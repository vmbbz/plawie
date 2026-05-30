const crypto = require("node:crypto");
const http = require("node:http");

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
    "/gateway/chat-provider-request-builder-stream",
    "/gateway/chat-provider-transport-shim-stream",
    "/gateway/chat-provider-live-canary-stream",
    "/gateway/chat-provider-stream-parser-parity-stream",
    "/gateway/chat-provider-tool-plan-canary-stream",
    "/gateway/chat-tool-dispatch-dry-run-stream",
    "/gateway/chat-native-dart-bridge-dry-run-stream",
    "/gateway/chat-native-dart-bridge-ordering-cancel-stream",
    "/gateway/chat-native-dart-bridge-haptic-canary-stream",
    "/gateway/chat-native-dart-bridge-readonly-canary-stream",
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

  function providerRouteFromPayload(payload) {
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
    let providerModel = slashIndex > 0
      ? requestedModel.slice(slashIndex + 1)
      : requestedModel;
    if (provider === "openrouter" && requestedModel === "openrouter/auto") {
      providerModel = "openrouter/auto";
    }
    return {
      requestedModel,
      provider,
      providerModel
    };
  }

  function providerShellEnvelope(payload, shape, queued) {
    const route = providerRouteFromPayload(payload);
    const requestedModel = route.requestedModel;
    const provider = route.provider;
    const providerModel = route.providerModel;
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

  function providerRequestBuilderDryRun(envelope, shape, queued) {
    const normalizedHeaders = {
      accept: envelope.stream ? "text/event-stream" : "application/json",
      authorization: "Bearer <redacted-or-missing>",
      "content-type": "application/json",
      "http-referer": "<redacted-or-missing>",
      "x-title": "<redacted-or-missing>"
    };
    const normalizedBody = {
      model: envelope.providerModel,
      messages: [
        {
          role: "user",
          content: "<redacted>"
        }
      ],
      stream: envelope.stream === true,
      tools: [],
      tool_choice: "none"
    };
    const headerValidation = {
      contentTypeOk: normalizedHeaders["content-type"] === "application/json",
      acceptOk: normalizedHeaders.accept === "text/event-stream",
      authorizationPolicy: "required_for_network_call",
      authMaterialStatus: "not_loaded_in_canary",
      forbiddenHeadersPresent: false,
      rawSecretsPresent: false
    };
    const bodyValidation = {
      modelPresent: typeof normalizedBody.model === "string" && normalizedBody.model.length > 0,
      messagesNormalized: normalizedBody.messages.length === 1,
      rawPromptRedacted: normalizedBody.messages[0].content === "<redacted>",
      streamMode: normalizedBody.stream === true,
      toolSchemasAttached: normalizedBody.tools.length > 0,
      toolChoice: normalizedBody.tool_choice
    };
    const headersHash = metadataHash(normalizedHeaders);
    const bodyHash = metadataHash(normalizedBody);
    const requestContract = {
      provider: envelope.provider,
      requestedModel: envelope.requestedModel,
      providerModel: envelope.providerModel,
      transport: envelope.transport,
      method: envelope.method,
      endpointRedacted: envelope.endpointRedacted,
      normalizedHeaders,
      normalizedBody,
      headerValidation,
      bodyValidation,
      envelopeHash: envelope.envelopeHash,
      request: {
        metadataHash: shape.metadataHash,
        sessionKey: shape.sessionKey,
        messageChars: shape.messageChars,
        mobileToolHints: shape.mobileToolHints
      },
      run: {
        requestId: queued.requestId,
        runId: queued.runId
      },
      outboundNetworkEnabled: false,
      transportInvocationEnabled: false,
      providerCallsEnabled: false,
      executionEnabled: false,
      stopBefore: "fetch_or_http_request",
      transportGate: {
        enabled: false,
        status: "blocked",
        reason: "transport_invocation_disabled_until_canary_gate",
        blockedBefore: "fetch_or_http_request"
      },
      providerConfigStatus: {
        mode: "shape_only",
        apiKeyLoaded: false,
        endpointResolved: true,
        headersNormalized: true,
        bodyNormalized: true
      },
      errorContract: envelope.errorContract
    };

    return {
      ...requestContract,
      headersHash,
      bodyHash,
      requestHash: metadataHash({
        provider: requestContract.provider,
        requestedModel: requestContract.requestedModel,
        providerModel: requestContract.providerModel,
        transport: requestContract.transport,
        method: requestContract.method,
        endpointRedacted: requestContract.endpointRedacted,
        normalizedHeaders,
        normalizedBody,
        envelopeHash: requestContract.envelopeHash,
        outboundNetworkEnabled: requestContract.outboundNetworkEnabled,
        transportInvocationEnabled: requestContract.transportInvocationEnabled
      }),
      validationOk:
        headerValidation.contentTypeOk &&
        headerValidation.acceptOk &&
        headerValidation.forbiddenHeadersPresent === false &&
        headerValidation.rawSecretsPresent === false &&
        bodyValidation.modelPresent &&
        bodyValidation.messagesNormalized &&
        bodyValidation.rawPromptRedacted &&
        bodyValidation.streamMode
    };
  }

  function providerTransportShimDryRun(requestBuilder, queued) {
    let endpointShape = {
      protocol: "unknown",
      host: "unknown",
      pathname: "unknown",
      searchParamNames: []
    };
    try {
      const url = new URL(requestBuilder.endpointRedacted);
      endpointShape = {
        protocol: url.protocol.replace(":", ""),
        host: url.hostname || "unknown",
        pathname: url.pathname || "/",
        searchParamNames: Array.from(url.searchParams.keys()).sort()
      };
    } catch (_) {
      endpointShape = {
        protocol: "provider",
        host: requestBuilder.provider,
        pathname: "/chat/completions",
        searchParamNames: []
      };
    }

    const abortContract = {
      abortControllerCreated: true,
      signalAttached: true,
      abortedLocally: true,
      abortReason: "transport_shim_canary_no_network",
      abortStage: "before_dns"
    };
    const networkProbe = {
      dnsLookupStarted: false,
      tlsHandshakeStarted: false,
      socketOpened: false,
      requestBytesWritten: 0,
      responseBytesRead: 0,
      providerBillingSurfaceReached: false
    };
    const transportObject = {
      adapter: "native-node-fetch-compatible-shim",
      provider: requestBuilder.provider,
      transport: requestBuilder.transport,
      method: requestBuilder.method,
      endpointShape,
      headersHash: requestBuilder.headersHash,
      bodyHash: requestBuilder.bodyHash,
      requestHash: requestBuilder.requestHash,
      streamExpected: requestBuilder.normalizedBody.stream === true,
      timeoutMs: 300000,
      abortContract,
      networkProbe,
      outboundNetworkEnabled: false,
      transportInvocationEnabled: false,
      providerCallsEnabled: false,
      executionEnabled: false
    };
    const shimValidation = {
      adapterSelected: transportObject.adapter.length > 0,
      endpointResolved: endpointShape.protocol !== "unknown",
      signalAttached: abortContract.signalAttached,
      abortedBeforeDns: abortContract.abortStage === "before_dns",
      noSocketOpened: networkProbe.socketOpened === false,
      noBytesWritten: networkProbe.requestBytesWritten === 0,
      billingSurfaceUnreached: networkProbe.providerBillingSurfaceReached === false
    };

    return {
      provider: requestBuilder.provider,
      requestedModel: requestBuilder.requestedModel,
      providerModel: requestBuilder.providerModel,
      transport: requestBuilder.transport,
      envelopeHash: requestBuilder.envelopeHash,
      headersHash: requestBuilder.headersHash,
      bodyHash: requestBuilder.bodyHash,
      requestHash: requestBuilder.requestHash,
      transportObject,
      shimValidation,
      transportHash: metadataHash({
        adapter: transportObject.adapter,
        provider: transportObject.provider,
        transport: transportObject.transport,
        method: transportObject.method,
        endpointShape: transportObject.endpointShape,
        headersHash: transportObject.headersHash,
        bodyHash: transportObject.bodyHash,
        requestHash: transportObject.requestHash,
        abortContract: transportObject.abortContract,
        networkProbe: transportObject.networkProbe,
        outboundNetworkEnabled: transportObject.outboundNetworkEnabled,
        transportInvocationEnabled: transportObject.transportInvocationEnabled
      }),
      validationOk:
        requestBuilder.validationOk === true &&
        shimValidation.adapterSelected &&
        shimValidation.endpointResolved &&
        shimValidation.signalAttached &&
        shimValidation.abortedBeforeDns &&
        shimValidation.noSocketOpened &&
        shimValidation.noBytesWritten &&
        shimValidation.billingSurfaceUnreached,
      transportGate: {
        enabled: false,
        status: "aborted_locally",
        reason: "transport_shim_aborted_before_dns_tls_socket",
        blockedBefore: "dns_lookup"
      },
      run: {
        requestId: queued.requestId,
        runId: queued.runId
      },
      stopBefore: "dns_tls_socket_or_fetch"
    };
  }

  function liveCanaryProviderConfig(payload, requestBuilder) {
    const raw = payload && typeof payload.nativeCanaryProviderConfig === "object" &&
      payload.nativeCanaryProviderConfig !== null
      ? payload.nativeCanaryProviderConfig
      : {};
    const apiKey = typeof raw.apiKey === "string" ? raw.apiKey.trim() : "";
    const endpoint = typeof raw.endpoint === "string" && raw.endpoint.trim().length > 0
      ? raw.endpoint.trim()
      : requestBuilder.endpointRedacted;
    const model = typeof raw.model === "string" && raw.model.trim().length > 0
      ? raw.model.trim()
      : requestBuilder.providerModel;
    const maxTokensRaw = Number(raw.maxTokens);
    const maxTokens = Number.isFinite(maxTokensRaw)
      ? Math.max(1, Math.min(32, Math.floor(maxTokensRaw)))
      : 16;
    const timeoutMsRaw = Number(raw.timeoutMs);
    const timeoutMs = Number.isFinite(timeoutMsRaw)
      ? Math.max(1000, Math.min(60000, Math.floor(timeoutMsRaw)))
      : 45000;
    const referer = typeof raw.referer === "string" && raw.referer.trim().length > 0
      ? raw.referer.trim()
      : "https://github.com/vmbbz/plawie";
    const title = typeof raw.title === "string" && raw.title.trim().length > 0
      ? raw.title.trim()
      : "Plawie Native Canary";

    let endpointShape = {
      protocol: "unknown",
      host: "unknown",
      pathname: "unknown"
    };
    let endpointAllowed = false;
    try {
      const url = new URL(endpoint);
      endpointShape = {
        protocol: url.protocol.replace(":", ""),
        host: url.hostname,
        pathname: url.pathname
      };
      endpointAllowed = requestBuilder.provider === "openrouter" &&
        url.protocol === "https:" &&
        url.hostname === "openrouter.ai" &&
        url.pathname.endsWith("/chat/completions");
    } catch (_) {
      endpointAllowed = false;
    }

    return {
      provider: requestBuilder.provider,
      endpoint,
      endpointShape,
      endpointAllowed,
      model,
      apiKey,
      apiKeyLoaded: apiKey.length > 0,
      maxTokens,
      timeoutMs,
      referer,
      title
    };
  }

  function compactCanaryPrompt(payload) {
    const params = payload && typeof payload.params === "object" && payload.params !== null
      ? payload.params
      : {};
    const raw = typeof params.message === "string" ? params.message : "";
    const compact = raw.replace(/\s+/g, " ").trim();
    return compact.length > 280 ? compact.slice(0, 280) : compact;
  }

  function providerLiveCanaryRequest(requestBuilder, payload) {
    const providerConfig = liveCanaryProviderConfig(payload, requestBuilder);
    const userPrompt = compactCanaryPrompt(payload);
    const normalizedBody = {
      model: providerConfig.model,
      messages: [
        {
          role: "system",
          content:
            "You are a Plawie native provider canary. Reply with exactly: native-ok"
        },
        {
          role: "user",
          content: `Canary probe: ${userPrompt || "native provider live canary"}`
        }
      ],
      stream: true,
      max_tokens: providerConfig.maxTokens,
      temperature: 0
    };
    const redactedBodyShape = {
      model: normalizedBody.model,
      messages: normalizedBody.messages.map((message) => ({
        role: message.role,
        content: "<redacted>",
        chars: message.content.length
      })),
      stream: normalizedBody.stream,
      max_tokens: normalizedBody.max_tokens,
      temperature: normalizedBody.temperature
    };
    const normalizedHeadersShape = {
      accept: "text/event-stream",
      authorization: providerConfig.apiKeyLoaded
        ? "Bearer <redacted>"
        : "Bearer <missing>",
      "content-type": "application/json",
      "http-referer": "<redacted>",
      "x-title": "<redacted>"
    };
    const requestBodyText = JSON.stringify(normalizedBody);
    const blockReasons = [];
    if (providerConfig.provider !== "openrouter") {
      blockReasons.push("only_openrouter_live_canary_supported");
    }
    if (!providerConfig.endpointAllowed) {
      blockReasons.push("endpoint_not_on_openrouter_chat_completions");
    }
    if (!providerConfig.apiKeyLoaded) {
      blockReasons.push("missing_openrouter_api_key");
    }
    if (typeof globalThis.fetch !== "function") {
      blockReasons.push("fetch_unavailable_in_embedded_node");
    }

    return {
      provider: providerConfig.provider,
      requestedModel: requestBuilder.requestedModel,
      providerModel: providerConfig.model,
      transport: requestBuilder.transport,
      endpoint: providerConfig.endpoint,
      endpointShape: providerConfig.endpointShape,
      normalizedHeadersShape,
      redactedBodyShape,
      requestBodyText,
      requestBodyBytes: Buffer.byteLength(requestBodyText, "utf8"),
      promptChars: userPrompt.length,
      timeoutMs: providerConfig.timeoutMs,
      maxTokens: providerConfig.maxTokens,
      apiKey: providerConfig.apiKey,
      referer: providerConfig.referer,
      title: providerConfig.title,
      canStart: blockReasons.length === 0,
      blockReasons,
      headersHash: metadataHash(normalizedHeadersShape),
      bodyHash: metadataHash(redactedBodyShape),
      requestHash: metadataHash({
        provider: providerConfig.provider,
        requestedModel: requestBuilder.requestedModel,
        providerModel: providerConfig.model,
        transport: requestBuilder.transport,
        endpointShape: providerConfig.endpointShape,
        headersShape: normalizedHeadersShape,
        bodyShape: redactedBodyShape,
        requestBuilderHash: requestBuilder.requestHash
      })
    };
  }

  function providerErrorPayload({
    source,
    canaryMode,
    runId,
    provider,
    statusCode = null,
    code = "provider_error",
    message = "provider error",
    rawError = null
  }) {
    const rawText = rawError == null
      ? null
      : String(rawError).slice(0, 4000);
    return {
      ok: false,
      runtime: "native-node-embedded",
      source,
      canaryMode,
      runId,
      provider,
      statusCode,
      rawProviderError: rawText,
      error: {
        type: "provider_error",
        code,
        message,
        raw: rawText
      },
      normalizedError: {
        type: "provider_error",
        code,
        message
      }
    };
  }

  function contentFromOpenAiCompatibleChunk(decoded) {
    if (!decoded || typeof decoded !== "object") return "";
    const choices = Array.isArray(decoded.choices) ? decoded.choices : [];
    if (choices.length === 0 || !choices[0] || typeof choices[0] !== "object") {
      return "";
    }
    const choice = choices[0];
    const delta = choice.delta && typeof choice.delta === "object"
      ? choice.delta
      : null;
    const message = choice.message && typeof choice.message === "object"
      ? choice.message
      : null;
    const content = delta?.content ?? message?.content ?? "";
    return typeof content === "string" ? content : "";
  }

  async function readProviderText(response) {
    try {
      return await response.text();
    } catch (error) {
      return `failed to read provider body: ${error.message || String(error)}`;
    }
  }

  function createProviderStreamParser({
    source,
    canaryMode,
    runId,
    startedAtMs = Date.now(),
    writeEvent = null
  }) {
    let sequence = 0;
    let textChars = 0;
    let firstTokenMs = null;
    let finishReason = null;
    let doneSeen = false;
    let warningCount = 0;
    let dataLineCount = 0;
    let parsedJsonCount = 0;
    let text = "";
    const warnings = [];

    function warning(code, message, rawChunk) {
      warningCount += 1;
      const entry = {
        code,
        message,
        rawChunk: String(rawChunk || "").slice(0, 500)
      };
      warnings.push(entry);
      if (writeEvent) {
        writeEvent("provider_parse_warning", {
          ok: false,
          runtime: "native-node-embedded",
          source,
          canaryMode,
          runId,
          warning: entry
        });
      }
    }

    function acceptData(data) {
      const trimmed = String(data || "").trim();
      if (trimmed.length === 0) return;
      dataLineCount += 1;
      if (trimmed === "[DONE]") {
        doneSeen = true;
        if (!finishReason) finishReason = "done";
        return;
      }

      let decoded;
      try {
        decoded = JSON.parse(trimmed);
        parsedJsonCount += 1;
      } catch (error) {
        warning(
          "provider_chunk_parse_failed",
          error.message || String(error),
          trimmed
        );
        return;
      }

      const choices = Array.isArray(decoded.choices) ? decoded.choices : [];
      const choice = choices[0] && typeof choices[0] === "object"
        ? choices[0]
        : null;
      if (choice?.finish_reason) {
        finishReason = choice.finish_reason;
      }

      const content = contentFromOpenAiCompatibleChunk(decoded);
      if (content.length === 0) return;

      sequence += 1;
      textChars += content.length;
      text += content;
      if (firstTokenMs == null) {
        firstTokenMs = Date.now() - startedAtMs;
      }
      if (writeEvent) {
        writeEvent("delta", {
          ok: true,
          runtime: "native-node-embedded",
          source,
          canaryMode,
          runId,
          sequence,
          text: content
        });
      }
    }

    function acceptLine(line) {
      const trimmed = String(line || "").trim();
      if (trimmed.length === 0) return;
      if (!trimmed.startsWith("data:")) return;
      acceptData(trimmed.slice(5));
    }

    function summary() {
      return {
        text,
        textChars,
        sequence,
        firstTokenMs,
        finishReason,
        doneSeen,
        warningCount,
        dataLineCount,
        parsedJsonCount,
        warnings,
        parserHash: metadataHash({
          text,
          textChars,
          sequence,
          finishReason,
          doneSeen,
          warningCount,
          dataLineCount,
          parsedJsonCount
        })
      };
    }

    return {
      acceptData,
      acceptLine,
      summary
    };
  }

  function parseOpenAiCompatibleSseFixture() {
    const parser = createProviderStreamParser({
      source: "provider-stream-parser-parity",
      canaryMode: "provider-stream-parser-parity",
      runId: "fixture"
    });
    const fixtureLines = [
      'data: {"choices":[{"index":0,"delta":{"role":"assistant"}}]}',
      'data: {"choices":[{"index":0,"delta":{"content":"native"}}]}',
      'data: {"choices":[{"index":0,"delta":{"content":"-ok"}}]}',
      'data: {"choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}',
      "data: {not-json",
      "data: [DONE]"
    ];
    for (const line of fixtureLines) parser.acceptLine(line);
    const parsed = parser.summary();
    return {
      fixture: "openai-compatible-sse-chunks",
      expectedText: "native-ok",
      expectedFinishReason: "stop",
      expectedDoneSeen: true,
      expectedWarningCount: 1,
      parsed,
      parityOk:
        parsed.text === "native-ok" &&
        parsed.finishReason === "stop" &&
        parsed.doneSeen === true &&
        parsed.warningCount === 1 &&
        parsed.sequence === 2
    };
  }

  function normalizeProviderErrorFixture() {
    const rawProviderError = JSON.stringify({
      error: {
        message: "fixture insufficient credits",
        code: "insufficient_credits",
        type: "billing_error"
      }
    });
    const parsed = JSON.parse(rawProviderError);
    const normalizedError = {
      type: parsed.error.type,
      code: parsed.error.code,
      message: parsed.error.message
    };
    return {
      fixture: "provider-error-raw-forwarding",
      statusCode: 402,
      rawProviderError,
      rawProviderErrorForwarded: true,
      normalizedError,
      parityOk:
        normalizedError.type === "billing_error" &&
        normalizedError.code === "insufficient_credits" &&
        normalizedError.message === "fixture insufficient credits" &&
        rawProviderError.includes("fixture insufficient credits")
    };
  }

  function normalizeProviderTimeoutFixture() {
    const timeoutMs = 25;
    const rawProviderError = "AbortError: native_provider_stream_parser_timeout";
    const normalizedError = {
      type: "provider_timeout",
      code: "provider_timeout",
      message: `provider stream timed out after ${timeoutMs}ms`
    };
    return {
      fixture: "provider-timeout-normalization",
      timeoutMs,
      rawProviderError,
      normalizedError,
      aborted: true,
      parityOk:
        normalizedError.type === "provider_timeout" &&
        normalizedError.code === "provider_timeout" &&
        rawProviderError.includes("AbortError")
    };
  }

  function normalizeProviderCancellationFixture() {
    const controller = new AbortController();
    controller.abort("native_stream_parser_parity_cancelled");
    const cancelledFrame = {
      event: "cancelled",
      ok: true,
      runtime: "native-node-embedded",
      source: "provider-stream-parser-parity",
      canaryMode: "provider-stream-parser-parity",
      finishReason: "cancelled",
      providerCallsEnabled: false,
      executionEnabled: false
    };
    return {
      fixture: "provider-cancellation-contract",
      abortControllerCreated: true,
      signalAttached: true,
      signalAborted: controller.signal.aborted === true,
      abortReason: String(controller.signal.reason || ""),
      cancelledFrame,
      parityOk:
        controller.signal.aborted === true &&
        cancelledFrame.finishReason === "cancelled" &&
        cancelledFrame.providerCallsEnabled === false &&
        cancelledFrame.executionEnabled === false
    };
  }

  function providerStreamParserParityFixtures() {
    const chunkFixture = parseOpenAiCompatibleSseFixture();
    const errorFixture = normalizeProviderErrorFixture();
    const timeoutFixture = normalizeProviderTimeoutFixture();
    const cancellationFixture = normalizeProviderCancellationFixture();
    return {
      chunkFixture,
      errorFixture,
      timeoutFixture,
      cancellationFixture,
      parityOk:
        chunkFixture.parityOk &&
        errorFixture.parityOk &&
        timeoutFixture.parityOk &&
        cancellationFixture.parityOk,
      fixtureHash: metadataHash({
        chunk: chunkFixture.parsed.parserHash,
        error: errorFixture.normalizedError,
        timeout: timeoutFixture.normalizedError,
        cancellation: {
          signalAborted: cancellationFixture.signalAborted,
          finishReason: cancellationFixture.cancelledFrame.finishReason
        }
      })
    };
  }

  function nativeMobileToolCatalog() {
    return [
      {
        functionName: "avatar_gesture",
        gatewayName: "avatar.gesture",
        aliases: [
          "avatar.gesture",
          "avatar_gesture",
          "gesture",
          "wave",
          "dance",
          "bow",
          "pose"
        ],
        description:
          "Capture an avatar gesture plan. The native canary records this plan only.",
        parameters: {
          type: "object",
          properties: {
            gesture: {
              type: "string",
              description: "Gesture or VRMA animation name."
            },
            intensity: {
              type: "number",
              minimum: 0,
              maximum: 1
            }
          },
          required: ["gesture"],
          additionalProperties: false
        },
        sampleArguments: { gesture: "wave", intensity: 0.65 }
      },
      {
        functionName: "camera_snap",
        gatewayName: "camera.snap",
        aliases: ["camera.snap", "camera_snap", "camera", "photo", "picture", "selfie"],
        description:
          "Capture a camera snapshot plan. The native canary does not open the camera.",
        parameters: {
          type: "object",
          properties: {
            facing: {
              type: "string",
              enum: ["back", "front"]
            }
          },
          required: [],
          additionalProperties: false
        },
        sampleArguments: { facing: "back" }
      },
      {
        functionName: "canvas_eval",
        gatewayName: "canvas.eval",
        aliases: ["canvas.eval", "canvas_eval", "canvas", "javascript", "js"],
        description:
          "Capture an in-app canvas JavaScript plan. The native canary does not run JavaScript.",
        parameters: {
          type: "object",
          properties: {
            js: {
              type: "string",
              description: "JavaScript to run in the in-app canvas."
            }
          },
          required: ["js"],
          additionalProperties: false
        },
        sampleArguments: { js: "document.title" }
      },
      {
        functionName: "canvas_navigate",
        gatewayName: "canvas.navigate",
        aliases: ["canvas.navigate", "canvas_navigate", "navigate", "open url", "website"],
        description:
          "Capture an in-app canvas navigation plan. The native canary does not navigate.",
        parameters: {
          type: "object",
          properties: {
            url: {
              type: "string",
              description: "Absolute URL to open in the in-app canvas."
            }
          },
          required: ["url"],
          additionalProperties: false
        },
        sampleArguments: { url: "https://example.com" }
      },
      {
        functionName: "canvas_snapshot",
        gatewayName: "canvas.snapshot",
        aliases: ["canvas.snapshot", "canvas_snapshot", "snapshot", "screenshot"],
        description:
          "Capture an in-app canvas snapshot plan. The native canary does not capture pixels.",
        parameters: {
          type: "object",
          properties: {},
          required: [],
          additionalProperties: false
        },
        sampleArguments: {}
      },
      {
        functionName: "haptic_vibrate",
        gatewayName: "haptic.vibrate",
        aliases: ["haptic.vibrate", "haptic_vibrate", "vibrate", "buzz", "haptic"],
        description:
          "Capture a vibration plan. The native canary does not vibrate the phone.",
        parameters: {
          type: "object",
          properties: {
            durationMs: {
              type: "integer",
              minimum: 50,
              maximum: 2000
            }
          },
          required: [],
          additionalProperties: false
        },
        sampleArguments: { durationMs: 250 }
      },
      {
        functionName: "sensor_read",
        gatewayName: "sensor.read",
        aliases: ["sensor.read", "sensor_read", "sensor", "accelerometer", "gyroscope"],
        description:
          "Capture a phone sensor read plan. The native canary does not read sensors.",
        parameters: {
          type: "object",
          properties: {
            sensor: {
              type: "string",
              enum: ["accelerometer", "gyroscope", "magnetometer", "barometer"]
            }
          },
          required: [],
          additionalProperties: false
        },
        sampleArguments: { sensor: "accelerometer" }
      },
      {
        functionName: "sensor_list",
        gatewayName: "sensor.list",
        aliases: ["sensor.list", "sensor_list", "list sensors", "sensors"],
        description:
          "Capture a sensor list plan. The native canary does not query Android sensors.",
        parameters: {
          type: "object",
          properties: {},
          required: [],
          additionalProperties: false
        },
        sampleArguments: {}
      },
      {
        functionName: "flash_status",
        gatewayName: "flash.status",
        aliases: ["flash.status", "flash_status", "torch", "flashlight", "flash"],
        description:
          "Capture a flashlight status plan. The native canary does not touch the flashlight.",
        parameters: {
          type: "object",
          properties: {},
          required: [],
          additionalProperties: false
        },
        sampleArguments: {}
      },
      {
        functionName: "device_status",
        gatewayName: "device.status",
        aliases: ["device_status", "device.status", "battery", "device", "phone status"],
        description:
          "Capture a device status plan. The native canary does not query device state.",
        parameters: {
          type: "object",
          properties: {},
          required: [],
          additionalProperties: false
        },
        sampleArguments: {}
      }
    ];
  }

  function toolSchemaForCatalogEntry(entry) {
    return {
      type: "function",
      function: {
        name: entry.functionName,
        description: entry.description,
        parameters: entry.parameters
      },
      gatewayName: entry.gatewayName
    };
  }

  function selectNativeMobileTools(payload, shape, { maxTools = 8 } = {}) {
    const params = payload && typeof payload.params === "object" && payload.params !== null
      ? payload.params
      : {};
    const message = typeof params.message === "string" ? params.message : "";
    const lower = message.toLowerCase();
    const hints = Array.isArray(shape.mobileToolHints) ? shape.mobileToolHints : [];
    const asksAboutTools =
      /\b(tool|tools|capabilit|what can you do|available)\b/.test(lower);
    const catalog = nativeMobileToolCatalog();
    const selected = [];

    for (const entry of catalog) {
      const aliasMatched = entry.aliases.some((alias) =>
        lower.includes(alias.toLowerCase()) || hints.includes(alias)
      );
      if (aliasMatched || asksAboutTools) {
        selected.push(entry);
      }
      if (selected.length >= maxTools) break;
    }

    if (selected.length === 0) {
      selected.push(catalog[0]);
    }

    const toolSchemas = selected.map(toolSchemaForCatalogEntry);
    return {
      tools: selected,
      toolSchemas,
      toolFunctionNames: selected.map((entry) => entry.functionName).sort(),
      gatewayToolNames: selected.map((entry) => entry.gatewayName).sort(),
      toolAliasMap: Object.fromEntries(
        selected.map((entry) => [entry.functionName, entry.gatewayName])
      ),
      selectionHash: metadataHash({
        toolFunctionNames: selected.map((entry) => entry.functionName).sort(),
        gatewayToolNames: selected.map((entry) => entry.gatewayName).sort()
      })
    };
  }

  function providerToolPlanRequestBuilder(envelope, shape, queued, payload) {
    const selected = selectNativeMobileTools(payload, shape);
    const normalizedHeaders = {
      accept: "text/event-stream",
      authorization: "Bearer <redacted-or-missing>",
      "content-type": "application/json",
      "http-referer": "<redacted-or-missing>",
      "x-title": "<redacted-or-missing>"
    };
    const normalizedBody = {
      model: envelope.providerModel,
      messages: [
        {
          role: "system",
          content: "<redacted>",
          chars: 163
        },
        {
          role: "user",
          content: "<redacted>",
          chars: shape.messageChars
        }
      ],
      stream: true,
      tools: selected.toolSchemas,
      tool_choice: "auto"
    };
    const headerValidation = {
      contentTypeOk: normalizedHeaders["content-type"] === "application/json",
      acceptOk: normalizedHeaders.accept === "text/event-stream",
      authorizationPolicy: "required_for_future_network_call",
      authMaterialStatus: "not_loaded_for_tool_plan_canary",
      forbiddenHeadersPresent: false,
      rawSecretsPresent: false
    };
    const bodyValidation = {
      modelPresent: typeof normalizedBody.model === "string" && normalizedBody.model.length > 0,
      messagesNormalized: normalizedBody.messages.length === 2,
      rawPromptRedacted: normalizedBody.messages.every((message) =>
        message.content === "<redacted>"
      ),
      streamMode: normalizedBody.stream === true,
      toolSchemasAttached: normalizedBody.tools.length > 0,
      toolChoice: normalizedBody.tool_choice,
      toolNamesValid: selected.toolFunctionNames.every((name) =>
        /^[a-zA-Z0-9_-]{1,64}$/.test(name)
      )
    };
    const headersHash = metadataHash(normalizedHeaders);
    const bodyHash = metadataHash(normalizedBody);
    const requestHash = metadataHash({
      provider: envelope.provider,
      providerModel: envelope.providerModel,
      transport: envelope.transport,
      headers: normalizedHeaders,
      body: normalizedBody,
      envelopeHash: envelope.envelopeHash,
      toolSelectionHash: selected.selectionHash,
      transportInvocationEnabled: false,
      providerCallsEnabled: false,
      executionEnabled: false
    });

    return {
      provider: envelope.provider,
      requestedModel: envelope.requestedModel,
      providerModel: envelope.providerModel,
      transport: envelope.transport,
      method: envelope.method,
      endpointRedacted: envelope.endpointRedacted,
      normalizedHeaders,
      normalizedBody,
      headerValidation,
      bodyValidation,
      selectedToolCount: selected.tools.length,
      toolFunctionNames: selected.toolFunctionNames,
      gatewayToolNames: selected.gatewayToolNames,
      toolAliasMap: selected.toolAliasMap,
      toolSelectionHash: selected.selectionHash,
      headersHash,
      bodyHash,
      requestHash,
      validationOk:
        headerValidation.contentTypeOk &&
        headerValidation.acceptOk &&
        headerValidation.forbiddenHeadersPresent === false &&
        headerValidation.rawSecretsPresent === false &&
        bodyValidation.modelPresent &&
        bodyValidation.messagesNormalized &&
        bodyValidation.rawPromptRedacted &&
        bodyValidation.streamMode &&
        bodyValidation.toolSchemasAttached &&
        bodyValidation.toolNamesValid,
      request: {
        metadataHash: shape.metadataHash,
        sessionKey: shape.sessionKey,
        messageChars: shape.messageChars,
        mobileToolHints: shape.mobileToolHints
      },
      run: {
        requestId: queued.requestId,
        runId: queued.runId
      },
      providerCallsEnabled: false,
      transportInvocationEnabled: false,
      executionEnabled: false,
      toolExecutionEnabled: false,
      stopBefore: "provider_fetch_or_tool_dispatch",
      transportGate: {
        enabled: false,
        status: "blocked",
        reason: "tool_plan_capture_only_until_canary_gate",
        blockedBefore: "fetch_or_tool_dispatch"
      }
    };
  }

  function createProviderToolPlanParser({
    source,
    canaryMode,
    runId,
    allowedTools,
    toolAliasMap,
    writeEvent = null
  }) {
    const allowed = new Set(allowedTools || []);
    const aliasMap = toolAliasMap || {};
    const calls = new Map();
    let finishReason = null;
    let doneSeen = false;
    let warningCount = 0;
    let dataLineCount = 0;
    let parsedJsonCount = 0;
    const warnings = [];

    function warning(code, message, rawChunk) {
      warningCount += 1;
      const entry = {
        code,
        message,
        rawChunk: String(rawChunk || "").slice(0, 500)
      };
      warnings.push(entry);
      if (writeEvent) {
        writeEvent("tool_plan_parse_warning", {
          ok: false,
          runtime: "native-node-embedded",
          source,
          canaryMode,
          runId,
          warning: entry
        });
      }
    }

    function ensureCall(rawCall, fallbackIndex) {
      const index = Number.isInteger(rawCall?.index) ? rawCall.index : fallbackIndex;
      const key = Number.isInteger(index)
        ? `index:${index}`
        : `call:${calls.size}`;
      if (!calls.has(key)) {
        calls.set(key, {
          index,
          id: null,
          type: "function",
          functionName: "",
          gatewayName: null,
          argumentsText: ""
        });
      }
      return calls.get(key);
    }

    function acceptToolCalls(rawToolCalls) {
      if (!Array.isArray(rawToolCalls)) return;
      rawToolCalls.forEach((rawCall, fallbackIndex) => {
        if (!rawCall || typeof rawCall !== "object") return;
        const call = ensureCall(rawCall, fallbackIndex);
        if (typeof rawCall.id === "string" && rawCall.id.length > 0) {
          call.id = rawCall.id;
        }
        if (typeof rawCall.type === "string" && rawCall.type.length > 0) {
          call.type = rawCall.type;
        }
        const fn = rawCall.function && typeof rawCall.function === "object"
          ? rawCall.function
          : {};
        if (typeof fn.name === "string" && fn.name.length > 0) {
          call.functionName = fn.name;
          call.gatewayName = aliasMap[fn.name] || fn.name;
        }
        if (typeof fn.arguments === "string") {
          call.argumentsText += fn.arguments;
        }
        if (writeEvent && call.functionName) {
          writeEvent("tool_plan_delta", {
            ok: true,
            runtime: "native-node-embedded",
            source,
            canaryMode,
            runId,
            index: call.index,
            id: call.id,
            functionName: call.functionName,
            gatewayName: call.gatewayName,
            argumentChars: call.argumentsText.length
          });
        }
      });
    }

    function acceptDecoded(decoded) {
      if (!decoded || typeof decoded !== "object") return;
      const choices = Array.isArray(decoded.choices) ? decoded.choices : [];
      const choice = choices[0] && typeof choices[0] === "object"
        ? choices[0]
        : null;
      if (!choice) return;
      if (choice.finish_reason) finishReason = choice.finish_reason;
      const delta = choice.delta && typeof choice.delta === "object"
        ? choice.delta
        : null;
      const message = choice.message && typeof choice.message === "object"
        ? choice.message
        : null;
      acceptToolCalls(delta?.tool_calls);
      acceptToolCalls(message?.tool_calls);
    }

    function acceptData(data) {
      const trimmed = String(data || "").trim();
      if (trimmed.length === 0) return;
      dataLineCount += 1;
      if (trimmed === "[DONE]") {
        doneSeen = true;
        if (!finishReason) finishReason = "done";
        return;
      }

      let decoded;
      try {
        decoded = JSON.parse(trimmed);
        parsedJsonCount += 1;
      } catch (error) {
        warning("tool_plan_chunk_parse_failed", error.message || String(error), trimmed);
        return;
      }
      acceptDecoded(decoded);
    }

    function acceptLine(line) {
      const trimmed = String(line || "").trim();
      if (trimmed.length === 0) return;
      if (!trimmed.startsWith("data:")) return;
      acceptData(trimmed.slice(5));
    }

    function summary() {
      const plans = Array.from(calls.values()).map((call) => {
        let parsedArguments = null;
        let argumentsOk = false;
        let argumentError = null;
        try {
          parsedArguments = call.argumentsText.trim().length === 0
            ? {}
            : JSON.parse(call.argumentsText);
          argumentsOk =
            parsedArguments !== null &&
            typeof parsedArguments === "object" &&
            !Array.isArray(parsedArguments);
        } catch (error) {
          argumentError = error.message || String(error);
        }
        const allowedName = allowed.has(call.functionName);
        const blockedReason = !allowedName
          ? "tool_not_in_attached_schema"
          : (!argumentsOk ? "invalid_tool_arguments" : null);
        const gatewayName = call.gatewayName || aliasMap[call.functionName] || call.functionName;
        return {
          index: call.index,
          id: call.id,
          type: call.type,
          functionName: call.functionName,
          gatewayName,
          argumentsTextChars: call.argumentsText.length,
          arguments: argumentsOk ? parsedArguments : null,
          argumentsOk,
          argumentError,
          allowedName,
          blockedReason,
          executionEnabled: false,
          planHash: metadataHash({
            functionName: call.functionName,
            gatewayName,
            argumentsText: call.argumentsText,
            allowedName,
            argumentsOk,
            blockedReason
          })
        };
      });
      const allowedPlanCount = plans.filter((plan) =>
        plan.allowedName && plan.argumentsOk
      ).length;
      const blockedPlanCount = plans.filter((plan) => plan.blockedReason).length;
      const invalidArgumentCount = plans.filter((plan) =>
        plan.blockedReason === "invalid_tool_arguments"
      ).length;
      const unknownToolCount = plans.filter((plan) =>
        plan.blockedReason === "tool_not_in_attached_schema"
      ).length;
      const toolPlanHash = metadataHash({
        plans: plans.map((plan) => ({
          functionName: plan.functionName,
          gatewayName: plan.gatewayName,
          planHash: plan.planHash,
          blockedReason: plan.blockedReason
        })),
        finishReason,
        doneSeen,
        warningCount
      });

      return {
        toolPlanCount: plans.length,
        toolPlanNames: plans.map((plan) => plan.functionName).sort(),
        gatewayToolNames: plans.map((plan) => plan.gatewayName).sort(),
        allowedPlanCount,
        blockedPlanCount,
        invalidArgumentCount,
        unknownToolCount,
        finishReason,
        doneSeen,
        warningCount,
        dataLineCount,
        parsedJsonCount,
        warnings,
        plans,
        toolPlanHash,
        executionEnabled: false,
        toolExecutionEnabled: false
      };
    }

    return {
      acceptData,
      acceptLine,
      summary
    };
  }

  function toolArgumentsForFixture(tool) {
    return tool?.sampleArguments && typeof tool.sampleArguments === "object"
      ? tool.sampleArguments
      : {};
  }

  function parseStreamingToolPlanFixture(toolSelection) {
    const tool = toolSelection.tools[0] || nativeMobileToolCatalog()[0];
    const parser = createProviderToolPlanParser({
      source: "provider-tool-plan-canary",
      canaryMode: "provider-tool-plan-canary",
      runId: "fixture",
      allowedTools: toolSelection.toolFunctionNames,
      toolAliasMap: toolSelection.toolAliasMap
    });
    const argsText = JSON.stringify(toolArgumentsForFixture(tool));
    const first = argsText.slice(0, Math.ceil(argsText.length / 2));
    const second = argsText.slice(first.length);
    parser.acceptData(JSON.stringify({
      choices: [
        {
          delta: {
            tool_calls: [
              {
                index: 0,
                id: "call_native_tool_plan_0",
                type: "function",
                function: {
                  name: tool.functionName,
                  arguments: first
                }
              }
            ]
          }
        }
      ]
    }));
    parser.acceptData(JSON.stringify({
      choices: [
        {
          delta: {
            tool_calls: [
              {
                index: 0,
                function: {
                  arguments: second
                }
              }
            ]
          }
        }
      ]
    }));
    parser.acceptData(JSON.stringify({
      choices: [
        {
          delta: {},
          finish_reason: "tool_calls"
        }
      ]
    }));
    parser.acceptData("[DONE]");
    const parsed = parser.summary();
    return {
      fixture: "openai-compatible-streaming-tool-call",
      expectedTool: tool.functionName,
      parsed,
      parityOk:
        parsed.toolPlanCount === 1 &&
        parsed.allowedPlanCount === 1 &&
        parsed.blockedPlanCount === 0 &&
        parsed.invalidArgumentCount === 0 &&
        parsed.finishReason === "tool_calls" &&
        parsed.doneSeen === true
    };
  }

  function parseMessageToolPlanFixture(toolSelection) {
    const tool = toolSelection.tools[1] || toolSelection.tools[0] || nativeMobileToolCatalog()[0];
    const parser = createProviderToolPlanParser({
      source: "provider-tool-plan-canary",
      canaryMode: "provider-tool-plan-canary",
      runId: "fixture",
      allowedTools: toolSelection.toolFunctionNames,
      toolAliasMap: toolSelection.toolAliasMap
    });
    parser.acceptData(JSON.stringify({
      choices: [
        {
          message: {
            role: "assistant",
            tool_calls: [
              {
                id: "call_native_tool_plan_1",
                type: "function",
                function: {
                  name: tool.functionName,
                  arguments: JSON.stringify(toolArgumentsForFixture(tool))
                }
              }
            ]
          },
          finish_reason: "tool_calls"
        }
      ]
    }));
    const parsed = parser.summary();
    return {
      fixture: "openai-compatible-message-tool-call",
      expectedTool: tool.functionName,
      parsed,
      parityOk:
        parsed.toolPlanCount === 1 &&
        parsed.allowedPlanCount === 1 &&
        parsed.blockedPlanCount === 0 &&
        parsed.invalidArgumentCount === 0 &&
        parsed.finishReason === "tool_calls"
    };
  }

  function parseUnknownToolFixture(toolSelection) {
    const parser = createProviderToolPlanParser({
      source: "provider-tool-plan-canary",
      canaryMode: "provider-tool-plan-canary",
      runId: "fixture",
      allowedTools: toolSelection.toolFunctionNames,
      toolAliasMap: toolSelection.toolAliasMap
    });
    parser.acceptData(JSON.stringify({
      choices: [
        {
          delta: {
            tool_calls: [
              {
                index: 0,
                id: "call_unknown_tool",
                type: "function",
                function: {
                  name: "unknown_destructive_tool",
                  arguments: "{}"
                }
              }
            ]
          },
          finish_reason: "tool_calls"
        }
      ]
    }));
    const parsed = parser.summary();
    return {
      fixture: "unknown-tool-rejected",
      parsed,
      parityOk:
        parsed.toolPlanCount === 1 &&
        parsed.allowedPlanCount === 0 &&
        parsed.blockedPlanCount === 1 &&
        parsed.unknownToolCount === 1 &&
        parsed.plans[0]?.blockedReason === "tool_not_in_attached_schema"
    };
  }

  function parseMalformedArgumentsFixture(toolSelection) {
    const tool = toolSelection.tools[0] || nativeMobileToolCatalog()[0];
    const parser = createProviderToolPlanParser({
      source: "provider-tool-plan-canary",
      canaryMode: "provider-tool-plan-canary",
      runId: "fixture",
      allowedTools: toolSelection.toolFunctionNames,
      toolAliasMap: toolSelection.toolAliasMap
    });
    parser.acceptData(JSON.stringify({
      choices: [
        {
          delta: {
            tool_calls: [
              {
                index: 0,
                id: "call_bad_args",
                type: "function",
                function: {
                  name: tool.functionName,
                  arguments: "{not-json"
                }
              }
            ]
          },
          finish_reason: "tool_calls"
        }
      ]
    }));
    const parsed = parser.summary();
    return {
      fixture: "malformed-tool-arguments-rejected",
      expectedTool: tool.functionName,
      parsed,
      parityOk:
        parsed.toolPlanCount === 1 &&
        parsed.allowedPlanCount === 0 &&
        parsed.blockedPlanCount === 1 &&
        parsed.invalidArgumentCount === 1 &&
        parsed.plans[0]?.blockedReason === "invalid_tool_arguments"
    };
  }

  function providerToolPlanFixtures(toolSelection) {
    const streamingFixture = parseStreamingToolPlanFixture(toolSelection);
    const messageFixture = parseMessageToolPlanFixture(toolSelection);
    const unknownFixture = parseUnknownToolFixture(toolSelection);
    const malformedFixture = parseMalformedArgumentsFixture(toolSelection);
    const parityOk =
      streamingFixture.parityOk &&
      messageFixture.parityOk &&
      unknownFixture.parityOk &&
      malformedFixture.parityOk;
    const fixtureHash = metadataHash({
      streamingHash: streamingFixture.parsed.toolPlanHash,
      messageHash: messageFixture.parsed.toolPlanHash,
      unknownHash: unknownFixture.parsed.toolPlanHash,
      malformedHash: malformedFixture.parsed.toolPlanHash,
      parityOk
    });
    return {
      streamingFixture,
      messageFixture,
      unknownFixture,
      malformedFixture,
      parityOk,
      fixtureHash
    };
  }

  function capabilityRouteForToolPlan(plan) {
    const gatewayName = plan?.gatewayName || plan?.functionName || "unknown";
    const routes = {
      "avatar.gesture": {
        capability: "avatar",
        dartCapability: "AvatarCapability",
        method: "avatar.gesture",
        requiresUiThread: true
      },
      "camera.snap": {
        capability: "camera",
        dartCapability: "CameraCapability",
        method: "camera.snap",
        requiresUiThread: true
      },
      "canvas.eval": {
        capability: "canvas",
        dartCapability: "CanvasCapability",
        method: "canvas.eval",
        requiresUiThread: true
      },
      "canvas.navigate": {
        capability: "canvas",
        dartCapability: "CanvasCapability",
        method: "canvas.navigate",
        requiresUiThread: true
      },
      "canvas.snapshot": {
        capability: "canvas",
        dartCapability: "CanvasCapability",
        method: "canvas.snapshot",
        requiresUiThread: true
      },
      "haptic.vibrate": {
        capability: "haptic",
        dartCapability: "HapticCapability",
        method: "haptic.vibrate",
        requiresUiThread: false
      },
      "sensor.read": {
        capability: "sensor",
        dartCapability: "SensorCapability",
        method: "sensor.read",
        requiresUiThread: false
      },
      "sensor.list": {
        capability: "sensor",
        dartCapability: "SensorCapability",
        method: "sensor.list",
        requiresUiThread: false
      },
      "flash.status": {
        capability: "flash",
        dartCapability: "FlashCapability",
        method: "flash.status",
        requiresUiThread: false
      },
      "device.status": {
        capability: "device",
        dartCapability: "DeviceStatusCapability",
        method: "device.status",
        requiresUiThread: false
      }
    };
    return routes[gatewayName] || {
      capability: "unknown",
      dartCapability: "UnknownCapability",
      method: gatewayName,
      requiresUiThread: false
    };
  }

  function syntheticToolDispatchDryRun(toolSelection, queued) {
    const fixture = parseStreamingToolPlanFixture(toolSelection);
    const plan = fixture.parsed.plans[0] || null;
    const route = capabilityRouteForToolPlan(plan);
    const canDispatch =
      fixture.parityOk &&
      plan &&
      plan.allowedName === true &&
      plan.argumentsOk === true &&
      route.capability !== "unknown";
    const callId = plan?.id || stableId("native-tool-call", {
      runId: queued.runId,
      functionName: plan?.functionName,
      planHash: plan?.planHash
    });
    const toolUseFrame = {
      type: "tool_use",
      id: callId,
      name: route.method,
      input: plan?.arguments || {},
      runtime: "native-node-embedded",
      source: "tool-dispatch-dry-run",
      executionEnabled: false,
      toolExecutionEnabled: false,
      planHash: plan?.planHash || null
    };
    const syntheticResult = {
      ok: canDispatch,
      dryRun: true,
      skipped: true,
      skippedReason: "native_tool_execution_disabled",
      runtime: "native-node-embedded",
      source: "tool-dispatch-dry-run",
      capability: route.capability,
      dartCapability: route.dartCapability,
      method: route.method,
      requiresUiThread: route.requiresUiThread,
      wouldExecute: canDispatch,
      executionEnabled: false,
      toolExecutionEnabled: false,
      planHash: plan?.planHash || null
    };
    const toolResultFrame = {
      type: "tool_result",
      id: callId,
      name: route.method,
      result: syntheticResult,
      runtime: "native-node-embedded",
      source: "tool-dispatch-dry-run",
      executionEnabled: false,
      toolExecutionEnabled: false
    };
    const dispatchHash = metadataHash({
      callId,
      route,
      toolUseFrame,
      syntheticResult,
      fixtureHash: fixture.parsed.toolPlanHash
    });

    return {
      fixture,
      plan,
      route,
      callId,
      canDispatch,
      toolUseFrame,
      toolResultFrame,
      dispatchHash,
      parityOk:
        canDispatch &&
        toolUseFrame.type === "tool_use" &&
        toolResultFrame.type === "tool_result" &&
        toolResultFrame.result.skippedReason === "native_tool_execution_disabled" &&
        toolUseFrame.toolExecutionEnabled === false &&
        toolResultFrame.toolExecutionEnabled === false
    };
  }

  function postJsonToDartBridge(
    pathname,
    body,
    timeoutMs = 2500,
    bridgeMode = "dry-run"
  ) {
    const payload = Buffer.from(JSON.stringify(body), "utf8");
    return new Promise((resolve, reject) => {
      const request = http.request({
        hostname: "127.0.0.1",
        port: 8765,
        path: pathname,
        method: "POST",
        timeout: timeoutMs,
        headers: {
          "content-type": "application/json",
          "content-length": String(payload.length),
          "x-plawie-native-bridge": bridgeMode
        }
      }, (response) => {
        const chunks = [];
        response.on("data", (chunk) => chunks.push(chunk));
        response.on("end", () => {
          const rawBody = Buffer.concat(chunks).toString("utf8");
          let jsonBody = {};
          try {
            jsonBody = rawBody.trim().length === 0 ? {} : JSON.parse(rawBody);
          } catch (error) {
            reject(Object.assign(new Error("dart_bridge_invalid_json"), {
              code: "dart_bridge_invalid_json",
              statusCode: response.statusCode,
              raw: rawBody,
              cause: error.message
            }));
            return;
          }
          if (response.statusCode < 200 || response.statusCode >= 300) {
            reject(Object.assign(new Error("dart_bridge_http_error"), {
              code: "dart_bridge_http_error",
              statusCode: response.statusCode,
              raw: rawBody,
              body: jsonBody
            }));
            return;
          }
          resolve({
            statusCode: response.statusCode,
            body: jsonBody,
            raw: rawBody,
            responseBytesRead: Buffer.byteLength(rawBody, "utf8")
          });
        });
      });
      request.on("timeout", () => {
        request.destroy(Object.assign(new Error("dart_bridge_timeout"), {
          code: "dart_bridge_timeout",
          timeoutMs
        }));
      });
      request.on("error", reject);
      request.write(payload);
      request.end();
    });
  }

  function nativeDartBridgeDryRunRequest(dispatch, queued, requestBuilder) {
    const bridgeRequest = {
      type: "native_tool_dispatch_dry_run",
      runtime: "native-node-embedded",
      source: "native-dart-bridge-dry-run",
      canaryMode: "native-dart-bridge-dry-run",
      runId: queued.runId,
      requestId: queued.requestId,
      nativeSessionId: queued.nativeSessionId,
      callId: dispatch.callId,
      method: dispatch.route.method,
      capability: dispatch.route.capability,
      dartCapability: dispatch.route.dartCapability,
      requiresUiThread: dispatch.route.requiresUiThread,
      input: dispatch.toolUseFrame.input,
      toolUseFrame: dispatch.toolUseFrame,
      dispatchHash: dispatch.dispatchHash,
      requestHash: requestBuilder.requestHash,
      toolSelectionHash: requestBuilder.toolSelectionHash,
      dryRun: true,
      providerCallsEnabled: false,
      executionEnabled: false,
      toolExecutionEnabled: false,
      bridgeExecutionEnabled: false
    };
    return {
      ...bridgeRequest,
      bridgeRequestHash: metadataHash({
        type: bridgeRequest.type,
        runId: bridgeRequest.runId,
        callId: bridgeRequest.callId,
        method: bridgeRequest.method,
        capability: bridgeRequest.capability,
        input: bridgeRequest.input,
        dispatchHash: bridgeRequest.dispatchHash,
        requestHash: bridgeRequest.requestHash,
        dryRun: bridgeRequest.dryRun,
        executionEnabled: bridgeRequest.executionEnabled,
        toolExecutionEnabled: bridgeRequest.toolExecutionEnabled
      })
    };
  }

  function nativeDartBridgeOrderedRequest(bridgeRequest, orderIndex, orderCount) {
    const ordered = {
      ...bridgeRequest,
      source: "native-dart-bridge-ordering-cancel",
      canaryMode: "native-dart-bridge-ordering-cancel",
      orderIndex,
      orderCount,
      orderingKey: `${bridgeRequest.nativeSessionId}:${orderIndex}`,
      cancellationToken: stableId("native-cancel-token", {
        runId: bridgeRequest.runId,
        callId: bridgeRequest.callId,
        orderIndex,
        dispatchHash: bridgeRequest.dispatchHash
      }),
      bridgeExecutionEnabled: false,
      toolExecutionEnabled: false,
      executionEnabled: false
    };
    return {
      ...ordered,
      bridgeRequestHash: metadataHash({
        type: ordered.type,
        runId: ordered.runId,
        callId: ordered.callId,
        method: ordered.method,
        capability: ordered.capability,
        input: ordered.input,
        dispatchHash: ordered.dispatchHash,
        requestHash: ordered.requestHash,
        orderIndex: ordered.orderIndex,
        orderCount: ordered.orderCount,
        cancellationToken: ordered.cancellationToken,
        dryRun: ordered.dryRun,
        executionEnabled: ordered.executionEnabled,
        toolExecutionEnabled: ordered.toolExecutionEnabled,
        bridgeExecutionEnabled: ordered.bridgeExecutionEnabled
      })
    };
  }

  function nativeDartBridgeCancelDryRunRequest(target, reason) {
    const cancelRequest = {
      type: "native_tool_dispatch_cancel_dry_run",
      runtime: "native-node-embedded",
      source: "native-dart-bridge-ordering-cancel",
      canaryMode: "native-dart-bridge-ordering-cancel",
      targetRunId: target.runId,
      targetRequestId: target.requestId,
      targetCallId: target.callId,
      targetBridgeRequestHash: target.bridgeRequestHash,
      targetDispatchHash: target.dispatchHash,
      orderIndex: target.orderIndex,
      orderCount: target.orderCount,
      cancellationToken: target.cancellationToken,
      reason,
      dryRun: true,
      providerCallsEnabled: false,
      executionEnabled: false,
      toolExecutionEnabled: false,
      bridgeExecutionEnabled: false
    };
    return {
      ...cancelRequest,
      cancelRequestHash: metadataHash({
        type: cancelRequest.type,
        targetRunId: cancelRequest.targetRunId,
        targetCallId: cancelRequest.targetCallId,
        targetBridgeRequestHash: cancelRequest.targetBridgeRequestHash,
        cancellationToken: cancelRequest.cancellationToken,
        reason: cancelRequest.reason,
        dryRun: cancelRequest.dryRun,
        executionEnabled: cancelRequest.executionEnabled,
        toolExecutionEnabled: cancelRequest.toolExecutionEnabled,
        bridgeExecutionEnabled: cancelRequest.bridgeExecutionEnabled
      })
    };
  }

  function nativeHapticCanaryToolSelection() {
    const baseTool = nativeMobileToolCatalog().find((entry) =>
      entry.gatewayName === "haptic.vibrate"
    );
    if (!baseTool) {
      throw Object.assign(new Error("haptic_canary_tool_missing"), {
        code: "haptic_canary_tool_missing"
      });
    }
    const tool = {
      ...baseTool,
      description:
        "Execute one bounded haptic vibration canary through the native-to-Dart bridge.",
      sampleArguments: { durationMs: 90 }
    };
    const toolFunctionNames = [tool.functionName];
    const gatewayToolNames = [tool.gatewayName];
    const toolAliasMap = { [tool.functionName]: tool.gatewayName };
    return {
      tools: [tool],
      toolFunctionNames,
      gatewayToolNames,
      toolAliasMap,
      selectionHash: metadataHash({
        toolFunctionNames,
        gatewayToolNames,
        canaryAllowlist: ["haptic.vibrate"],
        durationMs: tool.sampleArguments.durationMs
      })
    };
  }

  function nativeDartBridgeHapticCanaryRequest(
    dispatch,
    queued,
    requestBuilder
  ) {
    const source = "native-dart-bridge-haptic-canary";
    const canaryMode = "native-dart-bridge-haptic-canary";
    const canaryAllowlist = ["haptic.vibrate"];
    const input = { durationMs: 90 };
    const cancellationToken = stableId("native-haptic-cancel-token", {
      runId: queued.runId,
      callId: dispatch.callId,
      dispatchHash: dispatch.dispatchHash
    });
    const toolUseFrame = {
      ...dispatch.toolUseFrame,
      source,
      input,
      dryRun: false,
      canaryOnly: true,
      canaryMode,
      cancellationToken,
      executionEnabled: true,
      toolExecutionEnabled: true
    };
    const executeDispatchHash = metadataHash({
      callId: dispatch.callId,
      route: dispatch.route,
      toolUseFrame,
      fixtureHash: dispatch.fixture.parsed.toolPlanHash,
      canaryAllowlist,
      dryRun: false,
      executionEnabled: true,
      toolExecutionEnabled: true,
      bridgeExecutionEnabled: true
    });
    const bridgeRequest = {
      type: "native_tool_dispatch_execute_canary",
      runtime: "native-node-embedded",
      source,
      canaryMode,
      canaryOnly: true,
      runId: queued.runId,
      requestId: queued.requestId,
      nativeSessionId: queued.nativeSessionId,
      callId: dispatch.callId,
      method: dispatch.route.method,
      capability: dispatch.route.capability,
      dartCapability: dispatch.route.dartCapability,
      requiresUiThread: dispatch.route.requiresUiThread,
      input,
      toolUseFrame,
      dispatchHash: executeDispatchHash,
      requestHash: requestBuilder.requestHash,
      toolSelectionHash: requestBuilder.toolSelectionHash,
      canaryAllowlist,
      cancellationToken,
      dryRun: false,
      providerCallsEnabled: false,
      executionEnabled: true,
      toolExecutionEnabled: true,
      bridgeExecutionEnabled: true
    };
    return {
      ...bridgeRequest,
      bridgeRequestHash: metadataHash({
        type: bridgeRequest.type,
        source: bridgeRequest.source,
        runId: bridgeRequest.runId,
        callId: bridgeRequest.callId,
        method: bridgeRequest.method,
        capability: bridgeRequest.capability,
        input: bridgeRequest.input,
        dispatchHash: bridgeRequest.dispatchHash,
        requestHash: bridgeRequest.requestHash,
        canaryAllowlist: bridgeRequest.canaryAllowlist,
        cancellationToken: bridgeRequest.cancellationToken,
        dryRun: bridgeRequest.dryRun,
        providerCallsEnabled: bridgeRequest.providerCallsEnabled,
        executionEnabled: bridgeRequest.executionEnabled,
        toolExecutionEnabled: bridgeRequest.toolExecutionEnabled,
        bridgeExecutionEnabled: bridgeRequest.bridgeExecutionEnabled
      })
    };
  }

  function nativeReadOnlyCanaryToolSelection(gatewayName, canaryAllowlist) {
    const baseTool = nativeMobileToolCatalog().find((entry) =>
      entry.gatewayName === gatewayName
    );
    if (!baseTool) {
      throw Object.assign(new Error("readonly_canary_tool_missing"), {
        code: "readonly_canary_tool_missing",
        gatewayName
      });
    }
    const tool = {
      ...baseTool,
      description:
        `Execute one read-only ${gatewayName} canary through the native-to-Dart bridge.`,
      sampleArguments: {}
    };
    const toolFunctionNames = [tool.functionName];
    const gatewayToolNames = [tool.gatewayName];
    const toolAliasMap = { [tool.functionName]: tool.gatewayName };
    return {
      tools: [tool],
      toolFunctionNames,
      gatewayToolNames,
      toolAliasMap,
      selectionHash: metadataHash({
        toolFunctionNames,
        gatewayToolNames,
        canaryAllowlist,
        readOnly: true
      })
    };
  }

  function nativeDartBridgeReadOnlyCanaryRequest(
    dispatch,
    queued,
    requestBuilder,
    orderIndex,
    orderCount,
    canaryAllowlist
  ) {
    const source = "native-dart-bridge-readonly-canary";
    const canaryMode = "native-dart-bridge-readonly-canary";
    const input = {};
    const cancellationToken = stableId("native-readonly-cancel-token", {
      runId: queued.runId,
      callId: dispatch.callId,
      orderIndex,
      dispatchHash: dispatch.dispatchHash
    });
    const toolUseFrame = {
      ...dispatch.toolUseFrame,
      source,
      input,
      dryRun: false,
      readOnly: true,
      canaryOnly: true,
      canaryMode,
      orderIndex,
      orderCount,
      cancellationToken,
      executionEnabled: true,
      toolExecutionEnabled: true
    };
    const executeDispatchHash = metadataHash({
      callId: dispatch.callId,
      route: dispatch.route,
      toolUseFrame,
      fixtureHash: dispatch.fixture.parsed.toolPlanHash,
      canaryAllowlist,
      orderIndex,
      orderCount,
      readOnly: true,
      dryRun: false,
      executionEnabled: true,
      toolExecutionEnabled: true,
      bridgeExecutionEnabled: true
    });
    const bridgeRequest = {
      type: "native_tool_dispatch_execute_canary",
      runtime: "native-node-embedded",
      source,
      canaryMode,
      canaryOnly: true,
      readOnly: true,
      runId: queued.runId,
      requestId: queued.requestId,
      nativeSessionId: queued.nativeSessionId,
      callId: dispatch.callId,
      orderIndex,
      orderCount,
      method: dispatch.route.method,
      capability: dispatch.route.capability,
      dartCapability: dispatch.route.dartCapability,
      requiresUiThread: dispatch.route.requiresUiThread,
      input,
      toolUseFrame,
      dispatchHash: executeDispatchHash,
      requestHash: requestBuilder.requestHash,
      toolSelectionHash: requestBuilder.toolSelectionHash,
      canaryAllowlist,
      cancellationToken,
      dryRun: false,
      providerCallsEnabled: false,
      executionEnabled: true,
      toolExecutionEnabled: true,
      bridgeExecutionEnabled: true
    };
    return {
      ...bridgeRequest,
      bridgeRequestHash: metadataHash({
        type: bridgeRequest.type,
        source: bridgeRequest.source,
        runId: bridgeRequest.runId,
        callId: bridgeRequest.callId,
        orderIndex: bridgeRequest.orderIndex,
        orderCount: bridgeRequest.orderCount,
        method: bridgeRequest.method,
        capability: bridgeRequest.capability,
        input: bridgeRequest.input,
        dispatchHash: bridgeRequest.dispatchHash,
        requestHash: bridgeRequest.requestHash,
        canaryAllowlist: bridgeRequest.canaryAllowlist,
        cancellationToken: bridgeRequest.cancellationToken,
        readOnly: bridgeRequest.readOnly,
        dryRun: bridgeRequest.dryRun,
        providerCallsEnabled: bridgeRequest.providerCallsEnabled,
        executionEnabled: bridgeRequest.executionEnabled,
        toolExecutionEnabled: bridgeRequest.toolExecutionEnabled,
        bridgeExecutionEnabled: bridgeRequest.bridgeExecutionEnabled
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

  async function handleChatProviderRequestBuilderStream(req, res) {
    const source = "provider-request-builder";
    const canaryMode = "provider-request-builder";
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
      const requestBuilder = providerRequestBuilderDryRun(envelope, shape, queued);
      const ack = {
        parsed,
        route: "disabled",
        routeStatus: "blocked_before_transport_invocation",
        source,
        canaryMode,
        directCanary,
        reason:
          "provider request builder normalized headers/body and stopped before fetch/http.request",
        provider: requestBuilder.provider,
        requestedModel: requestBuilder.requestedModel,
        providerModel: requestBuilder.providerModel,
        transport: requestBuilder.transport,
        envelopeHash: requestBuilder.envelopeHash,
        headersHash: requestBuilder.headersHash,
        bodyHash: requestBuilder.bodyHash,
        requestHash: requestBuilder.requestHash,
        validationOk: requestBuilder.validationOk,
        transportInvocationEnabled: false,
        providerConfigStatus: requestBuilder.providerConfigStatus.mode,
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
        "x-plawie-native-canary": "provider-request-builder"
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
        transportInvocationEnabled: false,
        productionGatewayPort,
        ack,
        requestShape: shape
      });

      const steps = [
        {
          event: "provider_request",
          delay: 100,
          payload: {
            ok: true,
            runtime: "native-node-embedded",
            source,
            canaryMode,
            runId: queued.runId,
            requestBuilder
          }
        },
        {
          event: "request_validation",
          delay: 110,
          payload: {
            ok: true,
            runtime: "native-node-embedded",
            source,
            canaryMode,
            runId: queued.runId,
            validationOk: requestBuilder.validationOk,
            headerValidation: requestBuilder.headerValidation,
            bodyValidation: requestBuilder.bodyValidation,
            providerConfigStatus: requestBuilder.providerConfigStatus
          }
        },
        {
          event: "transport_gate",
          delay: 110,
          payload: {
            ok: true,
            runtime: "native-node-embedded",
            source,
            canaryMode,
            runId: queued.runId,
            gate: requestBuilder.transportGate,
            transportInvocationEnabled: false,
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
            provider: requestBuilder.provider,
            errorContract: requestBuilder.errorContract
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
              "Native provider request builder normalized the redacted headers and body. "
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
              "It stopped before fetch/http.request, so no provider network or billing happened."
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
            finishReason: "provider_request_builder_complete",
            provider: requestBuilder.provider,
            requestedModel: requestBuilder.requestedModel,
            requestHash: requestBuilder.requestHash,
            validationOk: requestBuilder.validationOk,
            transportInvocationEnabled: false,
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
            code: error.code || "chat_provider_request_builder_parse_failed",
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
          transportInvocationEnabled: false,
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
          code: error.code || "chat_provider_request_builder_failed",
          message: error.message || String(error)
        }
      });
      res.end();
    }
  }

  async function handleChatProviderTransportShimStream(req, res) {
    const source = "provider-transport-shim";
    const canaryMode = "provider-transport-shim";
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
      const requestBuilder = providerRequestBuilderDryRun(envelope, shape, queued);
      const transportShim = providerTransportShimDryRun(requestBuilder, queued);
      const ack = {
        parsed,
        route: "disabled",
        routeStatus: "aborted_before_dns",
        source,
        canaryMode,
        directCanary,
        reason:
          "provider transport shim constructed locally and aborted before DNS/TLS/socket/network",
        provider: transportShim.provider,
        requestedModel: transportShim.requestedModel,
        providerModel: transportShim.providerModel,
        transport: transportShim.transport,
        envelopeHash: transportShim.envelopeHash,
        headersHash: transportShim.headersHash,
        bodyHash: transportShim.bodyHash,
        requestHash: transportShim.requestHash,
        transportHash: transportShim.transportHash,
        validationOk: transportShim.validationOk,
        abortStage: transportShim.transportObject.abortContract.abortStage,
        abortedLocally: transportShim.transportObject.abortContract.abortedLocally,
        dnsLookupStarted: transportShim.transportObject.networkProbe.dnsLookupStarted,
        tlsHandshakeStarted: transportShim.transportObject.networkProbe.tlsHandshakeStarted,
        socketOpened: transportShim.transportObject.networkProbe.socketOpened,
        requestBytesWritten: transportShim.transportObject.networkProbe.requestBytesWritten,
        providerBillingSurfaceReached:
          transportShim.transportObject.networkProbe.providerBillingSurfaceReached,
        transportInvocationEnabled: false,
        providerCallsEnabled: false,
        executionEnabled: false,
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
        "x-plawie-native-canary": "provider-transport-shim"
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
        transportInvocationEnabled: false,
        productionGatewayPort,
        ack,
        requestShape: shape
      });

      const steps = [
        {
          event: "transport_shim",
          delay: 100,
          payload: {
            ok: true,
            runtime: "native-node-embedded",
            source,
            canaryMode,
            runId: queued.runId,
            transportShim
          }
        },
        {
          event: "abort_contract",
          delay: 100,
          payload: {
            ok: true,
            runtime: "native-node-embedded",
            source,
            canaryMode,
            runId: queued.runId,
            abortContract: transportShim.transportObject.abortContract,
            networkProbe: transportShim.transportObject.networkProbe
          }
        },
        {
          event: "transport_gate",
          delay: 110,
          payload: {
            ok: true,
            runtime: "native-node-embedded",
            source,
            canaryMode,
            runId: queued.runId,
            gate: transportShim.transportGate,
            transportInvocationEnabled: false,
            providerCallsEnabled: false
          }
        },
        {
          event: "shim_validation",
          delay: 110,
          payload: {
            ok: true,
            runtime: "native-node-embedded",
            source,
            canaryMode,
            runId: queued.runId,
            validationOk: transportShim.validationOk,
            shimValidation: transportShim.shimValidation
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
              "Native transport shim constructed the provider transport object. "
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
              "It aborted locally before DNS, TLS, socket open, bytes written, or provider billing."
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
            finishReason: "provider_transport_shim_complete",
            provider: transportShim.provider,
            requestedModel: transportShim.requestedModel,
            transportHash: transportShim.transportHash,
            validationOk: transportShim.validationOk,
            transportInvocationEnabled: false,
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
            code: error.code || "chat_provider_transport_shim_parse_failed",
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
          transportInvocationEnabled: false,
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
          code: error.code || "chat_provider_transport_shim_failed",
          message: error.message || String(error)
        }
      });
      res.end();
    }
  }

  async function handleChatProviderLiveCanaryStream(req, res) {
    const source = "provider-live-canary";
    const canaryMode = "provider-live-canary";
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
          dryRun: false,
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
      const requestBuilder = providerRequestBuilderDryRun(envelope, shape, queued);
      const liveRequest = providerLiveCanaryRequest(requestBuilder, payload);
      const routeBlocked = liveRequest.canStart !== true;
      const ack = {
        parsed,
        route: routeBlocked ? "blocked" : "enabled_canary",
        routeStatus: routeBlocked
          ? "blocked_before_provider_call"
          : "provider_call_starting",
        source,
        canaryMode,
        directCanary,
        reason: routeBlocked
          ? liveRequest.blockReasons.join(",")
          : "explicit native live provider canary allowed one tiny OpenRouter call",
        provider: liveRequest.provider,
        requestedModel: liveRequest.requestedModel,
        providerModel: liveRequest.providerModel,
        transport: liveRequest.transport,
        headersHash: liveRequest.headersHash,
        bodyHash: liveRequest.bodyHash,
        requestHash: liveRequest.requestHash,
        validationOk: liveRequest.canStart === true,
        endpointHost: liveRequest.endpointShape.host,
        endpointPath: liveRequest.endpointShape.pathname,
        maxTokens: liveRequest.maxTokens,
        promptChars: liveRequest.promptChars,
        requestBodyBytes: liveRequest.requestBodyBytes,
        providerCallStarted: false,
        providerCallsEnabled: liveRequest.canStart === true,
        transportInvocationEnabled: liveRequest.canStart === true,
        executionEnabled: false,
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
        "x-plawie-native-canary": "provider-live-canary"
      });
      writeEvent("ack", {
        ok: true,
        type: "res",
        id: typeof payload?.id === "string" ? payload.id : null,
        method: "chat.send",
        runtime: "native-node-embedded",
        canaryOnly: true,
        dryRun: false,
        source,
        canaryMode,
        directCanary,
        parsed: true,
        route: ack.route,
        routeStatus: ack.routeStatus,
        acceptedForRouting: liveRequest.canStart === true,
        acceptedForQueue: true,
        queuedForDryRun: false,
        queueStatus: "provider_live_canary",
        chatRoutingEnabled: false,
        providerCallsEnabled: liveRequest.canStart === true,
        executionEnabled: false,
        transportInvocationEnabled: liveRequest.canStart === true,
        productionGatewayPort,
        ack,
        requestShape: shape
      });

      writeEvent("provider_request", {
        ok: liveRequest.canStart === true,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        runId: queued.runId,
        providerRequest: {
          provider: liveRequest.provider,
          requestedModel: liveRequest.requestedModel,
          providerModel: liveRequest.providerModel,
          transport: liveRequest.transport,
          endpointShape: liveRequest.endpointShape,
          headersHash: liveRequest.headersHash,
          bodyHash: liveRequest.bodyHash,
          requestHash: liveRequest.requestHash,
          maxTokens: liveRequest.maxTokens,
          promptChars: liveRequest.promptChars,
          requestBodyBytes: liveRequest.requestBodyBytes,
          redactedBodyShape: liveRequest.redactedBodyShape,
          transportInvocationEnabled: liveRequest.canStart === true,
          providerCallsEnabled: liveRequest.canStart === true
        }
      });

      if (routeBlocked) {
        writeEvent("provider_gate", {
          ok: false,
          runtime: "native-node-embedded",
          source,
          canaryMode,
          runId: queued.runId,
          gate: {
            enabled: false,
            status: "blocked",
            reason: liveRequest.blockReasons.join(","),
            blockedBefore: "fetch"
          },
          transportInvocationEnabled: false,
          providerCallsEnabled: false
        });
        writeEvent("provider_error", providerErrorPayload({
          source,
          canaryMode,
          runId: queued.runId,
          provider: liveRequest.provider,
          code: "native_live_canary_blocked",
          message: liveRequest.blockReasons.join(",") ||
            "native live canary blocked before provider call",
          rawError: JSON.stringify({
            reasons: liveRequest.blockReasons,
            provider: liveRequest.provider,
            endpointHost: liveRequest.endpointShape.host
          })
        }));
        writeEvent("end", {
          ok: false,
          runtime: "native-node-embedded",
          source,
          canaryMode,
          runId: queued.runId,
          routeStatus: ack.routeStatus,
          finishReason: "provider_live_canary_blocked",
          providerCallsEnabled: false,
          executionEnabled: false
        });
        res.end();
        return;
      }

      const startedAtMs = Date.now();
      const controller = new AbortController();
      const timeout = setTimeout(() => {
        try {
          controller.abort("native_provider_live_canary_timeout");
        } catch (_) {
          controller.abort();
        }
      }, liveRequest.timeoutMs);

      try {
        writeEvent("provider_call_started", {
          ok: true,
          runtime: "native-node-embedded",
          source,
          canaryMode,
          runId: queued.runId,
          provider: liveRequest.provider,
          requestHash: liveRequest.requestHash,
          requestBodyBytes: liveRequest.requestBodyBytes,
          providerCallStarted: true,
          providerBillingSurfaceReached: true
        });

        const response = await fetch(liveRequest.endpoint, {
          method: "POST",
          headers: {
            "accept": "text/event-stream",
            "content-type": "application/json",
            "authorization": `Bearer ${liveRequest.apiKey}`,
            "http-referer": liveRequest.referer,
            "x-title": liveRequest.title
          },
          body: liveRequest.requestBodyText,
          signal: controller.signal
        });

        const responseStatus = response.status;
        const contentType = response.headers.get("content-type") || "";
        writeEvent("provider_response", {
          ok: response.ok,
          runtime: "native-node-embedded",
          source,
          canaryMode,
          runId: queued.runId,
          provider: liveRequest.provider,
          statusCode: responseStatus,
          contentType,
          firstByteMs: Date.now() - startedAtMs
        });

        if (!response.ok) {
          const rawError = await readProviderText(response);
          clearTimeout(timeout);
          writeEvent("provider_error", providerErrorPayload({
            source,
            canaryMode,
            runId: queued.runId,
            provider: liveRequest.provider,
            statusCode: responseStatus,
            code: `provider_http_${responseStatus}`,
            message: `provider returned HTTP ${responseStatus}`,
            rawError
          }));
          writeEvent("end", {
            ok: false,
            runtime: "native-node-embedded",
            source,
            canaryMode,
            runId: queued.runId,
            routeStatus: "provider_error",
            finishReason: "provider_http_error",
            provider: liveRequest.provider,
            statusCode: responseStatus,
            requestHash: liveRequest.requestHash,
            providerCallsEnabled: true,
            executionEnabled: false
          });
          res.end();
          return;
        }

        let sequence = 0;
        let textChars = 0;
        let firstTokenMs = null;
        let finishReason = null;
        let buffer = "";
        const decoder = new TextDecoder();
        const reader = response.body && typeof response.body.getReader === "function"
          ? response.body.getReader()
          : null;

        if (!reader) {
          const raw = await readProviderText(response);
          try {
            const decoded = JSON.parse(raw);
            const content = contentFromOpenAiCompatibleChunk(decoded);
            if (content.length > 0) {
              sequence += 1;
              textChars += content.length;
              firstTokenMs = Date.now() - startedAtMs;
              writeEvent("delta", {
                ok: true,
                runtime: "native-node-embedded",
                source,
                canaryMode,
                runId: queued.runId,
                sequence,
                text: content
              });
            }
          } catch (_) {
            writeEvent("delta", {
              ok: true,
              runtime: "native-node-embedded",
              source,
              canaryMode,
              runId: queued.runId,
              sequence: 1,
              text: raw.slice(0, 120)
            });
            textChars += Math.min(raw.length, 120);
          }
        } else {
          while (true) {
            const { done, value } = await reader.read();
            if (done) break;
            buffer += decoder.decode(value, { stream: true });
            const lines = buffer.split(/\r?\n/);
            buffer = lines.pop() || "";
            for (const line of lines) {
              const trimmed = line.trim();
              if (!trimmed.startsWith("data:")) continue;
              const data = trimmed.slice(5).trim();
              if (data.length === 0) continue;
              if (data === "[DONE]") {
                finishReason = finishReason || "done";
                continue;
              }
              try {
                const decoded = JSON.parse(data);
                const choices = Array.isArray(decoded.choices)
                  ? decoded.choices
                  : [];
                const choice = choices[0] && typeof choices[0] === "object"
                  ? choices[0]
                  : null;
                const content = contentFromOpenAiCompatibleChunk(decoded);
                if (choice?.finish_reason) {
                  finishReason = choice.finish_reason;
                }
                if (content.length === 0) continue;
                sequence += 1;
                textChars += content.length;
                if (firstTokenMs == null) {
                  firstTokenMs = Date.now() - startedAtMs;
                }
                writeEvent("delta", {
                  ok: true,
                  runtime: "native-node-embedded",
                  source,
                  canaryMode,
                  runId: queued.runId,
                  sequence,
                  text: content
                });
              } catch (error) {
                writeEvent("provider_parse_warning", {
                  ok: false,
                  runtime: "native-node-embedded",
                  source,
                  canaryMode,
                  runId: queued.runId,
                  warning: {
                    code: "provider_chunk_parse_failed",
                    message: error.message || String(error),
                    rawChunk: data.slice(0, 500)
                  }
                });
              }
            }
          }
        }

        clearTimeout(timeout);
        writeEvent("end", {
          ok: true,
          runtime: "native-node-embedded",
          source,
          canaryMode,
          runId: queued.runId,
          routeStatus: "provider_live_canary_complete",
          finishReason: finishReason || "stream_complete",
          provider: liveRequest.provider,
          requestedModel: liveRequest.requestedModel,
          providerModel: liveRequest.providerModel,
          statusCode: responseStatus,
          requestHash: liveRequest.requestHash,
          firstTokenMs,
          durationMs: Date.now() - startedAtMs,
          textChars,
          providerCallsEnabled: true,
          executionEnabled: false
        });
        res.end();
      } catch (error) {
        clearTimeout(timeout);
        const aborted = error?.name === "AbortError";
        writeEvent("provider_error", providerErrorPayload({
          source,
          canaryMode,
          runId: queued.runId,
          provider: liveRequest.provider,
          code: aborted ? "provider_timeout" : "provider_fetch_failed",
          message: error.message || String(error),
          rawError: error.stack || error.message || String(error)
        }));
        writeEvent("end", {
          ok: false,
          runtime: "native-node-embedded",
          source,
          canaryMode,
          runId: queued.runId,
          routeStatus: aborted ? "provider_timeout" : "provider_fetch_failed",
          finishReason: aborted ? "provider_timeout" : "provider_fetch_failed",
          provider: liveRequest.provider,
          requestHash: liveRequest.requestHash,
          durationMs: Date.now() - startedAtMs,
          providerCallsEnabled: true,
          executionEnabled: false
        });
        res.end();
      }
    } catch (error) {
      if (!res.headersSent) {
        sendJson(res, error.statusCode || 400, {
          ok: false,
          error: {
            type: "invalid_request",
            code: error.code || "chat_provider_live_canary_parse_failed",
            message: error.message || String(error)
          },
          runtime: "native-node-embedded",
          canaryOnly: true,
          dryRun: false,
          source,
          canaryMode,
          directCanary,
          openclawStarted: false,
          acceptedForRouting: false,
          chatRoutingEnabled: false,
          providerCallsEnabled: false,
          executionEnabled: false,
          transportInvocationEnabled: false,
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
          code: error.code || "chat_provider_live_canary_failed",
          message: error.message || String(error),
          raw: error.stack || error.message || String(error)
        }
      });
      res.end();
    }
  }

  async function handleChatProviderStreamParserParityStream(req, res) {
    const source = "provider-stream-parser-parity";
    const canaryMode = "provider-stream-parser-parity";
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
          dryRun: false,
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
      const requestBuilder = providerRequestBuilderDryRun(envelope, shape, queued);
      const liveRequest = providerLiveCanaryRequest(requestBuilder, payload);
      const fixtures = providerStreamParserParityFixtures();
      const routeBlocked = liveRequest.canStart !== true;
      const ack = {
        parsed,
        route: routeBlocked ? "blocked" : "enabled_canary",
        routeStatus: routeBlocked
          ? "blocked_before_provider_call"
          : "provider_stream_parser_parity_starting",
        source,
        canaryMode,
        directCanary,
        reason: routeBlocked
          ? liveRequest.blockReasons.join(",")
          : "explicit native stream parser parity canary allowed one tiny OpenRouter stream",
        provider: liveRequest.provider,
        requestedModel: liveRequest.requestedModel,
        providerModel: liveRequest.providerModel,
        transport: liveRequest.transport,
        headersHash: liveRequest.headersHash,
        bodyHash: liveRequest.bodyHash,
        requestHash: liveRequest.requestHash,
        fixtureHash: fixtures.fixtureHash,
        fixtureParityOk: fixtures.parityOk,
        validationOk: liveRequest.canStart === true && fixtures.parityOk,
        endpointHost: liveRequest.endpointShape.host,
        endpointPath: liveRequest.endpointShape.pathname,
        maxTokens: liveRequest.maxTokens,
        promptChars: liveRequest.promptChars,
        requestBodyBytes: liveRequest.requestBodyBytes,
        providerCallStarted: false,
        providerCallsEnabled: liveRequest.canStart === true,
        transportInvocationEnabled: liveRequest.canStart === true,
        executionEnabled: false,
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
        "x-plawie-native-canary": "provider-stream-parser-parity"
      });
      writeEvent("ack", {
        ok: true,
        type: "res",
        id: typeof payload?.id === "string" ? payload.id : null,
        method: "chat.send",
        runtime: "native-node-embedded",
        canaryOnly: true,
        dryRun: false,
        source,
        canaryMode,
        directCanary,
        parsed: true,
        route: ack.route,
        routeStatus: ack.routeStatus,
        acceptedForRouting: liveRequest.canStart === true,
        acceptedForQueue: true,
        queuedForDryRun: false,
        queueStatus: "provider_stream_parser_parity",
        chatRoutingEnabled: false,
        providerCallsEnabled: liveRequest.canStart === true,
        executionEnabled: false,
        transportInvocationEnabled: liveRequest.canStart === true,
        productionGatewayPort,
        ack,
        requestShape: shape
      });

      writeEvent("parser_fixture", {
        ok: fixtures.chunkFixture.parityOk,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        runId: queued.runId,
        fixture: fixtures.chunkFixture
      });
      writeEvent("error_fixture", {
        ok: fixtures.errorFixture.parityOk,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        runId: queued.runId,
        fixture: fixtures.errorFixture
      });
      writeEvent("timeout_fixture", {
        ok: fixtures.timeoutFixture.parityOk,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        runId: queued.runId,
        fixture: fixtures.timeoutFixture
      });
      writeEvent("cancellation_fixture", {
        ok: fixtures.cancellationFixture.parityOk,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        runId: queued.runId,
        fixture: fixtures.cancellationFixture
      });

      writeEvent("provider_request", {
        ok: liveRequest.canStart === true,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        runId: queued.runId,
        providerRequest: {
          provider: liveRequest.provider,
          requestedModel: liveRequest.requestedModel,
          providerModel: liveRequest.providerModel,
          transport: liveRequest.transport,
          endpointShape: liveRequest.endpointShape,
          headersHash: liveRequest.headersHash,
          bodyHash: liveRequest.bodyHash,
          requestHash: liveRequest.requestHash,
          maxTokens: liveRequest.maxTokens,
          promptChars: liveRequest.promptChars,
          requestBodyBytes: liveRequest.requestBodyBytes,
          redactedBodyShape: liveRequest.redactedBodyShape,
          transportInvocationEnabled: liveRequest.canStart === true,
          providerCallsEnabled: liveRequest.canStart === true
        }
      });

      if (routeBlocked) {
        writeEvent("provider_gate", {
          ok: false,
          runtime: "native-node-embedded",
          source,
          canaryMode,
          runId: queued.runId,
          gate: {
            enabled: false,
            status: "blocked",
            reason: liveRequest.blockReasons.join(","),
            blockedBefore: "fetch"
          },
          transportInvocationEnabled: false,
          providerCallsEnabled: false
        });
        writeEvent("provider_error", providerErrorPayload({
          source,
          canaryMode,
          runId: queued.runId,
          provider: liveRequest.provider,
          code: "native_stream_parser_parity_blocked",
          message: liveRequest.blockReasons.join(",") ||
            "native stream parser parity blocked before provider call",
          rawError: JSON.stringify({
            reasons: liveRequest.blockReasons,
            provider: liveRequest.provider,
            endpointHost: liveRequest.endpointShape.host
          })
        }));
        writeEvent("end", {
          ok: false,
          runtime: "native-node-embedded",
          source,
          canaryMode,
          runId: queued.runId,
          routeStatus: ack.routeStatus,
          finishReason: "provider_stream_parser_parity_blocked",
          fixtureParityOk: fixtures.parityOk,
          providerCallsEnabled: false,
          executionEnabled: false
        });
        res.end();
        return;
      }

      const startedAtMs = Date.now();
      const controller = new AbortController();
      const timeout = setTimeout(() => {
        try {
          controller.abort("native_provider_stream_parser_parity_timeout");
        } catch (_) {
          controller.abort();
        }
      }, liveRequest.timeoutMs);

      try {
        writeEvent("provider_call_started", {
          ok: true,
          runtime: "native-node-embedded",
          source,
          canaryMode,
          runId: queued.runId,
          provider: liveRequest.provider,
          requestHash: liveRequest.requestHash,
          requestBodyBytes: liveRequest.requestBodyBytes,
          providerCallStarted: true,
          providerBillingSurfaceReached: true
        });

        const response = await fetch(liveRequest.endpoint, {
          method: "POST",
          headers: {
            "accept": "text/event-stream",
            "content-type": "application/json",
            "authorization": `Bearer ${liveRequest.apiKey}`,
            "http-referer": liveRequest.referer,
            "x-title": liveRequest.title
          },
          body: liveRequest.requestBodyText,
          signal: controller.signal
        });

        const responseStatus = response.status;
        const contentType = response.headers.get("content-type") || "";
        writeEvent("provider_response", {
          ok: response.ok,
          runtime: "native-node-embedded",
          source,
          canaryMode,
          runId: queued.runId,
          provider: liveRequest.provider,
          statusCode: responseStatus,
          contentType,
          firstByteMs: Date.now() - startedAtMs
        });

        if (!response.ok) {
          const rawError = await readProviderText(response);
          clearTimeout(timeout);
          writeEvent("provider_error", providerErrorPayload({
            source,
            canaryMode,
            runId: queued.runId,
            provider: liveRequest.provider,
            statusCode: responseStatus,
            code: `provider_http_${responseStatus}`,
            message: `provider returned HTTP ${responseStatus}`,
            rawError
          }));
          writeEvent("end", {
            ok: false,
            runtime: "native-node-embedded",
            source,
            canaryMode,
            runId: queued.runId,
            routeStatus: "provider_error",
            finishReason: "provider_http_error",
            fixtureParityOk: fixtures.parityOk,
            provider: liveRequest.provider,
            statusCode: responseStatus,
            requestHash: liveRequest.requestHash,
            providerCallsEnabled: true,
            executionEnabled: false
          });
          res.end();
          return;
        }

        const parser = createProviderStreamParser({
          source,
          canaryMode,
          runId: queued.runId,
          startedAtMs,
          writeEvent
        });
        let buffer = "";
        const decoder = new TextDecoder();
        const reader = response.body && typeof response.body.getReader === "function"
          ? response.body.getReader()
          : null;

        if (!reader) {
          const raw = await readProviderText(response);
          try {
            const decoded = JSON.parse(raw);
            const content = contentFromOpenAiCompatibleChunk(decoded);
            if (content.length > 0) {
              parser.acceptData(JSON.stringify({
                choices: [
                  {
                    delta: { content },
                    finish_reason: decoded?.choices?.[0]?.finish_reason || "stop"
                  }
                ]
              }));
            }
          } catch (error) {
            parser.acceptData(JSON.stringify({
              choices: [
                {
                  delta: { content: raw.slice(0, 120) },
                  finish_reason: "raw_text"
                }
              ]
            }));
          }
        } else {
          while (true) {
            const { done, value } = await reader.read();
            if (done) break;
            buffer += decoder.decode(value, { stream: true });
            const lines = buffer.split(/\r?\n/);
            buffer = lines.pop() || "";
            for (const line of lines) {
              parser.acceptLine(line);
            }
          }
          if (buffer.trim().length > 0) {
            parser.acceptLine(buffer);
          }
        }

        clearTimeout(timeout);
        const liveSummary = parser.summary();
        const liveParityOk =
          responseStatus === 200 &&
          liveSummary.textChars > 0 &&
          liveSummary.warningCount === 0;
        writeEvent("live_parser_summary", {
          ok: liveParityOk,
          runtime: "native-node-embedded",
          source,
          canaryMode,
          runId: queued.runId,
          provider: liveRequest.provider,
          statusCode: responseStatus,
          parserSummary: liveSummary,
          fixtureParityOk: fixtures.parityOk,
          liveParityOk,
          parityOk: fixtures.parityOk && liveParityOk
        });
        writeEvent("end", {
          ok: fixtures.parityOk && liveParityOk,
          runtime: "native-node-embedded",
          source,
          canaryMode,
          runId: queued.runId,
          routeStatus: "provider_stream_parser_parity_complete",
          finishReason: liveSummary.finishReason || "stream_complete",
          provider: liveRequest.provider,
          requestedModel: liveRequest.requestedModel,
          providerModel: liveRequest.providerModel,
          statusCode: responseStatus,
          requestHash: liveRequest.requestHash,
          fixtureHash: fixtures.fixtureHash,
          fixtureParityOk: fixtures.parityOk,
          liveParityOk,
          firstTokenMs: liveSummary.firstTokenMs,
          durationMs: Date.now() - startedAtMs,
          textChars: liveSummary.textChars,
          warningCount: liveSummary.warningCount,
          providerCallsEnabled: true,
          executionEnabled: false
        });
        res.end();
      } catch (error) {
        clearTimeout(timeout);
        const aborted = error?.name === "AbortError";
        writeEvent("provider_error", providerErrorPayload({
          source,
          canaryMode,
          runId: queued.runId,
          provider: liveRequest.provider,
          code: aborted ? "provider_timeout" : "provider_fetch_failed",
          message: error.message || String(error),
          rawError: error.stack || error.message || String(error)
        }));
        writeEvent("end", {
          ok: false,
          runtime: "native-node-embedded",
          source,
          canaryMode,
          runId: queued.runId,
          routeStatus: aborted ? "provider_timeout" : "provider_fetch_failed",
          finishReason: aborted ? "provider_timeout" : "provider_fetch_failed",
          provider: liveRequest.provider,
          requestHash: liveRequest.requestHash,
          fixtureHash: fixtures.fixtureHash,
          fixtureParityOk: fixtures.parityOk,
          durationMs: Date.now() - startedAtMs,
          providerCallsEnabled: true,
          executionEnabled: false
        });
        res.end();
      }
    } catch (error) {
      if (!res.headersSent) {
        sendJson(res, error.statusCode || 400, {
          ok: false,
          error: {
            type: "invalid_request",
            code: error.code || "chat_provider_stream_parser_parity_parse_failed",
            message: error.message || String(error)
          },
          runtime: "native-node-embedded",
          canaryOnly: true,
          dryRun: false,
          source,
          canaryMode,
          directCanary,
          openclawStarted: false,
          acceptedForRouting: false,
          chatRoutingEnabled: false,
          providerCallsEnabled: false,
          executionEnabled: false,
          transportInvocationEnabled: false,
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
          code: error.code || "chat_provider_stream_parser_parity_failed",
          message: error.message || String(error),
          raw: error.stack || error.message || String(error)
        }
      });
      res.end();
    }
  }

  async function handleChatProviderToolPlanCanaryStream(req, res) {
    const source = "provider-tool-plan-canary";
    const canaryMode = "provider-tool-plan-canary";
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
          dryRun: false,
          source,
          canaryMode,
          directCanary,
          acceptedForRouting: false,
          acceptedForQueue: false,
          chatRoutingEnabled: false,
          providerCallsEnabled: false,
          executionEnabled: false,
          toolExecutionEnabled: false,
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
      const requestBuilder =
        providerToolPlanRequestBuilder(envelope, shape, queued, payload);
      const fixtureTools = nativeMobileToolCatalog().filter((entry) =>
        requestBuilder.toolFunctionNames.includes(entry.functionName)
      );
      const toolSelection = {
        tools: fixtureTools,
        toolFunctionNames: requestBuilder.toolFunctionNames,
        gatewayToolNames: requestBuilder.gatewayToolNames,
        toolAliasMap: requestBuilder.toolAliasMap,
        selectionHash: requestBuilder.toolSelectionHash
      };
      const fixtures = providerToolPlanFixtures(toolSelection);
      const validationOk = requestBuilder.validationOk === true && fixtures.parityOk;
      const ack = {
        parsed,
        route: "tool_plan_capture",
        routeStatus: "provider_tool_plan_capture_complete",
        source,
        canaryMode,
        directCanary,
        reason:
          "native captured provider tool-call plans from fixtures with dispatch disabled",
        provider: requestBuilder.provider,
        requestedModel: requestBuilder.requestedModel,
        providerModel: requestBuilder.providerModel,
        transport: requestBuilder.transport,
        headersHash: requestBuilder.headersHash,
        bodyHash: requestBuilder.bodyHash,
        requestHash: requestBuilder.requestHash,
        toolSelectionHash: requestBuilder.toolSelectionHash,
        fixtureHash: fixtures.fixtureHash,
        fixtureParityOk: fixtures.parityOk,
        validationOk,
        selectedToolCount: requestBuilder.selectedToolCount,
        toolPlanCount: fixtures.streamingFixture.parsed.toolPlanCount,
        allowedPlanCount: fixtures.streamingFixture.parsed.allowedPlanCount,
        blockedPlanCount: fixtures.streamingFixture.parsed.blockedPlanCount,
        providerCallStarted: false,
        providerCallsEnabled: false,
        transportInvocationEnabled: false,
        executionEnabled: false,
        toolExecutionEnabled: false,
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
        "x-plawie-native-canary": "provider-tool-plan-canary"
      });
      writeEvent("ack", {
        ok: true,
        type: "res",
        id: typeof payload?.id === "string" ? payload.id : null,
        method: "chat.send",
        runtime: "native-node-embedded",
        canaryOnly: true,
        dryRun: false,
        source,
        canaryMode,
        directCanary,
        parsed: true,
        route: ack.route,
        routeStatus: ack.routeStatus,
        acceptedForRouting: true,
        acceptedForQueue: true,
        queuedForDryRun: false,
        queueStatus: "provider_tool_plan_capture",
        chatRoutingEnabled: false,
        providerCallsEnabled: false,
        executionEnabled: false,
        toolExecutionEnabled: false,
        transportInvocationEnabled: false,
        productionGatewayPort,
        ack,
        requestShape: shape
      });

      writeEvent("tool_catalog", {
        ok: true,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        runId: queued.runId,
        selectedToolCount: requestBuilder.selectedToolCount,
        toolFunctionNames: requestBuilder.toolFunctionNames,
        gatewayToolNames: requestBuilder.gatewayToolNames,
        toolSelectionHash: requestBuilder.toolSelectionHash,
        schemaChars: JSON.stringify(requestBuilder.normalizedBody.tools).length,
        executionEnabled: false,
        toolExecutionEnabled: false
      });

      writeEvent("provider_request", {
        ok: requestBuilder.validationOk,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        runId: queued.runId,
        providerRequest: {
          provider: requestBuilder.provider,
          requestedModel: requestBuilder.requestedModel,
          providerModel: requestBuilder.providerModel,
          transport: requestBuilder.transport,
          endpointRedacted: requestBuilder.endpointRedacted,
          headersHash: requestBuilder.headersHash,
          bodyHash: requestBuilder.bodyHash,
          requestHash: requestBuilder.requestHash,
          selectedToolCount: requestBuilder.selectedToolCount,
          toolFunctionNames: requestBuilder.toolFunctionNames,
          gatewayToolNames: requestBuilder.gatewayToolNames,
          bodyValidation: requestBuilder.bodyValidation,
          transportInvocationEnabled: false,
          providerCallsEnabled: false,
          executionEnabled: false,
          toolExecutionEnabled: false,
          stopBefore: requestBuilder.stopBefore
        }
      });

      writeEvent("streaming_tool_fixture", {
        ok: fixtures.streamingFixture.parityOk,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        runId: queued.runId,
        fixture: fixtures.streamingFixture
      });
      writeEvent("message_tool_fixture", {
        ok: fixtures.messageFixture.parityOk,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        runId: queued.runId,
        fixture: fixtures.messageFixture
      });
      writeEvent("unknown_tool_fixture", {
        ok: fixtures.unknownFixture.parityOk,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        runId: queued.runId,
        fixture: fixtures.unknownFixture
      });
      writeEvent("malformed_arguments_fixture", {
        ok: fixtures.malformedFixture.parityOk,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        runId: queued.runId,
        fixture: fixtures.malformedFixture
      });

      writeEvent("tool_plan_summary", {
        ok: validationOk,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        runId: queued.runId,
        toolPlanSummary: fixtures.streamingFixture.parsed,
        fixtureHash: fixtures.fixtureHash,
        fixtureParityOk: fixtures.parityOk,
        validationOk,
        providerCallsEnabled: false,
        executionEnabled: false,
        toolExecutionEnabled: false
      });

      writeEvent("end", {
        ok: validationOk,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        runId: queued.runId,
        routeStatus: validationOk
          ? "provider_tool_plan_capture_complete"
          : "provider_tool_plan_capture_failed",
        finishReason: validationOk ? "tool_plan_capture_complete" : "tool_plan_capture_failed",
        requestHash: requestBuilder.requestHash,
        toolSelectionHash: requestBuilder.toolSelectionHash,
        fixtureHash: fixtures.fixtureHash,
        fixtureParityOk: fixtures.parityOk,
        validationOk,
        selectedToolCount: requestBuilder.selectedToolCount,
        toolPlanCount: fixtures.streamingFixture.parsed.toolPlanCount,
        allowedPlanCount: fixtures.streamingFixture.parsed.allowedPlanCount,
        blockedPlanCount: fixtures.streamingFixture.parsed.blockedPlanCount,
        invalidArgumentCount: fixtures.streamingFixture.parsed.invalidArgumentCount,
        providerCallsEnabled: false,
        executionEnabled: false,
        toolExecutionEnabled: false
      });
      res.end();
    } catch (error) {
      if (!res.headersSent) {
        sendJson(res, error.statusCode || 400, {
          ok: false,
          error: {
            type: "invalid_request",
            code: error.code || "chat_provider_tool_plan_canary_parse_failed",
            message: error.message || String(error)
          },
          runtime: "native-node-embedded",
          canaryOnly: true,
          dryRun: false,
          source,
          canaryMode,
          directCanary,
          openclawStarted: false,
          acceptedForRouting: false,
          chatRoutingEnabled: false,
          providerCallsEnabled: false,
          executionEnabled: false,
          toolExecutionEnabled: false,
          transportInvocationEnabled: false,
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
          code: error.code || "chat_provider_tool_plan_canary_failed",
          message: error.message || String(error),
          raw: error.stack || error.message || String(error)
        }
      });
      res.end();
    }
  }

  async function handleChatToolDispatchDryRunStream(req, res) {
    const source = "tool-dispatch-dry-run";
    const canaryMode = "tool-dispatch-dry-run";
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
          source,
          canaryMode,
          directCanary,
          acceptedForRouting: false,
          acceptedForQueue: false,
          providerCallsEnabled: false,
          executionEnabled: false,
          toolExecutionEnabled: false,
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
      const requestBuilder =
        providerToolPlanRequestBuilder(envelope, shape, queued, payload);
      const fixtureTools = nativeMobileToolCatalog().filter((entry) =>
        requestBuilder.toolFunctionNames.includes(entry.functionName)
      );
      const toolSelection = {
        tools: fixtureTools,
        toolFunctionNames: requestBuilder.toolFunctionNames,
        gatewayToolNames: requestBuilder.gatewayToolNames,
        toolAliasMap: requestBuilder.toolAliasMap,
        selectionHash: requestBuilder.toolSelectionHash
      };
      const dispatch = syntheticToolDispatchDryRun(toolSelection, queued);
      const validationOk =
        requestBuilder.validationOk === true && dispatch.parityOk === true;
      const ack = {
        parsed,
        route: "tool_dispatch_dry_run",
        routeStatus: "native_tool_dispatch_dry_run_complete",
        source,
        canaryMode,
        directCanary,
        reason:
          "native mapped a captured tool plan to synthetic tool_use/tool_result frames",
        provider: requestBuilder.provider,
        requestedModel: requestBuilder.requestedModel,
        providerModel: requestBuilder.providerModel,
        transport: requestBuilder.transport,
        requestHash: requestBuilder.requestHash,
        toolSelectionHash: requestBuilder.toolSelectionHash,
        dispatchHash: dispatch.dispatchHash,
        fixtureHash: dispatch.fixture.parsed.toolPlanHash,
        fixtureParityOk: dispatch.fixture.parityOk,
        dispatchParityOk: dispatch.parityOk,
        validationOk,
        selectedToolCount: requestBuilder.selectedToolCount,
        toolPlanCount: dispatch.fixture.parsed.toolPlanCount,
        allowedPlanCount: dispatch.fixture.parsed.allowedPlanCount,
        blockedPlanCount: dispatch.fixture.parsed.blockedPlanCount,
        providerCallStarted: false,
        providerCallsEnabled: false,
        transportInvocationEnabled: false,
        executionEnabled: false,
        toolExecutionEnabled: false,
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
        "x-plawie-native-canary": "tool-dispatch-dry-run"
      });
      writeEvent("ack", {
        ok: true,
        type: "res",
        id: typeof payload?.id === "string" ? payload.id : null,
        method: "chat.send",
        runtime: "native-node-embedded",
        canaryOnly: true,
        dryRun: false,
        source,
        canaryMode,
        directCanary,
        parsed: true,
        route: ack.route,
        routeStatus: ack.routeStatus,
        acceptedForRouting: true,
        acceptedForQueue: true,
        queuedForDryRun: false,
        queueStatus: "native_tool_dispatch_dry_run",
        chatRoutingEnabled: false,
        providerCallsEnabled: false,
        executionEnabled: false,
        toolExecutionEnabled: false,
        transportInvocationEnabled: false,
        productionGatewayPort,
        ack,
        requestShape: shape
      });

      writeEvent("tool_plan_summary", {
        ok: dispatch.fixture.parityOk,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        runId: queued.runId,
        toolPlanSummary: dispatch.fixture.parsed,
        plan: dispatch.plan,
        fixtureParityOk: dispatch.fixture.parityOk,
        toolExecutionEnabled: false
      });

      writeEvent("tool_dispatch_plan", {
        ok: dispatch.canDispatch,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        runId: queued.runId,
        dispatchPlan: {
          callId: dispatch.callId,
          route: dispatch.route,
          planHash: dispatch.plan?.planHash || null,
          dispatchHash: dispatch.dispatchHash,
          wouldExecute: dispatch.canDispatch,
          executionEnabled: false,
          toolExecutionEnabled: false
        }
      });

      writeEvent("tool_use_frame", {
        ok: dispatch.parityOk,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        runId: queued.runId,
        frame: dispatch.toolUseFrame
      });
      writeEvent("tool_result_frame", {
        ok: dispatch.parityOk,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        runId: queued.runId,
        frame: dispatch.toolResultFrame
      });

      writeEvent("dispatch_summary", {
        ok: validationOk,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        runId: queued.runId,
        dispatchHash: dispatch.dispatchHash,
        dispatchParityOk: dispatch.parityOk,
        validationOk,
        toolName: dispatch.route.method,
        capability: dispatch.route.capability,
        dartCapability: dispatch.route.dartCapability,
        skippedReason: dispatch.toolResultFrame.result.skippedReason,
        providerCallsEnabled: false,
        executionEnabled: false,
        toolExecutionEnabled: false
      });

      writeEvent("end", {
        ok: validationOk,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        runId: queued.runId,
        routeStatus: validationOk
          ? "native_tool_dispatch_dry_run_complete"
          : "native_tool_dispatch_dry_run_failed",
        finishReason: validationOk ? "tool_dispatch_dry_run_complete" : "tool_dispatch_dry_run_failed",
        requestHash: requestBuilder.requestHash,
        toolSelectionHash: requestBuilder.toolSelectionHash,
        dispatchHash: dispatch.dispatchHash,
        fixtureParityOk: dispatch.fixture.parityOk,
        dispatchParityOk: dispatch.parityOk,
        validationOk,
        toolName: dispatch.route.method,
        capability: dispatch.route.capability,
        providerCallsEnabled: false,
        executionEnabled: false,
        toolExecutionEnabled: false
      });
      res.end();
    } catch (error) {
      if (!res.headersSent) {
        sendJson(res, error.statusCode || 400, {
          ok: false,
          error: {
            type: "invalid_request",
            code: error.code || "chat_tool_dispatch_dry_run_parse_failed",
            message: error.message || String(error)
          },
          runtime: "native-node-embedded",
          canaryOnly: true,
          dryRun: false,
          source,
          canaryMode,
          directCanary,
          openclawStarted: false,
          acceptedForRouting: false,
          providerCallsEnabled: false,
          executionEnabled: false,
          toolExecutionEnabled: false,
          transportInvocationEnabled: false,
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
          code: error.code || "chat_tool_dispatch_dry_run_failed",
          message: error.message || String(error),
          raw: error.stack || error.message || String(error)
        }
      });
      res.end();
    }
  }

  async function handleChatNativeDartBridgeDryRunStream(req, res) {
    const source = "native-dart-bridge-dry-run";
    const canaryMode = "native-dart-bridge-dry-run";
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
          source,
          canaryMode,
          directCanary,
          acceptedForRouting: false,
          acceptedForQueue: false,
          providerCallsEnabled: false,
          executionEnabled: false,
          toolExecutionEnabled: false,
          bridgeExecutionEnabled: false,
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
      const requestBuilder =
        providerToolPlanRequestBuilder(envelope, shape, queued, payload);
      const fixtureTools = nativeMobileToolCatalog().filter((entry) =>
        requestBuilder.toolFunctionNames.includes(entry.functionName)
      );
      const toolSelection = {
        tools: fixtureTools,
        toolFunctionNames: requestBuilder.toolFunctionNames,
        gatewayToolNames: requestBuilder.gatewayToolNames,
        toolAliasMap: requestBuilder.toolAliasMap,
        selectionHash: requestBuilder.toolSelectionHash
      };
      const dispatch = syntheticToolDispatchDryRun(toolSelection, queued);
      const bridgeRequest =
        nativeDartBridgeDryRunRequest(dispatch, queued, requestBuilder);

      const ack = {
        parsed,
        route: "native_dart_bridge_dry_run",
        routeStatus: "native_dart_bridge_dry_run_started",
        source,
        canaryMode,
        directCanary,
        reason:
          "native mapped a tool plan and sent a dry-run dispatch request to Dart",
        provider: requestBuilder.provider,
        requestedModel: requestBuilder.requestedModel,
        providerModel: requestBuilder.providerModel,
        transport: requestBuilder.transport,
        requestHash: requestBuilder.requestHash,
        toolSelectionHash: requestBuilder.toolSelectionHash,
        dispatchHash: dispatch.dispatchHash,
        bridgeRequestHash: bridgeRequest.bridgeRequestHash,
        fixtureHash: dispatch.fixture.parsed.toolPlanHash,
        fixtureParityOk: dispatch.fixture.parityOk,
        dispatchParityOk: dispatch.parityOk,
        bridgeParityOk: false,
        validationOk: false,
        selectedToolCount: requestBuilder.selectedToolCount,
        toolPlanCount: dispatch.fixture.parsed.toolPlanCount,
        allowedPlanCount: dispatch.fixture.parsed.allowedPlanCount,
        blockedPlanCount: dispatch.fixture.parsed.blockedPlanCount,
        providerCallStarted: false,
        providerCallsEnabled: false,
        transportInvocationEnabled: false,
        executionEnabled: false,
        toolExecutionEnabled: false,
        bridgeExecutionEnabled: false,
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
        "x-plawie-native-canary": "native-dart-bridge-dry-run"
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
        route: ack.route,
        routeStatus: ack.routeStatus,
        acceptedForRouting: true,
        acceptedForQueue: true,
        queuedForDryRun: false,
        queueStatus: "native_dart_bridge_dry_run",
        chatRoutingEnabled: false,
        providerCallsEnabled: false,
        executionEnabled: false,
        toolExecutionEnabled: false,
        bridgeExecutionEnabled: false,
        transportInvocationEnabled: false,
        productionGatewayPort,
        ack,
        requestShape: shape
      });

      writeEvent("tool_plan_summary", {
        ok: dispatch.fixture.parityOk,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        runId: queued.runId,
        toolPlanSummary: dispatch.fixture.parsed,
        plan: dispatch.plan,
        fixtureParityOk: dispatch.fixture.parityOk,
        toolExecutionEnabled: false
      });

      writeEvent("tool_dispatch_plan", {
        ok: dispatch.canDispatch,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        runId: queued.runId,
        dispatchPlan: {
          callId: dispatch.callId,
          route: dispatch.route,
          planHash: dispatch.plan?.planHash || null,
          dispatchHash: dispatch.dispatchHash,
          bridgeRequestHash: bridgeRequest.bridgeRequestHash,
          wouldExecute: false,
          executionEnabled: false,
          toolExecutionEnabled: false,
          bridgeExecutionEnabled: false
        }
      });

      writeEvent("bridge_request", {
        ok: dispatch.parityOk,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        runId: queued.runId,
        endpoint: "http://127.0.0.1:8765/api/native-gateway/dispatch-dry-run",
        bridgeRequest: {
          type: bridgeRequest.type,
          callId: bridgeRequest.callId,
          method: bridgeRequest.method,
          capability: bridgeRequest.capability,
          dartCapability: bridgeRequest.dartCapability,
          requiresUiThread: bridgeRequest.requiresUiThread,
          bridgeRequestHash: bridgeRequest.bridgeRequestHash,
          dispatchHash: bridgeRequest.dispatchHash,
          dryRun: bridgeRequest.dryRun,
          executionEnabled: bridgeRequest.executionEnabled,
          toolExecutionEnabled: bridgeRequest.toolExecutionEnabled,
          bridgeExecutionEnabled: bridgeRequest.bridgeExecutionEnabled
        }
      });

      const bridgeResponse = await postJsonToDartBridge(
        "/api/native-gateway/dispatch-dry-run",
        bridgeRequest,
        2500
      );
      const bridgeAck = bridgeResponse.body;
      const bridgeAckHash = metadataHash({
        bridgeRequestHash: bridgeRequest.bridgeRequestHash,
        ok: bridgeAck.ok === true,
        accepted: bridgeAck.accepted === true,
        commandKnown: bridgeAck.commandKnown === true,
        command: bridgeAck.command,
        capability: bridgeAck.capability,
        dryRun: bridgeAck.dryRun === true,
        skippedReason: bridgeAck.skippedReason,
        executionEnabled: bridgeAck.executionEnabled === true,
        toolExecutionEnabled: bridgeAck.toolExecutionEnabled === true,
        bridgeExecutionEnabled: bridgeAck.bridgeExecutionEnabled === true
      });
      const bridgeParityOk =
        dispatch.parityOk &&
        bridgeAck.ok === true &&
        bridgeAck.accepted === true &&
        bridgeAck.commandKnown === true &&
        bridgeAck.dryRun === true &&
        bridgeAck.executionEnabled === false &&
        bridgeAck.toolExecutionEnabled === false &&
        bridgeAck.bridgeExecutionEnabled === false &&
        bridgeAck.skippedReason === "native_dart_bridge_dry_run_only";
      const validationOk =
        requestBuilder.validationOk === true && bridgeParityOk === true;
      const bridgedToolResultFrame = {
        ...dispatch.toolResultFrame,
        result: {
          ...dispatch.toolResultFrame.result,
          ok: bridgeParityOk,
          bridgeAckReceived: true,
          bridgeAckHash,
          bridgeRequestHash: bridgeRequest.bridgeRequestHash,
          dartBridgeOk: bridgeAck.ok === true,
          dartAccepted: bridgeAck.accepted === true,
          commandKnown: bridgeAck.commandKnown === true,
          skippedReason: bridgeAck.skippedReason,
          bridgeExecutionEnabled: false,
          toolExecutionEnabled: false,
          executionEnabled: false
        }
      };

      writeEvent("bridge_ack", {
        ok: bridgeAck.ok === true,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        runId: queued.runId,
        statusCode: bridgeResponse.statusCode,
        responseBytesRead: bridgeResponse.responseBytesRead,
        bridgeAckHash,
        bridgeParityOk,
        validationOk,
        bridgeAck
      });
      writeEvent("tool_use_frame", {
        ok: dispatch.parityOk,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        runId: queued.runId,
        frame: dispatch.toolUseFrame
      });
      writeEvent("tool_result_frame", {
        ok: bridgeParityOk,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        runId: queued.runId,
        frame: bridgedToolResultFrame
      });

      writeEvent("bridge_summary", {
        ok: validationOk,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        runId: queued.runId,
        requestHash: requestBuilder.requestHash,
        dispatchHash: dispatch.dispatchHash,
        bridgeRequestHash: bridgeRequest.bridgeRequestHash,
        bridgeAckHash,
        fixtureParityOk: dispatch.fixture.parityOk,
        dispatchParityOk: dispatch.parityOk,
        bridgeParityOk,
        validationOk,
        toolName: dispatch.route.method,
        capability: dispatch.route.capability,
        dartCapability: dispatch.route.dartCapability,
        skippedReason: bridgeAck.skippedReason,
        providerCallsEnabled: false,
        executionEnabled: false,
        toolExecutionEnabled: false,
        bridgeExecutionEnabled: false
      });

      writeEvent("end", {
        ok: validationOk,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        runId: queued.runId,
        routeStatus: validationOk
          ? "native_dart_bridge_dry_run_complete"
          : "native_dart_bridge_dry_run_failed",
        finishReason: validationOk ? "native_dart_bridge_dry_run_complete" : "native_dart_bridge_dry_run_failed",
        requestHash: requestBuilder.requestHash,
        dispatchHash: dispatch.dispatchHash,
        bridgeRequestHash: bridgeRequest.bridgeRequestHash,
        bridgeAckHash,
        fixtureParityOk: dispatch.fixture.parityOk,
        dispatchParityOk: dispatch.parityOk,
        bridgeParityOk,
        validationOk,
        toolName: dispatch.route.method,
        capability: dispatch.route.capability,
        providerCallsEnabled: false,
        executionEnabled: false,
        toolExecutionEnabled: false,
        bridgeExecutionEnabled: false
      });
      res.end();
    } catch (error) {
      if (!res.headersSent) {
        sendJson(res, error.statusCode || 400, {
          ok: false,
          error: {
            type: "invalid_request",
            code: error.code || "chat_native_dart_bridge_dry_run_parse_failed",
            message: error.message || String(error),
            raw: error.raw || error.stack || error.message || String(error),
            statusCode: error.statusCode || null,
            body: error.body || null
          },
          runtime: "native-node-embedded",
          canaryOnly: true,
          dryRun: true,
          source,
          canaryMode,
          directCanary,
          openclawStarted: false,
          acceptedForRouting: false,
          providerCallsEnabled: false,
          executionEnabled: false,
          toolExecutionEnabled: false,
          bridgeExecutionEnabled: false,
          transportInvocationEnabled: false,
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
          code: error.code || "chat_native_dart_bridge_dry_run_failed",
          message: error.message || String(error),
          raw: error.raw || error.stack || error.message || String(error),
          statusCode: error.statusCode || null,
          body: error.body || null
        }
      });
      res.end();
    }
  }

  async function handleChatNativeDartBridgeOrderingCancelStream(req, res) {
    const source = "native-dart-bridge-ordering-cancel";
    const canaryMode = "native-dart-bridge-ordering-cancel";
    const directCanary = true;
    const orderCount = 3;
    const cancelOrderIndex = 1;

    function writeEvent(event, payload) {
      if (res.writableEnded) return;
      res.write(`${JSON.stringify({
        event,
        ...payload
      })}\n`);
    }

    function clonePayloadForOrder(payload, orderIndex) {
      const params = payload?.params && typeof payload.params === "object"
        ? { ...payload.params }
        : {};
      return {
        ...payload,
        id: stableId("native-order-request", {
          id: payload?.id,
          orderIndex,
          message: params.message
        }),
        params: {
          ...params,
          idempotencyKey: stableId("native-order-idempotency", {
            base: params.idempotencyKey,
            orderIndex
          })
        }
      };
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
          source,
          canaryMode,
          directCanary,
          acceptedForRouting: false,
          acceptedForQueue: false,
          providerCallsEnabled: false,
          executionEnabled: false,
          toolExecutionEnabled: false,
          bridgeExecutionEnabled: false,
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

      const entries = [];
      let requestBuilder = null;
      for (let orderIndex = 0; orderIndex < orderCount; orderIndex += 1) {
        const orderedPayload = clonePayloadForOrder(payload, orderIndex);
        const orderedShape = summarizeGatewayWsFrame(orderedPayload);
        const queued = dryRunQueue.acceptDryRun({
          payload: orderedPayload,
          shape: orderedShape,
          gatewayReady: readyState(),
          source,
          canaryMode,
          directCanary
        });
        const envelope = providerShellEnvelope(
          orderedPayload,
          orderedShape,
          queued
        );
        const builder =
          providerToolPlanRequestBuilder(envelope, orderedShape, queued, orderedPayload);
        requestBuilder ??= builder;
        const fixtureTools = nativeMobileToolCatalog().filter((entry) =>
          builder.toolFunctionNames.includes(entry.functionName)
        );
        const toolSelection = {
          tools: fixtureTools,
          toolFunctionNames: builder.toolFunctionNames,
          gatewayToolNames: builder.gatewayToolNames,
          toolAliasMap: builder.toolAliasMap,
          selectionHash: builder.toolSelectionHash
        };
        const dispatch = syntheticToolDispatchDryRun(toolSelection, queued);
        const bridgeRequest = nativeDartBridgeOrderedRequest(
          nativeDartBridgeDryRunRequest(dispatch, queued, builder),
          orderIndex,
          orderCount
        );
        entries.push({
          orderIndex,
          orderedPayload,
          orderedShape,
          queued,
          builder,
          dispatch,
          bridgeRequest,
          bridgeAck: null,
          bridgeAckHash: null,
          bridgeParityOk: false,
          resultFrame: null
        });
      }

      const orderingPlanHash = metadataHash({
        orderCount,
        cancelOrderIndex,
        runIds: entries.map((entry) => entry.queued.runId),
        bridgeRequestHashes: entries.map((entry) => entry.bridgeRequest.bridgeRequestHash)
      });
      const ack = {
        parsed,
        route: "native_dart_bridge_ordering_cancel",
        routeStatus: "native_dart_bridge_ordering_cancel_started",
        source,
        canaryMode,
        directCanary,
        reason:
          "native sends ordered dry-run dispatches to Dart and records a dry-run cancellation",
        provider: requestBuilder.provider,
        requestedModel: requestBuilder.requestedModel,
        providerModel: requestBuilder.providerModel,
        transport: requestBuilder.transport,
        requestHash: requestBuilder.requestHash,
        toolSelectionHash: requestBuilder.toolSelectionHash,
        dispatchHash: entries[0].dispatch.dispatchHash,
        orderingPlanHash,
        orderCount,
        cancelOrderIndex,
        fixtureHash: entries[0].dispatch.fixture.parsed.toolPlanHash,
        fixtureParityOk: entries.every((entry) => entry.dispatch.fixture.parityOk),
        dispatchParityOk: entries.every((entry) => entry.dispatch.parityOk),
        orderingParityOk: false,
        cancellationParityOk: false,
        validationOk: false,
        selectedToolCount: requestBuilder.selectedToolCount,
        toolPlanCount: entries[0].dispatch.fixture.parsed.toolPlanCount,
        allowedPlanCount: entries[0].dispatch.fixture.parsed.allowedPlanCount,
        blockedPlanCount: entries[0].dispatch.fixture.parsed.blockedPlanCount,
        providerCallStarted: false,
        providerCallsEnabled: false,
        transportInvocationEnabled: false,
        executionEnabled: false,
        toolExecutionEnabled: false,
        bridgeExecutionEnabled: false,
        sessionKey: shape.sessionKey,
        nativeSessionId: entries[0].queued.nativeSessionId,
        requestId: entries[0].queued.requestId,
        runId: entries[0].queued.runId,
        sequence: entries[0].queued.sequence,
        queueStatus: "native_dart_bridge_ordering_cancel",
        gatewayReady: entries[0].queued.gatewayReady,
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
        "x-plawie-native-canary": "native-dart-bridge-ordering-cancel"
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
        route: ack.route,
        routeStatus: ack.routeStatus,
        acceptedForRouting: true,
        acceptedForQueue: true,
        queuedForDryRun: false,
        queueStatus: "native_dart_bridge_ordering_cancel",
        chatRoutingEnabled: false,
        providerCallsEnabled: false,
        executionEnabled: false,
        toolExecutionEnabled: false,
        bridgeExecutionEnabled: false,
        transportInvocationEnabled: false,
        productionGatewayPort,
        ack,
        requestShape: shape
      });

      writeEvent("order_plan", {
        ok: true,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        orderCount,
        cancelOrderIndex,
        orderingPlanHash,
        plannedOrder: entries.map((entry) => ({
          orderIndex: entry.orderIndex,
          runId: entry.queued.runId,
          requestId: entry.queued.requestId,
          bridgeRequestHash: entry.bridgeRequest.bridgeRequestHash,
          cancellationToken: entry.bridgeRequest.cancellationToken,
          toolName: entry.dispatch.route.method
        })),
        providerCallsEnabled: false,
        executionEnabled: false,
        toolExecutionEnabled: false,
        bridgeExecutionEnabled: false
      });

      const observedBridgeOrder = [];
      const observedResultOrder = [];
      for (const entry of entries) {
        writeEvent("bridge_request", {
          ok: entry.dispatch.parityOk,
          runtime: "native-node-embedded",
          source,
          canaryMode,
          runId: entry.queued.runId,
          orderIndex: entry.orderIndex,
          endpoint: "http://127.0.0.1:8765/api/native-gateway/dispatch-dry-run",
          bridgeRequest: {
            type: entry.bridgeRequest.type,
            callId: entry.bridgeRequest.callId,
            method: entry.bridgeRequest.method,
            capability: entry.bridgeRequest.capability,
            dartCapability: entry.bridgeRequest.dartCapability,
            requiresUiThread: entry.bridgeRequest.requiresUiThread,
            orderIndex: entry.bridgeRequest.orderIndex,
            orderCount: entry.bridgeRequest.orderCount,
            orderingKey: entry.bridgeRequest.orderingKey,
            cancellationToken: entry.bridgeRequest.cancellationToken,
            bridgeRequestHash: entry.bridgeRequest.bridgeRequestHash,
            dispatchHash: entry.bridgeRequest.dispatchHash,
            dryRun: entry.bridgeRequest.dryRun,
            executionEnabled: entry.bridgeRequest.executionEnabled,
            toolExecutionEnabled: entry.bridgeRequest.toolExecutionEnabled,
            bridgeExecutionEnabled: entry.bridgeRequest.bridgeExecutionEnabled
          }
        });

        const bridgeResponse = await postJsonToDartBridge(
          "/api/native-gateway/dispatch-dry-run",
          entry.bridgeRequest,
          2500
        );
        const bridgeAck = bridgeResponse.body;
        const bridgeAckHash = metadataHash({
          bridgeRequestHash: entry.bridgeRequest.bridgeRequestHash,
          ok: bridgeAck.ok === true,
          accepted: bridgeAck.accepted === true,
          commandKnown: bridgeAck.commandKnown === true,
          command: bridgeAck.command,
          capability: bridgeAck.capability,
          orderIndex: bridgeAck.orderIndex,
          dryRun: bridgeAck.dryRun === true,
          skippedReason: bridgeAck.skippedReason,
          executionEnabled: bridgeAck.executionEnabled === true,
          toolExecutionEnabled: bridgeAck.toolExecutionEnabled === true,
          bridgeExecutionEnabled: bridgeAck.bridgeExecutionEnabled === true
        });
        entry.bridgeAck = bridgeAck;
        entry.bridgeAckHash = bridgeAckHash;
        entry.bridgeParityOk =
          entry.dispatch.parityOk &&
          bridgeAck.ok === true &&
          bridgeAck.accepted === true &&
          bridgeAck.commandKnown === true &&
          bridgeAck.orderIndex === entry.orderIndex &&
          bridgeAck.dryRun === true &&
          bridgeAck.executionEnabled === false &&
          bridgeAck.toolExecutionEnabled === false &&
          bridgeAck.bridgeExecutionEnabled === false &&
          bridgeAck.skippedReason === "native_dart_bridge_dry_run_only";
        observedBridgeOrder.push(entry.orderIndex);

        writeEvent("bridge_ack", {
          ok: bridgeAck.ok === true,
          runtime: "native-node-embedded",
          source,
          canaryMode,
          runId: entry.queued.runId,
          orderIndex: entry.orderIndex,
          statusCode: bridgeResponse.statusCode,
          responseBytesRead: bridgeResponse.responseBytesRead,
          bridgeAckHash,
          bridgeParityOk: entry.bridgeParityOk,
          bridgeAck
        });

        const resultFrame = {
          ...entry.dispatch.toolResultFrame,
          result: {
            ...entry.dispatch.toolResultFrame.result,
            ok: entry.bridgeParityOk,
            bridgeAckReceived: true,
            bridgeAckHash,
            bridgeRequestHash: entry.bridgeRequest.bridgeRequestHash,
            orderIndex: entry.orderIndex,
            orderingKey: entry.bridgeRequest.orderingKey,
            cancellationToken: entry.bridgeRequest.cancellationToken,
            dartBridgeOk: bridgeAck.ok === true,
            dartAccepted: bridgeAck.accepted === true,
            commandKnown: bridgeAck.commandKnown === true,
            skippedReason: bridgeAck.skippedReason,
            bridgeExecutionEnabled: false,
            toolExecutionEnabled: false,
            executionEnabled: false
          },
          orderIndex: entry.orderIndex
        };
        entry.resultFrame = resultFrame;
        observedResultOrder.push(entry.orderIndex);
        writeEvent("tool_use_frame", {
          ok: entry.dispatch.parityOk,
          runtime: "native-node-embedded",
          source,
          canaryMode,
          runId: entry.queued.runId,
          orderIndex: entry.orderIndex,
          frame: {
            ...entry.dispatch.toolUseFrame,
            orderIndex: entry.orderIndex,
            cancellationToken: entry.bridgeRequest.cancellationToken
          }
        });
        writeEvent("tool_result_frame", {
          ok: entry.bridgeParityOk,
          runtime: "native-node-embedded",
          source,
          canaryMode,
          runId: entry.queued.runId,
          orderIndex: entry.orderIndex,
          frame: resultFrame
        });
      }

      const cancelTarget = entries[cancelOrderIndex];
      const cancelRequest = nativeDartBridgeCancelDryRunRequest(
        {
          runId: cancelTarget.queued.runId,
          requestId: cancelTarget.queued.requestId,
          callId: cancelTarget.bridgeRequest.callId,
          bridgeRequestHash: cancelTarget.bridgeRequest.bridgeRequestHash,
          dispatchHash: cancelTarget.dispatch.dispatchHash,
          orderIndex: cancelTarget.orderIndex,
          orderCount,
          cancellationToken: cancelTarget.bridgeRequest.cancellationToken
        },
        "ordering_cancel_parity_after_bridge_ack"
      );
      writeEvent("cancel_request", {
        ok: true,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        runId: cancelTarget.queued.runId,
        orderIndex: cancelTarget.orderIndex,
        endpoint: "http://127.0.0.1:8765/api/native-gateway/dispatch-cancel-dry-run",
        cancelRequest
      });
      const cancelResponse = await postJsonToDartBridge(
        "/api/native-gateway/dispatch-cancel-dry-run",
        cancelRequest,
        2500
      );
      const cancelAck = cancelResponse.body;
      const cancelAckHash = metadataHash({
        cancelRequestHash: cancelRequest.cancelRequestHash,
        ok: cancelAck.ok === true,
        cancelAccepted: cancelAck.cancelAccepted === true,
        targetRunId: cancelAck.targetRunId,
        targetBridgeRequestHash: cancelAck.targetBridgeRequestHash,
        cancellationState: cancelAck.cancellationState,
        skippedReason: cancelAck.skippedReason,
        executionEnabled: cancelAck.executionEnabled === true,
        toolExecutionEnabled: cancelAck.toolExecutionEnabled === true,
        bridgeExecutionEnabled: cancelAck.bridgeExecutionEnabled === true
      });
      const expectedOrder = entries.map((entry) => entry.orderIndex);
      const runIds = entries.map((entry) => entry.queued.runId);
      const uniqueRunIds = new Set(runIds);
      const orderingParityOk =
        uniqueRunIds.size === entries.length &&
        JSON.stringify(observedBridgeOrder) === JSON.stringify(expectedOrder) &&
        JSON.stringify(observedResultOrder) === JSON.stringify(expectedOrder) &&
        entries.every((entry) => entry.bridgeParityOk === true);
      const cancellationParityOk =
        cancelAck.ok === true &&
        cancelAck.cancelAccepted === true &&
        cancelAck.cancelRequested === true &&
        cancelAck.cancelApplied === false &&
        cancelAck.targetRunId === cancelTarget.queued.runId &&
        cancelAck.targetBridgeRequestHash === cancelTarget.bridgeRequest.bridgeRequestHash &&
        cancelAck.cancellationState === "recorded_dry_run_no_active_execution" &&
        cancelAck.skippedReason === "native_dart_bridge_cancel_dry_run_only" &&
        cancelAck.executionEnabled === false &&
        cancelAck.toolExecutionEnabled === false &&
        cancelAck.bridgeExecutionEnabled === false;
      const validationOk =
        requestBuilder.validationOk === true &&
        entries.every((entry) => entry.dispatch.parityOk) &&
        orderingParityOk &&
        cancellationParityOk;

      writeEvent("cancel_ack", {
        ok: cancelAck.ok === true,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        runId: cancelTarget.queued.runId,
        orderIndex: cancelTarget.orderIndex,
        statusCode: cancelResponse.statusCode,
        responseBytesRead: cancelResponse.responseBytesRead,
        cancelRequestHash: cancelRequest.cancelRequestHash,
        cancelAckHash,
        cancellationParityOk,
        cancelAck
      });
      writeEvent("ordering_summary", {
        ok: validationOk,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        orderingPlanHash,
        orderCount,
        expectedOrder,
        observedBridgeOrder,
        observedResultOrder,
        uniqueRunIds: uniqueRunIds.size,
        orderingParityOk,
        cancellationParityOk,
        validationOk,
        cancelOrderIndex,
        cancelRequestHash: cancelRequest.cancelRequestHash,
        cancelAckHash,
        targetRunId: cancelTarget.queued.runId,
        targetBridgeRequestHash: cancelTarget.bridgeRequest.bridgeRequestHash,
        cancellationState: cancelAck.cancellationState,
        skippedReason: cancelAck.skippedReason,
        providerCallsEnabled: false,
        executionEnabled: false,
        toolExecutionEnabled: false,
        bridgeExecutionEnabled: false
      });
      writeEvent("end", {
        ok: validationOk,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        routeStatus: validationOk
          ? "native_dart_bridge_ordering_cancel_complete"
          : "native_dart_bridge_ordering_cancel_failed",
        finishReason: validationOk
          ? "native_dart_bridge_ordering_cancel_complete"
          : "native_dart_bridge_ordering_cancel_failed",
        orderingPlanHash,
        orderCount,
        orderingParityOk,
        cancellationParityOk,
        validationOk,
        cancelOrderIndex,
        providerCallsEnabled: false,
        executionEnabled: false,
        toolExecutionEnabled: false,
        bridgeExecutionEnabled: false
      });
      res.end();
    } catch (error) {
      if (!res.headersSent) {
        sendJson(res, error.statusCode || 400, {
          ok: false,
          error: {
            type: "invalid_request",
            code:
              error.code || "chat_native_dart_bridge_ordering_cancel_parse_failed",
            message: error.message || String(error),
            raw: error.raw || error.stack || error.message || String(error),
            statusCode: error.statusCode || null,
            body: error.body || null
          },
          runtime: "native-node-embedded",
          canaryOnly: true,
          dryRun: true,
          source,
          canaryMode,
          directCanary,
          openclawStarted: false,
          acceptedForRouting: false,
          providerCallsEnabled: false,
          executionEnabled: false,
          toolExecutionEnabled: false,
          bridgeExecutionEnabled: false,
          transportInvocationEnabled: false,
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
          code: error.code || "chat_native_dart_bridge_ordering_cancel_failed",
          message: error.message || String(error),
          raw: error.raw || error.stack || error.message || String(error),
          statusCode: error.statusCode || null,
          body: error.body || null
        }
      });
      res.end();
    }
  }

  async function handleChatNativeDartBridgeHapticCanaryStream(req, res) {
    const source = "native-dart-bridge-haptic-canary";
    const canaryMode = "native-dart-bridge-haptic-canary";
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
          source,
          canaryMode,
          directCanary,
          acceptedForRouting: false,
          acceptedForQueue: false,
          providerCallsEnabled: false,
          executionEnabled: false,
          toolExecutionEnabled: false,
          bridgeExecutionEnabled: false,
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
      const requestBuilder =
        providerToolPlanRequestBuilder(envelope, shape, queued, payload);
      const hapticToolSelection = nativeHapticCanaryToolSelection();
      const dispatch = syntheticToolDispatchDryRun(hapticToolSelection, queued);
      const bridgeRequest = nativeDartBridgeHapticCanaryRequest(
        dispatch,
        queued,
        {
          ...requestBuilder,
          toolSelectionHash: hapticToolSelection.selectionHash
        }
      );
      const canaryAllowlistOk =
        dispatch.route.method === "haptic.vibrate" &&
        bridgeRequest.canaryAllowlist.length === 1 &&
        bridgeRequest.canaryAllowlist[0] === "haptic.vibrate" &&
        bridgeRequest.input.durationMs > 0 &&
        bridgeRequest.input.durationMs <= 150;
      const ack = {
        parsed,
        route: "native_dart_bridge_haptic_canary",
        routeStatus: "native_dart_bridge_haptic_canary_started",
        source,
        canaryMode,
        directCanary,
        reason:
          "native forced one allowlisted haptic.vibrate call and sent it to Dart for real canary execution",
        provider: requestBuilder.provider,
        requestedModel: requestBuilder.requestedModel,
        providerModel: requestBuilder.providerModel,
        transport: requestBuilder.transport,
        requestHash: requestBuilder.requestHash,
        toolSelectionHash: hapticToolSelection.selectionHash,
        dispatchHash: bridgeRequest.dispatchHash,
        bridgeRequestHash: bridgeRequest.bridgeRequestHash,
        fixtureHash: dispatch.fixture.parsed.toolPlanHash,
        fixtureParityOk: dispatch.fixture.parityOk,
        dispatchParityOk: dispatch.parityOk,
        canaryAllowlist: bridgeRequest.canaryAllowlist,
        canaryAllowlistOk,
        hapticDurationMs: bridgeRequest.input.durationMs,
        executeParityOk: false,
        validationOk: false,
        selectedToolCount: 1,
        toolPlanCount: dispatch.fixture.parsed.toolPlanCount,
        allowedPlanCount: dispatch.fixture.parsed.allowedPlanCount,
        blockedPlanCount: dispatch.fixture.parsed.blockedPlanCount,
        providerCallStarted: false,
        providerCallsEnabled: false,
        transportInvocationEnabled: false,
        executionEnabled: true,
        toolExecutionEnabled: true,
        bridgeExecutionEnabled: true,
        sessionKey: shape.sessionKey,
        nativeSessionId: queued.nativeSessionId,
        requestId: queued.requestId,
        runId: queued.runId,
        sequence: queued.sequence,
        queueStatus: "native_dart_bridge_haptic_canary",
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
        "x-plawie-native-canary": "native-dart-bridge-haptic-canary"
      });
      writeEvent("ack", {
        ok: true,
        type: "res",
        id: typeof payload?.id === "string" ? payload.id : null,
        method: "chat.send",
        runtime: "native-node-embedded",
        canaryOnly: true,
        dryRun: false,
        source,
        canaryMode,
        directCanary,
        parsed: true,
        route: ack.route,
        routeStatus: ack.routeStatus,
        acceptedForRouting: true,
        acceptedForQueue: true,
        queuedForDryRun: false,
        queueStatus: "native_dart_bridge_haptic_canary",
        chatRoutingEnabled: false,
        providerCallsEnabled: false,
        executionEnabled: true,
        toolExecutionEnabled: true,
        bridgeExecutionEnabled: true,
        transportInvocationEnabled: false,
        productionGatewayPort,
        ack,
        requestShape: shape
      });

      writeEvent("tool_plan_summary", {
        ok: dispatch.fixture.parityOk,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        runId: queued.runId,
        toolPlanSummary: dispatch.fixture.parsed,
        plan: dispatch.plan,
        forcedAllowlist: bridgeRequest.canaryAllowlist,
        fixtureParityOk: dispatch.fixture.parityOk,
        dispatchParityOk: dispatch.parityOk,
        canaryAllowlistOk,
        providerCallsEnabled: false,
        executionEnabled: true,
        toolExecutionEnabled: true,
        bridgeExecutionEnabled: true
      });

      writeEvent("bridge_execute_request", {
        ok: canaryAllowlistOk && dispatch.parityOk,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        runId: queued.runId,
        endpoint: "http://127.0.0.1:8765/api/native-gateway/dispatch-execute-canary",
        bridgeRequest: {
          type: bridgeRequest.type,
          callId: bridgeRequest.callId,
          method: bridgeRequest.method,
          capability: bridgeRequest.capability,
          dartCapability: bridgeRequest.dartCapability,
          requiresUiThread: bridgeRequest.requiresUiThread,
          bridgeRequestHash: bridgeRequest.bridgeRequestHash,
          dispatchHash: bridgeRequest.dispatchHash,
          cancellationToken: bridgeRequest.cancellationToken,
          canaryAllowlist: bridgeRequest.canaryAllowlist,
          input: bridgeRequest.input,
          dryRun: bridgeRequest.dryRun,
          providerCallsEnabled: bridgeRequest.providerCallsEnabled,
          executionEnabled: bridgeRequest.executionEnabled,
          toolExecutionEnabled: bridgeRequest.toolExecutionEnabled,
          bridgeExecutionEnabled: bridgeRequest.bridgeExecutionEnabled
        }
      });

      const bridgeResponse = await postJsonToDartBridge(
        "/api/native-gateway/dispatch-execute-canary",
        bridgeRequest,
        3000,
        "execute-canary"
      );
      const executeAck = bridgeResponse.body;
      const executeResult =
        executeAck?.result && typeof executeAck.result === "object"
          ? executeAck.result
          : {};
      const returnedDuration = Number(executeAck.durationMs);
      const durationBounded =
        Number.isFinite(returnedDuration) &&
        returnedDuration > 0 &&
        returnedDuration <= 150;
      const executeAckHash = metadataHash({
        bridgeRequestHash: bridgeRequest.bridgeRequestHash,
        ok: executeAck.ok === true,
        accepted: executeAck.accepted === true,
        command: executeAck.command,
        canaryAllowlistOk: executeAck.canaryAllowlistOk === true,
        dryRun: executeAck.dryRun === false,
        executed: executeAck.executed === true,
        resultStatus: executeResult.status || null,
        durationMs: executeAck.durationMs,
        providerCallsEnabled: executeAck.providerCallsEnabled === true,
        executionEnabled: executeAck.executionEnabled === true,
        toolExecutionEnabled: executeAck.toolExecutionEnabled === true,
        bridgeExecutionEnabled: executeAck.bridgeExecutionEnabled === true
      });
      const resultStatus = executeResult.status || "unknown";
      const resultStatusOk =
        resultStatus === "vibrated" || resultStatus === "vibrated_fallback";
      const executeParityOk =
        requestBuilder.validationOk === true &&
        dispatch.parityOk === true &&
        canaryAllowlistOk === true &&
        executeAck.ok === true &&
        executeAck.accepted === true &&
        executeAck.command === "haptic.vibrate" &&
        executeAck.canaryAllowlistOk === true &&
        executeAck.dryRun === false &&
        executeAck.executed === true &&
        durationBounded &&
        resultStatusOk &&
        executeAck.providerCallsEnabled === false &&
        executeAck.executionEnabled === true &&
        executeAck.toolExecutionEnabled === true &&
        executeAck.bridgeExecutionEnabled === true;
      const toolResultFrame = {
        type: "tool_result",
        id: dispatch.callId,
        name: "haptic.vibrate",
        result: {
          ok: executeParityOk,
          dryRun: false,
          executed: executeAck.executed === true,
          accepted: executeAck.accepted === true,
          status: resultStatus,
          result: executeResult,
          executeAckHash,
          bridgeRequestHash: bridgeRequest.bridgeRequestHash,
          cancellationToken: bridgeRequest.cancellationToken,
          canaryAllowlistOk: executeAck.canaryAllowlistOk === true,
          durationMs: executeAck.durationMs,
          providerCallsEnabled: false,
          executionEnabled: true,
          toolExecutionEnabled: true,
          bridgeExecutionEnabled: true
        },
        runtime: "native-node-embedded",
        source,
        canaryMode,
        dryRun: false,
        executionEnabled: true,
        toolExecutionEnabled: true
      };

      writeEvent("bridge_execute_ack", {
        ok: executeAck.ok === true,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        runId: queued.runId,
        statusCode: bridgeResponse.statusCode,
        responseBytesRead: bridgeResponse.responseBytesRead,
        bridgeRequestHash: bridgeRequest.bridgeRequestHash,
        executeAckHash,
        executeParityOk,
        executeAck
      });
      writeEvent("tool_use_frame", {
        ok: dispatch.parityOk,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        runId: queued.runId,
        frame: bridgeRequest.toolUseFrame
      });
      writeEvent("tool_result_frame", {
        ok: executeParityOk,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        runId: queued.runId,
        frame: toolResultFrame
      });
      writeEvent("haptic_canary_summary", {
        ok: executeParityOk,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        runId: queued.runId,
        requestHash: requestBuilder.requestHash,
        toolSelectionHash: hapticToolSelection.selectionHash,
        dispatchHash: bridgeRequest.dispatchHash,
        bridgeRequestHash: bridgeRequest.bridgeRequestHash,
        executeAckHash,
        fixtureParityOk: dispatch.fixture.parityOk,
        dispatchParityOk: dispatch.parityOk,
        canaryAllowlistOk,
        executeParityOk,
        validationOk: executeParityOk,
        toolName: "haptic.vibrate",
        capability: "haptic",
        dartCapability: dispatch.route.dartCapability,
        durationMs: executeAck.durationMs,
        resultStatus,
        providerCallsEnabled: false,
        executionEnabled: true,
        toolExecutionEnabled: true,
        bridgeExecutionEnabled: true
      });
      writeEvent("end", {
        ok: executeParityOk,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        runId: queued.runId,
        routeStatus: executeParityOk
          ? "native_dart_bridge_haptic_canary_complete"
          : "native_dart_bridge_haptic_canary_failed",
        finishReason: executeParityOk
          ? "native_dart_bridge_haptic_canary_complete"
          : "native_dart_bridge_haptic_canary_failed",
        requestHash: requestBuilder.requestHash,
        dispatchHash: bridgeRequest.dispatchHash,
        bridgeRequestHash: bridgeRequest.bridgeRequestHash,
        executeAckHash,
        fixtureParityOk: dispatch.fixture.parityOk,
        dispatchParityOk: dispatch.parityOk,
        canaryAllowlistOk,
        executeParityOk,
        validationOk: executeParityOk,
        toolName: "haptic.vibrate",
        capability: "haptic",
        providerCallsEnabled: false,
        executionEnabled: true,
        toolExecutionEnabled: true,
        bridgeExecutionEnabled: true
      });
      res.end();
    } catch (error) {
      if (!res.headersSent) {
        sendJson(res, error.statusCode || 400, {
          ok: false,
          error: {
            type: "invalid_request",
            code:
              error.code || "chat_native_dart_bridge_haptic_canary_parse_failed",
            message: error.message || String(error),
            raw: error.raw || error.stack || error.message || String(error),
            statusCode: error.statusCode || null,
            body: error.body || null
          },
          runtime: "native-node-embedded",
          canaryOnly: true,
          dryRun: false,
          source,
          canaryMode,
          directCanary,
          openclawStarted: false,
          acceptedForRouting: false,
          providerCallsEnabled: false,
          executionEnabled: false,
          toolExecutionEnabled: false,
          bridgeExecutionEnabled: false,
          transportInvocationEnabled: false,
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
          code: error.code || "chat_native_dart_bridge_haptic_canary_failed",
          message: error.message || String(error),
          raw: error.raw || error.stack || error.message || String(error),
          statusCode: error.statusCode || null,
          body: error.body || null
        }
      });
      res.end();
    }
  }

  async function handleChatNativeDartBridgeReadOnlyCanaryStream(req, res) {
    const source = "native-dart-bridge-readonly-canary";
    const canaryMode = "native-dart-bridge-readonly-canary";
    const directCanary = true;
    const canaryAllowlist = ["flash.status", "sensor.list"];

    function writeEvent(event, payload) {
      if (res.writableEnded) return;
      res.write(`${JSON.stringify({
        event,
        ...payload
      })}\n`);
    }

    function readOnlyResultShapeOk(method, result) {
      if (method === "flash.status") {
        return typeof result.on === "boolean";
      }
      if (method === "sensor.list") {
        return Array.isArray(result.sensors) && result.sensors.length > 0;
      }
      return false;
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
          source,
          canaryMode,
          directCanary,
          acceptedForRouting: false,
          acceptedForQueue: false,
          providerCallsEnabled: false,
          executionEnabled: false,
          toolExecutionEnabled: false,
          bridgeExecutionEnabled: false,
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
      const requestBuilder =
        providerToolPlanRequestBuilder(envelope, shape, queued, payload);
      const entries = canaryAllowlist.map((toolName, index) => {
        const toolSelection = nativeReadOnlyCanaryToolSelection(
          toolName,
          canaryAllowlist
        );
        const dispatch = syntheticToolDispatchDryRun(toolSelection, queued);
        const bridgeRequest = nativeDartBridgeReadOnlyCanaryRequest(
          dispatch,
          queued,
          {
            ...requestBuilder,
            toolSelectionHash: toolSelection.selectionHash
          },
          index,
          canaryAllowlist.length,
          canaryAllowlist
        );
        return {
          toolName,
          orderIndex: index,
          toolSelection,
          dispatch,
          bridgeRequest
        };
      });
      const canaryAllowlistOk =
        entries.length === canaryAllowlist.length &&
        entries.every((entry, index) =>
          entry.bridgeRequest.method === canaryAllowlist[index] &&
          entry.bridgeRequest.canaryAllowlist.length === canaryAllowlist.length &&
          canaryAllowlist.every((name) =>
            entry.bridgeRequest.canaryAllowlist.includes(name)
          ) &&
          Object.keys(entry.bridgeRequest.input).length === 0
        );
      const planHash = metadataHash({
        runId: queued.runId,
        source,
        canaryMode,
        canaryAllowlist,
        dispatchHashes: entries.map((entry) => entry.bridgeRequest.dispatchHash),
        bridgeRequestHashes: entries.map((entry) =>
          entry.bridgeRequest.bridgeRequestHash
        )
      });
      const ack = {
        parsed,
        route: "native_dart_bridge_readonly_canary",
        routeStatus: "native_dart_bridge_readonly_canary_started",
        source,
        canaryMode,
        directCanary,
        reason:
          "native forced two allowlisted read-only calls and sent them to Dart for real canary execution",
        provider: requestBuilder.provider,
        requestedModel: requestBuilder.requestedModel,
        providerModel: requestBuilder.providerModel,
        transport: requestBuilder.transport,
        requestHash: requestBuilder.requestHash,
        readOnlyPlanHash: planHash,
        bridgeRequestHashes: entries.map((entry) =>
          entry.bridgeRequest.bridgeRequestHash
        ),
        dispatchHashes: entries.map((entry) => entry.bridgeRequest.dispatchHash),
        fixtureParityOk: entries.every((entry) => entry.dispatch.fixture.parityOk),
        dispatchParityOk: entries.every((entry) => entry.dispatch.parityOk),
        canaryAllowlist,
        canaryAllowlistOk,
        executeParityOk: false,
        validationOk: false,
        selectedToolCount: entries.length,
        forcedToolNames: entries.map((entry) => entry.bridgeRequest.method),
        providerCallStarted: false,
        providerCallsEnabled: false,
        transportInvocationEnabled: false,
        executionEnabled: true,
        toolExecutionEnabled: true,
        bridgeExecutionEnabled: true,
        readOnly: true,
        sessionKey: shape.sessionKey,
        nativeSessionId: queued.nativeSessionId,
        requestId: queued.requestId,
        runId: queued.runId,
        sequence: queued.sequence,
        queueStatus: "native_dart_bridge_readonly_canary",
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
        "x-plawie-native-canary": "native-dart-bridge-readonly-canary"
      });
      writeEvent("ack", {
        ok: true,
        type: "res",
        id: typeof payload?.id === "string" ? payload.id : null,
        method: "chat.send",
        runtime: "native-node-embedded",
        canaryOnly: true,
        dryRun: false,
        source,
        canaryMode,
        directCanary,
        parsed: true,
        route: ack.route,
        routeStatus: ack.routeStatus,
        acceptedForRouting: true,
        acceptedForQueue: true,
        queuedForDryRun: false,
        queueStatus: "native_dart_bridge_readonly_canary",
        chatRoutingEnabled: false,
        providerCallsEnabled: false,
        executionEnabled: true,
        toolExecutionEnabled: true,
        bridgeExecutionEnabled: true,
        transportInvocationEnabled: false,
        productionGatewayPort,
        ack,
        requestShape: shape
      });

      writeEvent("tool_plan_summary", {
        ok: entries.every((entry) => entry.dispatch.parityOk),
        runtime: "native-node-embedded",
        source,
        canaryMode,
        runId: queued.runId,
        readOnlyPlanHash: planHash,
        orderCount: entries.length,
        expectedOrder: canaryAllowlist,
        forcedAllowlist: canaryAllowlist,
        plannedTools: entries.map((entry) => ({
          orderIndex: entry.orderIndex,
          toolName: entry.bridgeRequest.method,
          fixtureParityOk: entry.dispatch.fixture.parityOk,
          dispatchParityOk: entry.dispatch.parityOk,
          bridgeRequestHash: entry.bridgeRequest.bridgeRequestHash
        })),
        fixtureParityOk: entries.every((entry) => entry.dispatch.fixture.parityOk),
        dispatchParityOk: entries.every((entry) => entry.dispatch.parityOk),
        canaryAllowlistOk,
        providerCallsEnabled: false,
        executionEnabled: true,
        toolExecutionEnabled: true,
        bridgeExecutionEnabled: true,
        readOnly: true
      });

      const results = [];
      for (const entry of entries) {
        const bridgeRequest = entry.bridgeRequest;
        writeEvent("bridge_execute_request", {
          ok: canaryAllowlistOk && entry.dispatch.parityOk,
          runtime: "native-node-embedded",
          source,
          canaryMode,
          runId: queued.runId,
          orderIndex: entry.orderIndex,
          orderCount: entries.length,
          endpoint:
            "http://127.0.0.1:8765/api/native-gateway/dispatch-execute-canary",
          bridgeRequest: {
            type: bridgeRequest.type,
            callId: bridgeRequest.callId,
            orderIndex: bridgeRequest.orderIndex,
            orderCount: bridgeRequest.orderCount,
            method: bridgeRequest.method,
            capability: bridgeRequest.capability,
            dartCapability: bridgeRequest.dartCapability,
            requiresUiThread: bridgeRequest.requiresUiThread,
            bridgeRequestHash: bridgeRequest.bridgeRequestHash,
            dispatchHash: bridgeRequest.dispatchHash,
            cancellationToken: bridgeRequest.cancellationToken,
            canaryAllowlist: bridgeRequest.canaryAllowlist,
            input: bridgeRequest.input,
            readOnly: bridgeRequest.readOnly,
            dryRun: bridgeRequest.dryRun,
            providerCallsEnabled: bridgeRequest.providerCallsEnabled,
            executionEnabled: bridgeRequest.executionEnabled,
            toolExecutionEnabled: bridgeRequest.toolExecutionEnabled,
            bridgeExecutionEnabled: bridgeRequest.bridgeExecutionEnabled
          }
        });

        const bridgeResponse = await postJsonToDartBridge(
          "/api/native-gateway/dispatch-execute-canary",
          bridgeRequest,
          3000,
          "execute-canary"
        );
        const executeAck = bridgeResponse.body;
        const executeResult =
          executeAck?.result && typeof executeAck.result === "object"
            ? executeAck.result
            : {};
        const resultStatus =
          executeAck.resultStatus || executeResult.status || "ok";
        const resultShapeOk = readOnlyResultShapeOk(
          bridgeRequest.method,
          executeResult
        );
        const executeAckHash = metadataHash({
          bridgeRequestHash: bridgeRequest.bridgeRequestHash,
          orderIndex: entry.orderIndex,
          ok: executeAck.ok === true,
          accepted: executeAck.accepted === true,
          command: executeAck.command,
          canaryAllowlistOk: executeAck.canaryAllowlistOk === true,
          dryRun: executeAck.dryRun === false,
          executed: executeAck.executed === true,
          resultStatus,
          resultShapeOk,
          providerCallsEnabled: executeAck.providerCallsEnabled === true,
          executionEnabled: executeAck.executionEnabled === true,
          toolExecutionEnabled: executeAck.toolExecutionEnabled === true,
          bridgeExecutionEnabled: executeAck.bridgeExecutionEnabled === true
        });
        const executeParityOk =
          requestBuilder.validationOk === true &&
          entry.dispatch.parityOk === true &&
          canaryAllowlistOk === true &&
          executeAck.ok === true &&
          executeAck.accepted === true &&
          executeAck.command === bridgeRequest.method &&
          executeAck.canaryAllowlistOk === true &&
          executeAck.dryRun === false &&
          executeAck.executed === true &&
          resultStatus === "ok" &&
          resultShapeOk &&
          executeAck.providerCallsEnabled === false &&
          executeAck.executionEnabled === true &&
          executeAck.toolExecutionEnabled === true &&
          executeAck.bridgeExecutionEnabled === true;
        const toolResultFrame = {
          type: "tool_result",
          id: bridgeRequest.callId,
          name: bridgeRequest.method,
          result: {
            ok: executeParityOk,
            dryRun: false,
            executed: executeAck.executed === true,
            accepted: executeAck.accepted === true,
            status: resultStatus,
            result: executeResult,
            executeAckHash,
            bridgeRequestHash: bridgeRequest.bridgeRequestHash,
            cancellationToken: bridgeRequest.cancellationToken,
            canaryAllowlistOk: executeAck.canaryAllowlistOk === true,
            resultShapeOk,
            providerCallsEnabled: false,
            executionEnabled: true,
            toolExecutionEnabled: true,
            bridgeExecutionEnabled: true,
            readOnly: true
          },
          runtime: "native-node-embedded",
          source,
          canaryMode,
          dryRun: false,
          executionEnabled: true,
          toolExecutionEnabled: true,
          readOnly: true
        };
        results.push({
          orderIndex: entry.orderIndex,
          toolName: bridgeRequest.method,
          capability: bridgeRequest.capability,
          dartCapability: bridgeRequest.dartCapability,
          bridgeRequestHash: bridgeRequest.bridgeRequestHash,
          executeAckHash,
          executeParityOk,
          resultStatus,
          resultShapeOk,
          executeAck,
          toolResultFrame
        });

        writeEvent("bridge_execute_ack", {
          ok: executeAck.ok === true,
          runtime: "native-node-embedded",
          source,
          canaryMode,
          runId: queued.runId,
          orderIndex: entry.orderIndex,
          orderCount: entries.length,
          statusCode: bridgeResponse.statusCode,
          responseBytesRead: bridgeResponse.responseBytesRead,
          bridgeRequestHash: bridgeRequest.bridgeRequestHash,
          executeAckHash,
          executeParityOk,
          resultStatus,
          resultShapeOk,
          executeAck
        });
        writeEvent("tool_use_frame", {
          ok: entry.dispatch.parityOk,
          runtime: "native-node-embedded",
          source,
          canaryMode,
          runId: queued.runId,
          orderIndex: entry.orderIndex,
          frame: bridgeRequest.toolUseFrame
        });
        writeEvent("tool_result_frame", {
          ok: executeParityOk,
          runtime: "native-node-embedded",
          source,
          canaryMode,
          runId: queued.runId,
          orderIndex: entry.orderIndex,
          frame: toolResultFrame
        });
      }

      const executeParityOk =
        results.length === canaryAllowlist.length &&
        results.every((result, index) =>
          result.executeParityOk === true &&
          result.toolName === canaryAllowlist[index]
        );
      const resultStatuses = results.map((result) => ({
        orderIndex: result.orderIndex,
        toolName: result.toolName,
        resultStatus: result.resultStatus,
        resultShapeOk: result.resultShapeOk,
        executeParityOk: result.executeParityOk
      }));
      writeEvent("readonly_canary_summary", {
        ok: executeParityOk,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        runId: queued.runId,
        requestHash: requestBuilder.requestHash,
        readOnlyPlanHash: planHash,
        commandCount: results.length,
        expectedOrder: canaryAllowlist,
        observedOrder: results.map((result) => result.toolName),
        resultStatuses,
        bridgeRequestHashes: results.map((result) => result.bridgeRequestHash),
        executeAckHashes: results.map((result) => result.executeAckHash),
        fixtureParityOk: entries.every((entry) => entry.dispatch.fixture.parityOk),
        dispatchParityOk: entries.every((entry) => entry.dispatch.parityOk),
        canaryAllowlistOk,
        executeParityOk,
        validationOk: executeParityOk,
        providerCallsEnabled: false,
        executionEnabled: true,
        toolExecutionEnabled: true,
        bridgeExecutionEnabled: true,
        readOnly: true
      });
      writeEvent("end", {
        ok: executeParityOk,
        runtime: "native-node-embedded",
        source,
        canaryMode,
        runId: queued.runId,
        routeStatus: executeParityOk
          ? "native_dart_bridge_readonly_canary_complete"
          : "native_dart_bridge_readonly_canary_failed",
        finishReason: executeParityOk
          ? "native_dart_bridge_readonly_canary_complete"
          : "native_dart_bridge_readonly_canary_failed",
        requestHash: requestBuilder.requestHash,
        readOnlyPlanHash: planHash,
        commandCount: results.length,
        expectedOrder: canaryAllowlist,
        observedOrder: results.map((result) => result.toolName),
        canaryAllowlistOk,
        executeParityOk,
        validationOk: executeParityOk,
        providerCallsEnabled: false,
        executionEnabled: true,
        toolExecutionEnabled: true,
        bridgeExecutionEnabled: true,
        readOnly: true
      });
      res.end();
    } catch (error) {
      if (!res.headersSent) {
        sendJson(res, error.statusCode || 400, {
          ok: false,
          error: {
            type: "invalid_request",
            code:
              error.code || "chat_native_dart_bridge_readonly_canary_parse_failed",
            message: error.message || String(error),
            raw: error.raw || error.stack || error.message || String(error),
            statusCode: error.statusCode || null,
            body: error.body || null
          },
          runtime: "native-node-embedded",
          canaryOnly: true,
          dryRun: false,
          source,
          canaryMode,
          directCanary,
          openclawStarted: false,
          acceptedForRouting: false,
          providerCallsEnabled: false,
          executionEnabled: false,
          toolExecutionEnabled: false,
          bridgeExecutionEnabled: false,
          transportInvocationEnabled: false,
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
          code: error.code || "chat_native_dart_bridge_readonly_canary_failed",
          message: error.message || String(error),
          raw: error.raw || error.stack || error.message || String(error),
          statusCode: error.statusCode || null,
          body: error.body || null
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

    if (pathname === "/gateway/chat-provider-request-builder-stream") {
      handleChatProviderRequestBuilderStream(req, res);
      return true;
    }

    if (pathname === "/gateway/chat-provider-transport-shim-stream") {
      handleChatProviderTransportShimStream(req, res);
      return true;
    }

    if (pathname === "/gateway/chat-provider-live-canary-stream") {
      handleChatProviderLiveCanaryStream(req, res);
      return true;
    }

    if (pathname === "/gateway/chat-provider-stream-parser-parity-stream") {
      handleChatProviderStreamParserParityStream(req, res);
      return true;
    }

    if (pathname === "/gateway/chat-provider-tool-plan-canary-stream") {
      handleChatProviderToolPlanCanaryStream(req, res);
      return true;
    }

    if (pathname === "/gateway/chat-tool-dispatch-dry-run-stream") {
      handleChatToolDispatchDryRunStream(req, res);
      return true;
    }

    if (pathname === "/gateway/chat-native-dart-bridge-dry-run-stream") {
      handleChatNativeDartBridgeDryRunStream(req, res);
      return true;
    }

    if (pathname === "/gateway/chat-native-dart-bridge-ordering-cancel-stream") {
      handleChatNativeDartBridgeOrderingCancelStream(req, res);
      return true;
    }

    if (pathname === "/gateway/chat-native-dart-bridge-haptic-canary-stream") {
      handleChatNativeDartBridgeHapticCanaryStream(req, res);
      return true;
    }

    if (pathname === "/gateway/chat-native-dart-bridge-readonly-canary-stream") {
      handleChatNativeDartBridgeReadOnlyCanaryStream(req, res);
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
