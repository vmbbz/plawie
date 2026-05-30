const jsonHeaders = {
  "content-type": "application/json",
  "cache-control": "no-store"
};

function sendJson(res, statusCode, body) {
  res.writeHead(statusCode, jsonHeaders);
  res.end(JSON.stringify(body));
}

function readJsonBody(req, maxBytes) {
  return new Promise((resolve, reject) => {
    let received = 0;
    let failed = false;
    const chunks = [];

    req.on("data", (chunk) => {
      if (failed) return;
      received += chunk.length;
      if (received > maxBytes) {
        failed = true;
        reject(Object.assign(new Error("request_body_too_large"), {
          code: "request_body_too_large",
          statusCode: 413
        }));
        return;
      }
      chunks.push(chunk);
    });

    req.on("end", () => {
      if (failed) return;
      try {
        const text = Buffer.concat(chunks).toString("utf8");
        resolve(text.trim().length === 0 ? {} : JSON.parse(text));
      } catch (error) {
        reject(Object.assign(error, {
          code: "invalid_json",
          statusCode: 400
        }));
      }
    });

    req.on("error", reject);
  });
}

function nowIso() {
  return new Date().toISOString();
}

function summarizeMessageContent(content) {
  if (typeof content === "string") {
    return {
      textChars: content.length,
      textParts: content.length > 0 ? 1 : 0,
      imageParts: 0,
      otherParts: 0
    };
  }

  if (!Array.isArray(content)) {
    return {
      textChars: 0,
      textParts: 0,
      imageParts: 0,
      otherParts: content == null ? 0 : 1
    };
  }

  return content.reduce((acc, part) => {
    if (typeof part === "string") {
      acc.textChars += part.length;
      acc.textParts += 1;
      return acc;
    }

    if (part && typeof part === "object") {
      if (part.type === "text" && typeof part.text === "string") {
        acc.textChars += part.text.length;
        acc.textParts += 1;
      } else if (
        part.type === "image_url" ||
        part.type === "input_image" ||
        Object.prototype.hasOwnProperty.call(part, "image_url")
      ) {
        acc.imageParts += 1;
      } else {
        acc.otherParts += 1;
      }
      return acc;
    }

    acc.otherParts += 1;
    return acc;
  }, {
    textChars: 0,
    textParts: 0,
    imageParts: 0,
    otherParts: 0
  });
}

function summarizeChatRequest(payload) {
  const messages = Array.isArray(payload?.messages) ? payload.messages : [];
  const roleCounts = {};
  let textChars = 0;
  let systemTextChars = 0;
  let userTextChars = 0;
  let assistantTextChars = 0;
  let toolTextChars = 0;
  let imageParts = 0;
  let multimodalMessages = 0;
  let toolCallMessages = 0;

  for (const message of messages) {
    const role = typeof message?.role === "string" ? message.role : "unknown";
    roleCounts[role] = (roleCounts[role] || 0) + 1;

    const summary = summarizeMessageContent(message?.content);
    textChars += summary.textChars;
    imageParts += summary.imageParts;
    if (summary.imageParts > 0 || summary.otherParts > 0 || summary.textParts > 1) {
      multimodalMessages += 1;
    }

    if (role === "system" || role === "developer") {
      systemTextChars += summary.textChars;
    } else if (role === "user") {
      userTextChars += summary.textChars;
    } else if (role === "assistant") {
      assistantTextChars += summary.textChars;
    } else if (role === "tool") {
      toolTextChars += summary.textChars;
    }

    if (Array.isArray(message?.tool_calls) && message.tool_calls.length > 0) {
      toolCallMessages += 1;
    }
  }

  const tools = Array.isArray(payload?.tools) ? payload.tools : [];
  const toolNames = tools
    .map((tool) => tool?.function?.name || tool?.name)
    .filter((name) => typeof name === "string")
    .sort();

  return {
    ok: true,
    requestShape: "openai-chat-completions",
    model: typeof payload?.model === "string" ? payload.model : null,
    stream: payload?.stream === true,
    toolChoice: payload?.tool_choice ?? null,
    maxTokens: payload?.max_tokens ?? payload?.max_completion_tokens ?? null,
    temperature: payload?.temperature ?? null,
    messageCount: messages.length,
    roleCounts,
    textChars,
    systemTextChars,
    userTextChars,
    assistantTextChars,
    toolTextChars,
    imageParts,
    multimodalMessages,
    toolCallMessages,
    toolCount: tools.length,
    toolNames,
    toolSchemaChars: JSON.stringify(tools).length,
    hasLargeGatewaySystemPrompt: systemTextChars >= 6000,
    safeForProbe: true,
    acceptedForRouting: false,
    providerCallsEnabled: false,
    executionEnabled: false,
    inspectedAt: nowIso()
  };
}

