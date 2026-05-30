const crypto = require("node:crypto");

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

function metadataHash(metadata) {
  return crypto
    .createHash("sha256")
    .update(JSON.stringify(metadata))
    .digest("hex")
    .slice(0, 16);
}

function stableId(prefix, metadata) {
  return `${prefix}-${metadataHash(metadata)}`;
}

function createDryRunQueue() {
  const sessions = new Map();
  const recent = [];
  let sequence = 0;
  let maxQueueDepth = 0;

  function sessionFor(sessionKey) {
    const key = typeof sessionKey === "string" && sessionKey.trim().length > 0
      ? sessionKey.trim()
      : "main";
    let session = sessions.get(key);
    if (!session) {
      session = {
        sessionKey: key,
        nativeSessionId: stableId("native-session", { sessionKey: key }),
        createdAt: nowIso(),
        lastSeenAt: null,
        accepted: 0,
        completed: 0,
        duplicate: 0,
        inFlight: 0,
        idempotencyKeys: new Map(),
        recent: []
      };
      sessions.set(key, session);
    }
    return session;
  }

  function pushRecent(entry) {
    recent.push(entry);
    if (recent.length > 24) recent.splice(0, recent.length - 24);
  }

  function pushSessionRecent(session, entry) {
    session.recent.push(entry);
    if (session.recent.length > 8) {
      session.recent.splice(0, session.recent.length - 8);
    }
  }

  function acceptDryRun({ payload, shape, gatewayReady }) {
    const session = sessionFor(shape.sessionKey);
    const idempotencyKey = typeof payload?.params?.idempotencyKey === "string"
      ? payload.params.idempotencyKey
      : null;
    const requestId = typeof payload?.id === "string"
      ? payload.id
      : stableId("native-request", {
          sessionKey: session.sessionKey,
          sequence: sequence + 1,
          metadataHash: shape.metadataHash
        });
    const duplicateOf = idempotencyKey
      ? session.idempotencyKeys.get(idempotencyKey)
      : null;

    const queueDepthBefore = session.inFlight;
    session.inFlight += 1;
    maxQueueDepth = Math.max(maxQueueDepth, session.inFlight);
    sequence += 1;
    const queuedAt = nowIso();
    const runId = duplicateOf?.runId || stableId("native-run", {
      sessionKey: session.sessionKey,
      requestId,
      sequence,
      metadataHash: shape.metadataHash
    });

    const entry = {
      sequence,
      requestId,
      runId,
      sessionKey: session.sessionKey,
      nativeSessionId: session.nativeSessionId,
      metadataHash: shape.metadataHash,
      messageChars: shape.messageChars,
      mobileToolHints: shape.mobileToolHints,
      duplicate: duplicateOf != null,
      duplicateOfRequestId: duplicateOf?.requestId ?? null,
      queuedAt,
      parsedAt: nowIso(),
      queueDepthBefore,
      queueDepthAfter: Math.max(0, session.inFlight - 1),
      state: "parsed_disabled",
      route: "disabled",
      gatewayReady
    };

    session.inFlight = entry.queueDepthAfter;
    session.lastSeenAt = entry.parsedAt;
    session.accepted += duplicateOf == null ? 1 : 0;
    session.completed += 1;
    session.duplicate += duplicateOf == null ? 0 : 1;
    if (idempotencyKey && duplicateOf == null) {
      session.idempotencyKeys.set(idempotencyKey, {
        requestId,
        runId,
        firstSeenAt: queuedAt
      });
    }

    pushRecent(entry);
    pushSessionRecent(session, {
      sequence: entry.sequence,
      requestId: entry.requestId,
      runId: entry.runId,
      metadataHash: entry.metadataHash,
      messageChars: entry.messageChars,
      duplicate: entry.duplicate,
      state: entry.state,
      queuedAt: entry.queuedAt,
      parsedAt: entry.parsedAt
    });

    return {
      ...entry,
      pendingQueueDepth: session.inFlight,
      sessionAccepted: session.accepted,
      sessionCompleted: session.completed,
      sessionDuplicate: session.duplicate,
      maxQueueDepth
    };
  }

  function snapshot() {
    return {
      ok: true,
      runtime: "native-node-embedded",
      canaryOnly: true,
      dryRun: true,
      queueMode: "parse-only",
      route: "disabled",
      acceptedForRouting: false,
      chatRoutingEnabled: false,
      providerCallsEnabled: false,
      executionEnabled: false,
      sessionCount: sessions.size,
      pendingQueueDepth: Array.from(sessions.values())
        .reduce((sum, session) => sum + session.inFlight, 0),
      maxQueueDepth,
      totalAccepted: Array.from(sessions.values())
        .reduce((sum, session) => sum + session.accepted, 0),
      totalCompleted: Array.from(sessions.values())
        .reduce((sum, session) => sum + session.completed, 0),
      totalDuplicate: Array.from(sessions.values())
        .reduce((sum, session) => sum + session.duplicate, 0),
      sessions: Array.from(sessions.values()).map((session) => ({
        sessionKey: session.sessionKey,
        nativeSessionId: session.nativeSessionId,
        createdAt: session.createdAt,
        lastSeenAt: session.lastSeenAt,
        accepted: session.accepted,
        completed: session.completed,
        duplicate: session.duplicate,
        pendingQueueDepth: session.inFlight,
        recent: session.recent
      })),
      recent
    };
  }

  return {
    acceptDryRun,
    snapshot
  };
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

function extractMobileNodeHandle(message) {
  if (typeof message !== "string") return null;
  const match = message.match(/gateway handle is "([^"]+)"/);
  return match ? match[1] : null;
}

