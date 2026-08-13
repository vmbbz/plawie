import { definePluginEntry } from "openclaw/plugin-sdk/plugin-entry";

const PLUGIN_ID = "plawie-tool-probe-guard";
const ALLOWED_TOOL = "session_status";
const PROBE_PROMPT = `
[PLAWIE_EXPLICIT_TOOL_COMPATIBILITY_PROBE_V1]
This is a user-approved, side-effect-free compatibility test.
Call the session_status tool exactly once with this exact input:
{"sessionKey":"current"}
Do not call any other tool. After the tool result returns, reply with exactly:
PLAWIE TOOL COMPATIBILITY VERIFIED
`;
const RUN_TTL_MS = 10 * 60 * 1000;
const MAX_TRACKED_RUNS = 8;

function normalized(value) {
  return String(value || "").replace(/\r\n/g, "\n").trim();
}

function exactInput(params) {
  if (!params || typeof params !== "object" || Array.isArray(params)) {
    return false;
  }
  const keys = Object.keys(params);
  return keys.length === 1 && keys[0] === "sessionKey" && params.sessionKey === "current";
}

export default definePluginEntry({
  id: PLUGIN_ID,
  name: "Plawie tool probe guard",
  description:
    "Fail-closed execution guard for Plawie's explicit read-only provider tool probe.",
  register(api) {
    const activeRuns = new Map();

    function prune(now = Date.now()) {
      for (const [runId, expiresAt] of activeRuns) {
        if (expiresAt <= now) activeRuns.delete(runId);
      }
    }

    api.on(
      "before_agent_run",
      async (event, ctx) => {
        if (normalized(event?.prompt) !== normalized(PROBE_PROMPT)) return;
        prune();
        const runId = String(ctx?.runId || "").trim();
        if (!runId) {
          return {
            outcome: "block",
            reason: "probe_run_identity_missing",
            message:
              "Compatibility test stopped because the Gateway did not expose a bounded run identity.",
          };
        }
        if (activeRuns.size >= MAX_TRACKED_RUNS && !activeRuns.has(runId)) {
          return {
            outcome: "block",
            reason: "probe_guard_capacity_reached",
            message:
              "Compatibility test stopped because the bounded probe guard is busy.",
          };
        }
        activeRuns.set(runId, Date.now() + RUN_TTL_MS);
      },
      { priority: 1000, timeoutMs: 1000 },
    );

    api.on(
      "before_tool_call",
      async (event, ctx) => {
        prune();
        const runId = String(event?.runId || ctx?.runId || "").trim();
        if (!runId || !activeRuns.has(runId)) return;
        if (event?.toolName !== ALLOWED_TOOL || !exactInput(event?.params)) {
          return {
            block: true,
            blockReason:
              "The explicit Plawie compatibility probe permits only session_status with the fixed current-session input.",
          };
        }
      },
      { priority: 1000, timeoutMs: 1000 },
    );

    api.on("agent_end", async (_event, ctx) => {
      const runId = String(ctx?.runId || "").trim();
      if (runId) activeRuns.delete(runId);
      prune();
    });

    api.logger.info(
      `[${PLUGIN_ID}] registered scope=exact-probe tools=${ALLOWED_TOOL} failClosed=true`,
    );
  },
});
