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

function delayMs(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
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

  function acceptDryRun({
    payload,
    shape,
    gatewayReady,
    source = "shadow-dry-run",
    canaryMode = "shadow-dry-run",
    directCanary = false
  }) {
    const session = sessionFor(shape.sessionKey);
    const idempotencyKey = typeof payload?.params?.idempotencyKey === "string"
      ? payload.params.idempotencyKey
      : null;
    const idempotencyScopeKey = idempotencyKey
      ? `${source}:${canaryMode}:${idempotencyKey}`
      : null;
    const requestId = typeof payload?.id === "string"
      ? payload.id
      : stableId("native-request", {
          sessionKey: session.sessionKey,
          sequence: sequence + 1,
          metadataHash: shape.metadataHash
        });
    const duplicateOf = idempotencyScopeKey
      ? session.idempotencyKeys.get(idempotencyScopeKey)
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
      source,
      canaryMode,
      directCanary,
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
    if (idempotencyScopeKey && duplicateOf == null) {
      session.idempotencyKeys.set(idempotencyScopeKey, {
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
      source: entry.source,
      canaryMode: entry.canaryMode,
      directCanary: entry.directCanary,
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
      sourceCounts: recent.reduce((counts, entry) => {
        const source = entry.source || "unknown";
        counts[source] = (counts[source] || 0) + 1;
        return counts;
      }, {}),
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
    "/gateway/chat-send-canary",
    "/gateway/chat-send-canary-stream",
    "/gateway/chat-route-skeleton-stream",
    "/gateway/chat-route-skeleton-cancel",
    "/gateway/chat-provider-shell-stream",
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
  const routingSkeletonRuns = new Map();

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

  async function handleChatSendDryRun(req, res, {
    source = "shadow-dry-run",
    canaryMode = "shadow-dry-run",
    directCanary = false
  } = {}) {
    try {
      const payload = await readJsonBody(req, 256 * 1024);
      const shape = summarizeGatewayWsFrame(payload);
      const parsed = shape.looksLikeProductionChatSend === true;
      const queued = parsed
        ? dryRunQueue.acceptDryRun({
            payload,
            shape,
            gatewayReady: readyState(),
            source,
            canaryMode,
            directCanary
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
        source,
        canaryMode,
        directCanary,
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
          source,
          canaryMode,
          directCanary,
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
        source,
        canaryMode,
        directCanary,
        openclawStarted: false,
        acceptedForRouting: false,
        chatRoutingEnabled: false,
        providerCallsEnabled: false,
        executionEnabled: false,
        productionGatewayPort
      });
    }
  }

  async function handleChatSendCanaryStream(req, res) {
    const source = "primary-canary-stream";
    const canaryMode = "stream-dry-run";
    const directCanary = true;

    function writeEvent(event, payload) {
      res.write(`${JSON.stringify({
        event,
        ...payload
      })}\n`);
    }

    try {
      const payload = await readJsonBody(req, 256 * 1024);
      const shape = summarizeGatewayWsFrame(payload);
      const parsed = shape.looksLikeProductionChatSend === true;
      if (!parsed) {
        sendJson(res, 422, {
          ok: false,
          parsed: false,
          runtime: "native-node-embedded",
          canaryOnly: true,
          dryRun: true,
          source,
          canaryMode,
          directCanary,
          acceptedForRouting: false,
          acceptedForQueue: false,
          chatRoutingEnabled: false,
          providerCallsEnabled: false,
          executionEnabled: false,
          productionGatewayPort,
          error: {
            type: "invalid_request",
            code: "not_chat_send_frame",
            message: "payload is not a production-shaped chat.send frame"
          },
          requestShape: shape
        });
        return;
      }

      const queued = dryRunQueue.acceptDryRun({
        payload,
        shape,
        gatewayReady: readyState(),
        source,
        canaryMode,
        directCanary
      });
      const ack = {
        parsed,
        route: "disabled",
        source,
        canaryMode,
        directCanary,
        reason:
          "chat.send frame queued and parsed; native stream is synthetic and routing remains disabled",
        sessionKey: shape.sessionKey,
        nativeSessionId: queued.nativeSessionId,
        requestId: queued.requestId,
        runId: queued.runId,
        sequence: queued.sequence,
        queueStatus: queued.state,
        queueDepthBefore: queued.queueDepthBefore,
        queueDepthAfter: queued.queueDepthAfter,
        pendingQueueDepth: queued.pendingQueueDepth,
        sessionAccepted: queued.sessionAccepted,
        sessionCompleted: queued.sessionCompleted,
        sessionDuplicate: queued.sessionDuplicate,
        duplicate: queued.duplicate,
        duplicateOfRequestId: queued.duplicateOfRequestId,
        queuedAt: queued.queuedAt,
        parsedAt: queued.parsedAt,
        gatewayReady: queued.gatewayReady,
        idempotencyKeyPresent: shape.idempotencyKeyPresent,
        timeoutMs: shape.timeoutMs,
        messageChars: shape.messageChars,
        hasMobileToolContext: shape.hasMobileToolContext,
        mobileNodeHandle: shape.mobileNodeHandle,
        mobileToolHints: shape.mobileToolHints,
        metadataHash: shape.metadataHash
      };

      res.writeHead(202, {
        "content-type": "application/x-ndjson",
        "cache-control": "no-store",
        "x-plawie-native-canary": "stream-dry-run"
      });
      writeEvent("ack", {
        ok: true,
        type: "res",
        id: typeof payload?.id === "string" ? payload.id : null,
        method: "chat.send",
        runtime: "native-node-embedded",
        canaryOnly: true,
        dryRun: true,
        source,
        canaryMode,
        directCanary,
        parsed: true,
        acceptedForRouting: false,
        acceptedForQueue: true,
        queuedForDryRun: true,
        queueStatus: "parsed_disabled",
        chatRoutingEnabled: false,
        providerCallsEnabled: false,
        executionEnabled: false,
        productionGatewayPort,
        ack,
        requestShape: shape
      });

      const chunks = [
        "Native stream dry-run accepted the production-shaped chat.send frame. ",
        "The UI is now consuming a response stream from embedded Node on 18790. ",
        "Routing, provider calls, and tool execution are still disabled."
      ];
      chunks.forEach((text, index) => {
        setTimeout(() => {
          writeEvent("delta", {
            ok: true,
            runtime: "native-node-embedded",
            source,
            canaryMode,
            runId: queued.runId,
            sequence: index + 1,
            text
          });
          if (index === chunks.length - 1) {
            writeEvent("end", {
              ok: true,
              runtime: "native-node-embedded",
              source,
              canaryMode,
              runId: queued.runId,
              finishReason: "dry_run_complete",
              providerCallsEnabled: false,
              executionEnabled: false
            });
            res.end();
          }
        }, 120 + index * 180);
      });
    } catch (error) {
      if (!res.headersSent) {
        sendJson(res, error.statusCode || 400, {
          ok: false,
          error: {
            type: "invalid_request",
            code: error.code || "chat_send_stream_parse_failed",
            message: error.message || String(error)
          },
          runtime: "native-node-embedded",
          canaryOnly: true,
          dryRun: true,
          source,
          canaryMode,
          directCanary,
          openclawStarted: false,
          acceptedForRouting: false,
          chatRoutingEnabled: false,
          providerCallsEnabled: false,
          executionEnabled: false,
          productionGatewayPort
        });
        return;
      }
      writeEvent("error", {
        ok: false,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        error: {
          type: "stream_error",
          code: error.code || "chat_send_stream_failed",
          message: error.message || String(error)
        }
      });
      res.end();
    }
  }

  function routingSkeletonPlan(queued, shape) {
    return {
      mode: "native-routing-skeleton",
      routeStatus: "blocked_before_provider",
      acceptedForRouting: false,
      chatRoutingEnabled: false,
      providerCallGate: {
        enabled: false,
        status: "blocked",
        reason: "provider_calls_disabled_until_native_runtime_canary_gate"
      },
      toolExecutionGate: {
        enabled: false,
        status: "blocked",
        reason: "tool_execution_disabled_until_native_runtime_canary_gate"
      },
      queue: {
        status: queued.state,
        source: queued.source,
        canaryMode: queued.canaryMode,
        sequence: queued.sequence
      },
      session: {
        sessionKey: queued.sessionKey,
        nativeSessionId: queued.nativeSessionId
      },
      run: {
        requestId: queued.requestId,
        runId: queued.runId,
        duplicate: queued.duplicate,
        duplicateOfRequestId: queued.duplicateOfRequestId
      },
      request: {
        metadataHash: shape.metadataHash,
        messageChars: shape.messageChars,
        hasMobileToolContext: shape.hasMobileToolContext,
        mobileNodeHandle: shape.mobileNodeHandle,
        mobileToolHints: shape.mobileToolHints
      },
      cancellation: {
        supported: true,
        endpoint: "/gateway/chat-route-skeleton-cancel",
        runId: queued.runId
      },
      errorFrameContract: {
        event: "error",
        fields: [
          "ok",
          "runtime",
          "source",
          "canaryMode",
          "runId",
          "error.type",
          "error.code",
          "error.message"
        ]
      }
    };
  }

  function providerShellEnvelope(payload, shape, queued) {
    const params = payload && typeof payload.params === "object" && payload.params !== null
      ? payload.params
      : {};
    const requestedModel = typeof params.model === "string" && params.model.trim().length > 0
      ? params.model.trim()
      : "openrouter/auto";
    const explicitProvider = typeof params.provider === "string" && params.provider.trim().length > 0
      ? params.provider.trim()
      : null;
    const slashIndex = requestedModel.indexOf("/");
    const inferredProvider = slashIndex > 0
      ? requestedModel.slice(0, slashIndex)
      : "unknown";
    const provider = explicitProvider || inferredProvider;
    const providerModel = slashIndex > 0
      ? requestedModel.slice(slashIndex + 1)
      : requestedModel;
    const openAiCompatible = [
      "openrouter",
      "openai",
      "groq",
      "together",
      "deepseek",
      "gemini"
    ].includes(provider);
    const transport = openAiCompatible
      ? "openai-compatible-chat-completions"
      : "provider-adapter-chat";
    const endpoint = provider === "openrouter"
      ? "https://openrouter.ai/api/v1/chat/completions"
      : `provider://${provider}/chat/completions`;
    const envelopeShape = {
      provider,
      requestedModel,
      providerModel,
      transport,
      endpointRedacted: endpoint,
      method: "POST",
      stream: true,
      outboundNetworkEnabled: false,
      authMaterialPresent: false,
      bodyShape: {
        model: providerModel,
        messages: [
          {
            role: "user",
            content: "<redacted>"
          }
        ],
        stream: true,
        tools: [],
        tool_choice: "none"
      },
      headersShape: {
        authorization: "<redacted-or-missing>",
        contentType: "application/json",
        referer: "<redacted-or-missing>",
        title: "<redacted-or-missing>"
      },
      request: {
        metadataHash: shape.metadataHash,
        messageChars: shape.messageChars,
        sessionKey: shape.sessionKey,
        mobileToolHints: shape.mobileToolHints
      },
      run: {
        requestId: queued.requestId,
        runId: queued.runId
      },
      errorContract: {
        event: "provider_error",
        fields: [
          "ok",
          "runtime",
          "source",
          "canaryMode",
          "runId",
          "provider",
          "statusCode",
          "rawError",
          "normalizedError.type",
          "normalizedError.code",
          "normalizedError.message"
        ],
        rawProviderErrorForwarding: true
      }
    };

    return {
      ...envelopeShape,
      envelopeHash: metadataHash({
        provider: envelopeShape.provider,
        requestedModel: envelopeShape.requestedModel,
        providerModel: envelopeShape.providerModel,
        transport: envelopeShape.transport,
        endpointRedacted: envelopeShape.endpointRedacted,
        stream: envelopeShape.stream,
        outboundNetworkEnabled: envelopeShape.outboundNetworkEnabled,
        bodyShape: envelopeShape.bodyShape,
        request: envelopeShape.request
      })
    };
  }

  async function handleChatRouteSkeletonStream(req, res) {
    const source = "routing-skeleton";
    const canaryMode = "routing-skeleton";
    const directCanary = true;
    let runState = null;

    function writeEvent(event, payload) {
      if (res.writableEnded) return;
      res.write(`${JSON.stringify({
        event,
        ...payload
      })}\n`);
    }

    function finishCancelled() {
      if (!runState || res.writableEnded) return true;
      if (!runState.cancelRequested) return false;
      runState.status = "cancelled";
      runState.completedAt = nowIso();
      writeEvent("cancelled", {
        ok: true,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        runId: runState.runId,
        finishReason: "cancelled",
        providerCallsEnabled: false,
        executionEnabled: false
      });
      writeEvent("end", {
        ok: true,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        runId: runState.runId,
        finishReason: "cancelled",
        providerCallsEnabled: false,
        executionEnabled: false
      });
      res.end();
      routingSkeletonRuns.delete(runState.runId);
      return true;
    }

    try {
      const payload = await readJsonBody(req, 256 * 1024);
      const shape = summarizeGatewayWsFrame(payload);
      const parsed = shape.looksLikeProductionChatSend === true;
      if (!parsed) {
        sendJson(res, 422, {
          ok: false,
          parsed: false,
          runtime: "native-node-embedded",
          canaryOnly: true,
          dryRun: true,
          source,
          canaryMode,
          directCanary,
          acceptedForRouting: false,
          acceptedForQueue: false,
          chatRoutingEnabled: false,
          providerCallsEnabled: false,
          executionEnabled: false,
          productionGatewayPort,
          error: {
            type: "invalid_request",
            code: "not_chat_send_frame",
            message: "payload is not a production-shaped chat.send frame"
          },
          requestShape: shape
        });
        return;
      }

      const queued = dryRunQueue.acceptDryRun({
        payload,
        shape,
        gatewayReady: readyState(),
        source,
        canaryMode,
        directCanary
      });
      const routePlan = routingSkeletonPlan(queued, shape);
      runState = {
        runId: queued.runId,
        requestId: queued.requestId,
        sessionKey: queued.sessionKey,
        status: "streaming",
        cancelRequested: false,
        startedAt: nowIso(),
        routePlan
      };
      routingSkeletonRuns.set(queued.runId, runState);

      req.on("close", () => {
        if (!res.writableEnded && runState) {
          runState.clientClosed = true;
        }
      });

      const ack = {
        parsed,
        route: "disabled",
        routeStatus: routePlan.routeStatus,
        source,
        canaryMode,
        directCanary,
        reason:
          "chat.send frame parsed by native routing skeleton; provider calls and tool execution remain disabled",
        sessionKey: shape.sessionKey,
        nativeSessionId: queued.nativeSessionId,
        requestId: queued.requestId,
        runId: queued.runId,
        sequence: queued.sequence,
        queueStatus: queued.state,
        queueDepthBefore: queued.queueDepthBefore,
        queueDepthAfter: queued.queueDepthAfter,
        pendingQueueDepth: queued.pendingQueueDepth,
        sessionAccepted: queued.sessionAccepted,
        sessionCompleted: queued.sessionCompleted,
        sessionDuplicate: queued.sessionDuplicate,
        duplicate: queued.duplicate,
        duplicateOfRequestId: queued.duplicateOfRequestId,
        queuedAt: queued.queuedAt,
        parsedAt: queued.parsedAt,
        gatewayReady: queued.gatewayReady,
        idempotencyKeyPresent: shape.idempotencyKeyPresent,
        timeoutMs: shape.timeoutMs,
        messageChars: shape.messageChars,
        hasMobileToolContext: shape.hasMobileToolContext,
        mobileNodeHandle: shape.mobileNodeHandle,
        mobileToolHints: shape.mobileToolHints,
        metadataHash: shape.metadataHash
      };

      res.writeHead(202, {
        "content-type": "application/x-ndjson",
        "cache-control": "no-store",
        "x-plawie-native-canary": "routing-skeleton"
      });
      writeEvent("ack", {
        ok: true,
        type: "res",
        id: typeof payload?.id === "string" ? payload.id : null,
        method: "chat.send",
        runtime: "native-node-embedded",
        canaryOnly: true,
        dryRun: true,
        source,
        canaryMode,
        directCanary,
        parsed: true,
        route: "disabled",
        routeStatus: routePlan.routeStatus,
        acceptedForRouting: false,
        acceptedForQueue: true,
        queuedForDryRun: true,
        queueStatus: "parsed_disabled",
        chatRoutingEnabled: false,
        providerCallsEnabled: false,
        executionEnabled: false,
        productionGatewayPort,
        ack,
        requestShape: shape
      });

      const steps = [
        {
          event: "route_plan",
          delay: 100,
          payload: {
            ok: true,
            runtime: "native-node-embedded",
            source,
            canaryMode,
            runId: queued.runId,
            routePlan
          }
        },
        {
          event: "provider_gate",
          delay: 120,
          payload: {
            ok: true,
            runtime: "native-node-embedded",
            source,
            canaryMode,
            runId: queued.runId,
            gate: routePlan.providerCallGate,
            providerCallsEnabled: false
          }
        },
        {
          event: "tool_gate",
          delay: 120,
          payload: {
            ok: true,
            runtime: "native-node-embedded",
            source,
            canaryMode,
            runId: queued.runId,
            gate: routePlan.toolExecutionGate,
            executionEnabled: false,
            mobileToolHints: shape.mobileToolHints
          }
        },
        {
          event: "delta",
          delay: 120,
          payload: {
            ok: true,
            runtime: "native-node-embedded",
            source,
            canaryMode,
            runId: queued.runId,
            sequence: 1,
            text:
              "Native routing skeleton accepted the production-shaped chat.send frame. "
          }
        },
        {
          event: "delta",
          delay: 140,
          payload: {
            ok: true,
            runtime: "native-node-embedded",
            source,
            canaryMode,
            runId: queued.runId,
            sequence: 2,
            text:
              "It built a route plan, attached cancellation/error contracts, and stopped before provider or tool execution."
          }
        },
        {
          event: "end",
          delay: 80,
          payload: {
            ok: true,
            runtime: "native-node-embedded",
            source,
            canaryMode,
            runId: queued.runId,
            routeStatus: routePlan.routeStatus,
            finishReason: "routing_skeleton_complete",
            providerCallsEnabled: false,
            executionEnabled: false
          }
        }
      ];

      for (const step of steps) {
        await delayMs(step.delay);
        if (finishCancelled()) return;
        writeEvent(step.event, step.payload);
        if (step.event === "end") {
          runState.status = "completed";
          runState.completedAt = nowIso();
          res.end();
          routingSkeletonRuns.delete(queued.runId);
          return;
        }
      }
    } catch (error) {
      if (runState) {
        runState.status = "error";
        runState.completedAt = nowIso();
        routingSkeletonRuns.delete(runState.runId);
      }
      if (!res.headersSent) {
        sendJson(res, error.statusCode || 400, {
          ok: false,
          error: {
            type: "invalid_request",
            code: error.code || "chat_route_skeleton_parse_failed",
            message: error.message || String(error)
          },
          runtime: "native-node-embedded",
          canaryOnly: true,
          dryRun: true,
          source,
          canaryMode,
          directCanary,
          openclawStarted: false,
          acceptedForRouting: false,
          chatRoutingEnabled: false,
          providerCallsEnabled: false,
          executionEnabled: false,
          productionGatewayPort
        });
        return;
      }
      writeEvent("error", {
        ok: false,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        runId: runState?.runId ?? null,
        error: {
          type: "stream_error",
          code: error.code || "chat_route_skeleton_failed",
          message: error.message || String(error)
        }
      });
      res.end();
    }
  }

  async function handleChatRouteSkeletonCancel(req, res) {
    try {
      const body = await readJsonBody(req, 64 * 1024);
      const url = new URL(req.url, `http://${req.headers.host || "127.0.0.1"}`);
      const runId = typeof body?.runId === "string" && body.runId.trim().length > 0
        ? body.runId.trim()
        : url.searchParams.get("runId");
      if (typeof runId !== "string" || runId.trim().length === 0) {
        sendJson(res, 400, {
          ok: false,
          runtime: "native-node-embedded",
          canaryOnly: true,
          error: {
            type: "invalid_request",
            code: "missing_run_id",
            message: "runId is required to cancel a native routing skeleton run"
          }
        });
        return;
      }

      const runState = routingSkeletonRuns.get(runId);
      if (!runState) {
        sendJson(res, 404, {
          ok: false,
          runtime: "native-node-embedded",
          canaryOnly: true,
          runId,
          cancelled: false,
          error: {
            type: "not_found",
            code: "routing_skeleton_run_not_found",
            message: "no active native routing skeleton run exists for runId"
          }
        });
        return;
      }

      runState.cancelRequested = true;
      runState.status = "cancel_requested";
      runState.cancelRequestedAt = nowIso();
      sendJson(res, 202, {
        ok: true,
        runtime: "native-node-embedded",
        canaryOnly: true,
        runId,
        cancelled: true,
        status: runState.status,
        providerCallsEnabled: false,
        executionEnabled: false
      });
    } catch (error) {
      sendJson(res, error.statusCode || 400, {
        ok: false,
        runtime: "native-node-embedded",
        canaryOnly: true,
        error: {
          type: "invalid_request",
          code: error.code || "routing_skeleton_cancel_failed",
          message: error.message || String(error)
        }
      });
    }
  }

  async function handleChatProviderShellStream(req, res) {
    const source = "provider-adapter-shell";
    const canaryMode = "provider-shell";
    const directCanary = true;

    function writeEvent(event, payload) {
      if (res.writableEnded) return;
      res.write(`${JSON.stringify({
        event,
        ...payload
      })}\n`);
    }

    try {
      const payload = await readJsonBody(req, 256 * 1024);
      const shape = summarizeGatewayWsFrame(payload);
      const parsed = shape.looksLikeProductionChatSend === true;
      if (!parsed) {
        sendJson(res, 422, {
          ok: false,
          parsed: false,
          runtime: "native-node-embedded",
          canaryOnly: true,
          dryRun: true,
          source,
          canaryMode,
          directCanary,
          acceptedForRouting: false,
          acceptedForQueue: false,
          chatRoutingEnabled: false,
          providerCallsEnabled: false,
          executionEnabled: false,
          productionGatewayPort,
          error: {
            type: "invalid_request",
            code: "not_chat_send_frame",
            message: "payload is not a production-shaped chat.send frame"
          },
          requestShape: shape
        });
        return;
      }

      const queued = dryRunQueue.acceptDryRun({
        payload,
        shape,
        gatewayReady: readyState(),
        source,
        canaryMode,
        directCanary
      });
      const envelope = providerShellEnvelope(payload, shape, queued);
      const ack = {
        parsed,
        route: "disabled",
        routeStatus: "blocked_before_outbound_provider",
        source,
        canaryMode,
        directCanary,
        reason:
          "provider adapter shell built a redacted outbound envelope; outbound network remains disabled",
        provider: envelope.provider,
        requestedModel: envelope.requestedModel,
        providerModel: envelope.providerModel,
        transport: envelope.transport,
        envelopeHash: envelope.envelopeHash,
        sessionKey: shape.sessionKey,
        nativeSessionId: queued.nativeSessionId,
        requestId: queued.requestId,
        runId: queued.runId,
        sequence: queued.sequence,
        queueStatus: queued.state,
        queueDepthBefore: queued.queueDepthBefore,
        queueDepthAfter: queued.queueDepthAfter,
        pendingQueueDepth: queued.pendingQueueDepth,
        sessionAccepted: queued.sessionAccepted,
        sessionCompleted: queued.sessionCompleted,
        sessionDuplicate: queued.sessionDuplicate,
        duplicate: queued.duplicate,
        duplicateOfRequestId: queued.duplicateOfRequestId,
        queuedAt: queued.queuedAt,
        parsedAt: queued.parsedAt,
        gatewayReady: queued.gatewayReady,
        idempotencyKeyPresent: shape.idempotencyKeyPresent,
        timeoutMs: shape.timeoutMs,
        messageChars: shape.messageChars,
        hasMobileToolContext: shape.hasMobileToolContext,
        mobileNodeHandle: shape.mobileNodeHandle,
        mobileToolHints: shape.mobileToolHints,
        metadataHash: shape.metadataHash
      };

      res.writeHead(202, {
        "content-type": "application/x-ndjson",
        "cache-control": "no-store",
        "x-plawie-native-canary": "provider-shell"
      });
      writeEvent("ack", {
        ok: true,
        type: "res",
        id: typeof payload?.id === "string" ? payload.id : null,
        method: "chat.send",
        runtime: "native-node-embedded",
        canaryOnly: true,
        dryRun: true,
        source,
        canaryMode,
        directCanary,
        parsed: true,
        route: "disabled",
        routeStatus: ack.routeStatus,
        acceptedForRouting: false,
        acceptedForQueue: true,
        queuedForDryRun: true,
        queueStatus: "parsed_disabled",
        chatRoutingEnabled: false,
        providerCallsEnabled: false,
        executionEnabled: false,
        productionGatewayPort,
        ack,
        requestShape: shape
      });

      const steps = [
        {
          event: "provider_envelope",
          delay: 100,
          payload: {
            ok: true,
            runtime: "native-node-embedded",
            source,
            canaryMode,
            runId: queued.runId,
            envelope
          }
        },
        {
          event: "provider_gate",
          delay: 120,
          payload: {
            ok: true,
            runtime: "native-node-embedded",
            source,
            canaryMode,
            runId: queued.runId,
            gate: {
              enabled: false,
              status: "blocked",
              reason: "outbound_provider_network_disabled_until_canary_gate",
              wouldCallProvider: envelope.provider,
              wouldUseTransport: envelope.transport
            },
            providerCallsEnabled: false
          }
        },
        {
          event: "provider_error_contract",
          delay: 100,
          payload: {
            ok: true,
            runtime: "native-node-embedded",
            source,
            canaryMode,
            runId: queued.runId,
            provider: envelope.provider,
            errorContract: envelope.errorContract
          }
        },
        {
          event: "delta",
          delay: 120,
          payload: {
            ok: true,
            runtime: "native-node-embedded",
            source,
            canaryMode,
            runId: queued.runId,
            sequence: 1,
            text:
              "Native provider shell built the redacted provider envelope. "
          }
        },
        {
          event: "delta",
          delay: 140,
          payload: {
            ok: true,
            runtime: "native-node-embedded",
            source,
            canaryMode,
            runId: queued.runId,
            sequence: 2,
            text:
              "Outbound provider network, billing, and tool execution are still disabled."
          }
        },
        {
          event: "end",
          delay: 80,
          payload: {
            ok: true,
            runtime: "native-node-embedded",
            source,
            canaryMode,
            runId: queued.runId,
            routeStatus: ack.routeStatus,
            finishReason: "provider_shell_complete",
            provider: envelope.provider,
            requestedModel: envelope.requestedModel,
            providerCallsEnabled: false,
            executionEnabled: false
          }
        }
      ];

      for (const step of steps) {
        await delayMs(step.delay);
        writeEvent(step.event, step.payload);
        if (step.event === "end") {
          res.end();
          return;
        }
      }
    } catch (error) {
      if (!res.headersSent) {
        sendJson(res, error.statusCode || 400, {
          ok: false,
          error: {
            type: "invalid_request",
            code: error.code || "chat_provider_shell_parse_failed",
            message: error.message || String(error)
          },
          runtime: "native-node-embedded",
          canaryOnly: true,
          dryRun: true,
          source,
          canaryMode,
          directCanary,
          openclawStarted: false,
          acceptedForRouting: false,
          chatRoutingEnabled: false,
          providerCallsEnabled: false,
          executionEnabled: false,
          productionGatewayPort
        });
        return;
      }
      writeEvent("error", {
        ok: false,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        error: {
          type: "stream_error",
          code: error.code || "chat_provider_shell_failed",
          message: error.message || String(error)
        }
      });
      res.end();
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

    if (pathname === "/gateway/chat-send-canary") {
      handleChatSendDryRun(req, res, {
        source: "direct-canary",
        canaryMode: "direct-dry-run",
        directCanary: true
      });
      return true;
    }

    if (pathname === "/gateway/chat-send-canary-stream") {
      handleChatSendCanaryStream(req, res);
      return true;
    }

    if (pathname === "/gateway/chat-route-skeleton-stream") {
      handleChatRouteSkeletonStream(req, res);
      return true;
    }

    if (pathname === "/gateway/chat-route-skeleton-cancel") {
      handleChatRouteSkeletonCancel(req, res);
      return true;
    }

    if (pathname === "/gateway/chat-provider-shell-stream") {
      handleChatProviderShellStream(req, res);
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