function summarizeGatewayWsFrame(payload) {
  const params = payload && typeof payload.params === "object" && payload.params !== null
    ? payload.params
    : {};
  const message = typeof params.message === "string" ? params.message : "";
  const sessionKey = typeof params.sessionKey === "string" ? params.sessionKey : null;
  const idempotencyKey = typeof params.idempotencyKey === "string"
    ? params.idempotencyKey
    : null;
  const timeoutMs = typeof params.timeoutMs === "number" ? params.timeoutMs : null;
  const mobileToolHints = [
    "camera_snap",
    "device_status",
    "avatar.gesture",
    "canvas.navigate",
    "canvas.eval",
    "canvas.snapshot",
    "haptic.vibrate",
    "sensor.read",
    "sensor.list",
    "flash.status",
    "notifications.list"
  ].filter((hint) => message.includes(hint)).sort();

  const shape = {
    ok: true,
    requestShape: "openclaw-ws-rpc-chat-send",
    frameType: payload?.type ?? null,
    method: payload?.method ?? null,
    hasId: typeof payload?.id === "string" && payload.id.length > 0,
    hasParams: Object.keys(params).length > 0,
    sessionKey,
    messageChars: message.length,
    hasMessage: message.length > 0,
    idempotencyKeyPresent: idempotencyKey != null && idempotencyKey.length > 0,
    timeoutMs,
    hasMobileToolContext: message.includes("<plawie_mobile_tool_context>"),
    mobileNodeHandle: extractMobileNodeHandle(message),
    notificationListDisabled:
      message.includes("Notification listing/reading is not currently exposed"),
    mobileToolHints,
    looksLikeProductionChatSend:
      payload?.type === "req" &&
      payload?.method === "chat.send" &&
      typeof payload?.id === "string" &&
      typeof sessionKey === "string" &&
      typeof params.message === "string" &&
      typeof idempotencyKey === "string" &&
      typeof timeoutMs === "number",
    safeForProbe: true,
    acceptedForRouting: false,
    providerCallsEnabled: false,
    executionEnabled: false,
    inspectedAt: nowIso()
  };

  return {
    ...shape,
    metadataHash: metadataHash({
      requestShape: shape.requestShape,
      frameType: shape.frameType,
      method: shape.method,
      hasId: shape.hasId,
      hasParams: shape.hasParams,
      sessionKey: shape.sessionKey,
      messageChars: shape.messageChars,
      hasMessage: shape.hasMessage,
      idempotencyKeyPresent: shape.idempotencyKeyPresent,
      timeoutMs: shape.timeoutMs,
      hasMobileToolContext: shape.hasMobileToolContext,
      mobileNodeHandle: shape.mobileNodeHandle,
      notificationListDisabled: shape.notificationListDisabled,
      mobileToolHints: shape.mobileToolHints,
      looksLikeProductionChatSend: shape.looksLikeProductionChatSend,
      acceptedForRouting: shape.acceptedForRouting,
      providerCallsEnabled: shape.providerCallsEnabled,
      executionEnabled: shape.executionEnabled
    })
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
    "/gateway/ws-frame-shape",
    "/gateway/chat-send-dry-run",
    "/gateway/dry-run-sessions",
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

  function readyState() {
    return {
      status: preflight?.passed === true ? "ready" : "blocked",
      preflightPassed: preflight?.passed === true,
      hotReloading: false,
      acceptsDryRunQueue: true,
      chatRoutingEnabled: false,
      providerCallsEnabled: false,
      executionEnabled: false,
      checkedAt: nowIso(),
      uptimeMs: uptimeMs()
    };
  }

  const dryRunQueue = createDryRunQueue();

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
      acceptsDryRunQueue: true,
      fullSkillRegistryLoaded: false,
      productionSkillRegistryInspected: skillRegistry?.ok === true,
      productionSkillCount: skillRegistry?.skillCount ?? 0,
      skillRegistryMode: "curated-mobile-preflight",
      skillCount: preflight?.skillCount ?? 0,
      toolCount: Array.isArray(preflight?.bridgeToolNames)
        ? preflight.bridgeToolNames.length
        : 0,
      endpoints,
      readyState: readyState(),
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
      smokePort: port,
      readyState: readyState()
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

  async function handleWsFrameShape(req, res) {
    try {
      const payload = await readJsonBody(req, 256 * 1024);
      const shape = summarizeGatewayWsFrame(payload);
      sendJson(res, 200, {
        ok: true,
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
          code: error.code || "ws_frame_shape_parse_failed",
          message: error.message || String(error)
        },
        runtime: "native-node-embedded",
        canaryOnly: true,
        openclawStarted: false,
        productionGatewayPort
      });
    }
  }

  async function handleChatSendDryRun(req, res) {
    try {
      const payload = await readJsonBody(req, 256 * 1024);
      const shape = summarizeGatewayWsFrame(payload);
      const parsed = shape.looksLikeProductionChatSend === true;
      const queued = parsed
        ? dryRunQueue.acceptDryRun({
            payload,
            shape,
            gatewayReady: readyState()
          })
        : null;
      sendJson(res, parsed ? 202 : 422, {
        ok: parsed,
        type: "res",
        id: typeof payload?.id === "string" ? payload.id : null,
        method: "chat.send",
        runtime: "native-node-embedded",
        canaryOnly: true,
        dryRun: true,
        parsed,
        openclawStarted: false,
        acceptedForRouting: false,
        acceptedForQueue: parsed,
        queuedForDryRun: parsed,
        queueStatus: parsed ? "parsed_disabled" : "rejected",
        chatRoutingEnabled: false,
        providerCallsEnabled: false,
        executionEnabled: false,
        productionGatewayPort,
        ack: {
          parsed,
          route: "disabled",
          reason: parsed
            ? "chat.send frame queued and parsed; routing intentionally disabled in native dry-run"
            : "payload is not a production-shaped chat.send frame",
          sessionKey: shape.sessionKey,
          nativeSessionId: queued?.nativeSessionId ?? null,
          requestId: queued?.requestId ?? null,
          runId: queued?.runId ?? null,
          sequence: queued?.sequence ?? null,
          queueStatus: queued?.state ?? "rejected",
          queueDepthBefore: queued?.queueDepthBefore ?? null,
          queueDepthAfter: queued?.queueDepthAfter ?? null,
          pendingQueueDepth: queued?.pendingQueueDepth ?? null,
          sessionAccepted: queued?.sessionAccepted ?? null,
          sessionCompleted: queued?.sessionCompleted ?? null,
          sessionDuplicate: queued?.sessionDuplicate ?? null,
          duplicate: queued?.duplicate ?? false,
          duplicateOfRequestId: queued?.duplicateOfRequestId ?? null,
          queuedAt: queued?.queuedAt ?? null,
          parsedAt: queued?.parsedAt ?? null,
          gatewayReady: queued?.gatewayReady ?? readyState(),
          idempotencyKeyPresent: shape.idempotencyKeyPresent,
          timeoutMs: shape.timeoutMs,
          messageChars: shape.messageChars,
          hasMobileToolContext: shape.hasMobileToolContext,
          mobileNodeHandle: shape.mobileNodeHandle,
          mobileToolHints: shape.mobileToolHints,
          metadataHash: shape.metadataHash
        },
        requestShape: shape
      });
    } catch (error) {
      sendJson(res, error.statusCode || 400, {
        ok: false,
        error: {
          type: "invalid_request",
          code: error.code || "chat_send_dry_run_parse_failed",
          message: error.message || String(error)
        },
        runtime: "native-node-embedded",
        canaryOnly: true,
        dryRun: true,
        openclawStarted: false,
        acceptedForRouting: false,
        chatRoutingEnabled: false,
        providerCallsEnabled: false,
        executionEnabled: false,
        productionGatewayPort
      });
    }
  }

  function handleDryRunSessions(_req, res) {
    sendJson(res, 200, {
      ...dryRunQueue.snapshot(),
      productionGatewayPort,
      readyState: readyState()
    });
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

    if (pathname === "/gateway/ws-frame-shape") {
      handleWsFrameShape(req, res);
      return true;
    }

    if (pathname === "/gateway/chat-send-dry-run") {
      handleChatSendDryRun(req, res);
      return true;
    }

    if (pathname === "/gateway/dry-run-sessions") {
      handleDryRunSessions(req, res);
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
