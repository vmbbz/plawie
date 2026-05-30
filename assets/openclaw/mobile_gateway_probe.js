const jsonHeaders = {
  "content-type": "application/json",
  "cache-control": "no-store"
};

function sendJson(res, statusCode, body) {
  res.writeHead(statusCode, jsonHeaders);
  res.end(JSON.stringify(body));
}

function nowIso() {
  return new Date().toISOString();
}

function createMobileGatewayProbe({
  preflight,
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
      productionSkillsLoaded: false,
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

  function rejectChat(res) {
    sendJson(res, 409, {
      error: {
        type: "probe_only_runtime",
        code: "chat_disabled",
        message:
          "Embedded native Node is running only a Gateway bootstrap probe. Chat and provider calls remain on the production PRoot Gateway."
      },
      runtime: "native-node-embedded",
      canaryOnly: true,
      productionGatewayPort
    });
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

    if (pathname === "/v1/models") {
      sendJson(res, 200, modelList());
      return true;
    }

    if (pathname === "/v1/chat/completions") {
      rejectChat(res);
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