function createMobileGatewayProbe({
  preflight,
  skillRegistry,
  host,
  port,
  productionGatewayPort,
  startedAt
}) {
  const endpoints = [
    "/health",
    "/preflight",
    "/gateway/probe",
    "/gateway/capabilities",
    "/gateway/skill-registry",
    "/gateway/request-shape",
    "/v1/models",
    "/v1/chat/completions"
  ];

  const warnings = [
    "probe_only_runtime",
    "production_gateway_remains_proot",
    "full_openclaw_skill_registry_not_loaded",
    "provider_calls_disabled",
    "chat_routing_disabled"
  ];

  function uptimeMs() {
    return Date.now() - startedAt;
  }

  function summary() {
    return {
      passed: preflight?.passed === true,
      probe: "mobile-openclaw-gateway-bootstrap",
      gatewayShape: "openclaw-http-probe",
      status: preflight?.passed === true ? "ready" : "blocked",
      runtime: "native-node-embedded",
      canaryOnly: true,
      productionReady: false,
      host,
      port,
      productionGatewayPort,
      openclawStarted: false,
      chatRoutingEnabled: false,
      providerCallsEnabled: false,
      fullSkillRegistryLoaded: false,
      productionSkillRegistryInspected: skillRegistry?.ok === true,
      productionSkillCount: skillRegistry?.skillCount ?? 0,
      skillRegistryMode: "curated-mobile-preflight",
      skillCount: preflight?.skillCount ?? 0,
      toolCount: Array.isArray(preflight?.bridgeToolNames)
        ? preflight.bridgeToolNames.length
        : 0,
      endpoints,
      warnings,
      checkedAt: nowIso(),
      uptimeMs: uptimeMs()
    };
  }

  function capabilities() {
    return {
      ok: preflight?.passed === true,
      runtime: "native-node-embedded",
      capabilityMode: "curated-mobile-preflight",
      canaryOnly: true,
      openclawStarted: false,
      fullSkillRegistryLoaded: false,
      productionSkillRegistryInspected: skillRegistry?.ok === true,
      productionSkillCount: skillRegistry?.skillCount ?? 0,
      productionSkillsLoaded: false,
      productionSkillRegistry: skillRegistry
        ? {
            ok: skillRegistry.ok === true,
            readOnly: skillRegistry.readOnly === true,
            executionEnabled: skillRegistry.executionEnabled === true,
            registrySource: skillRegistry.registrySource,
            skillCount: skillRegistry.skillCount ?? 0,
            countsByClass: skillRegistry.countsByClass ?? {},
            errors: skillRegistry.errors ?? []
          }
        : null,
      skillsSource: "assets/openclaw/skills",
      skillCount: preflight?.skillCount ?? 0,
      skillFiles: preflight?.skillFiles ?? [],
      bridgeToolsLoaded: preflight?.bridgeToolsLoaded === true,
      bridgeToolNames: preflight?.bridgeToolNames ?? [],
      disabledSurfaces: [
        "chat.completions",
        "provider.calls",
        "shell.exec",
        "browser.automation",
        "production.tools",
        "production.skills.registry"
      ],
      productionGatewayPort,
      smokePort: port
    };
  }

  async function handleRequestShape(req, res, { statusCode }) {
    try {
      const payload = await readJsonBody(req, 256 * 1024);
      const shape = summarizeChatRequest(payload);
      sendJson(res, statusCode, {
        ok: statusCode === 200,
        runtime: "native-node-embedded",
        canaryOnly: true,
        openclawStarted: false,
        productionGatewayPort,
        requestShape: shape
      });
    } catch (error) {
      sendJson(res, error.statusCode || 400, {
        ok: false,
        error: {
          type: "invalid_request",
          code: error.code || "request_shape_parse_failed",
          message: error.message || String(error)
        },
        runtime: "native-node-embedded",
        canaryOnly: true,
        openclawStarted: false,
        productionGatewayPort
      });
    }
  }

  function modelList() {
    return {
      object: "list",
      probeOnly: true,
      canaryOnly: true,
      data: [
        {
          id: "plawie/native-node-probe",
          object: "model",
          owned_by: "plawie",
          created: 0,
          capabilities: {
            chat: false,
            tool_calls: false,
            streaming: false
          }
        }
      ]
    };
  }

  async function rejectChat(req, res) {
    try {
      const payload = await readJsonBody(req, 256 * 1024);
      const shape = summarizeChatRequest(payload);
      sendJson(res, 409, {
        error: {
          type: "probe_only_runtime",
          code: "chat_disabled",
          message:
            "Embedded native Node parsed the chat request shape only. Chat and provider calls remain on the production PRoot Gateway."
        },
        runtime: "native-node-embedded",
        canaryOnly: true,
        openclawStarted: false,
        providerCallsEnabled: false,
        executionEnabled: false,
        productionGatewayPort,
        requestShape: shape
      });
    } catch (error) {
      sendJson(res, error.statusCode || 400, {
        error: {
          type: "invalid_request",
          code: error.code || "request_shape_parse_failed",
          message: error.message || String(error)
        },
        runtime: "native-node-embedded",
        canaryOnly: true,
        openclawStarted: false,
        providerCallsEnabled: false,
        executionEnabled: false,
        productionGatewayPort
      });
    }
  }

  function handle(req, res, pathname) {
    if (pathname === "/gateway/probe") {
      sendJson(res, 200, summary());
      return true;
    }

    if (pathname === "/gateway/capabilities") {
      sendJson(res, 200, capabilities());
      return true;
    }

    if (pathname === "/gateway/skill-registry") {
      sendJson(res, skillRegistry?.ok === true ? 200 : 503, {
        ...(skillRegistry ?? {
          ok: false,
          readOnly: true,
          executionEnabled: false,
          errors: ["skill_registry_not_configured"]
        }),
        canaryOnly: true,
        openclawStarted: false,
        chatRoutingEnabled: false
      });
      return true;
    }

    if (pathname === "/v1/models") {
      sendJson(res, 200, modelList());
      return true;
    }

    if (pathname === "/gateway/request-shape") {
      handleRequestShape(req, res, { statusCode: 200 });
      return true;
    }

    if (pathname === "/v1/chat/completions") {
      rejectChat(req, res);
      return true;
    }

    return false;
  }

  return {
    endpoints,
    summary,
    capabilities,
    handle
  };
}

module.exports = {
  createMobileGatewayProbe
};
