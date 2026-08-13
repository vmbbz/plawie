import { definePluginEntry } from "openclaw/plugin-sdk/plugin-entry";
import { buildProviderReplayFamilyHooks } from "openclaw/plugin-sdk/provider-model-shared";
import { buildProviderToolCompatFamilyHooks } from "openclaw/plugin-sdk/provider-tools";

const PLUGIN_ID = "plawie-venice-compat";
const PROVIDER_ID = "venice";
const PROFILE_VERSION = "venice-gemini-openclaw-2026.7.1-v1";

const geminiReplayHooks = buildProviderReplayFamilyHooks({
  family: "passthrough-gemini",
});
const geminiToolHooks = buildProviderToolCompatFamilyHooks("gemini");

function isVeniceGemini(context) {
  if (String(context?.provider || "").toLowerCase() !== PROVIDER_ID) {
    return false;
  }
  const modelId = String(context?.modelId || "").trim().toLowerCase();
  return /^gemini(?:[-/.]|$)/.test(modelId);
}

function invokeScoped(hook, context) {
  return isVeniceGemini(context) && typeof hook === "function"
    ? hook(context)
    : undefined;
}

export default definePluginEntry({
  id: PLUGIN_ID,
  name: "Plawie Venice compatibility",
  description:
    "Venice-hosted Gemini replay and tool-schema compatibility for Plawie's verified mobile Gateway.",
  register(api) {
    api.registerProvider({
      id: PROVIDER_ID,
      pluginId: PLUGIN_ID,
      label: "Venice",
      auth: [],
      buildReplayPolicy: (context) =>
        invokeScoped(geminiReplayHooks.buildReplayPolicy, context),
      sanitizeReplayHistory: (context) =>
        invokeScoped(geminiReplayHooks.sanitizeReplayHistory, context),
      normalizeToolSchemas: (context) =>
        invokeScoped(geminiToolHooks.normalizeToolSchemas, context),
      inspectToolSchemas: (context) =>
        invokeScoped(geminiToolHooks.inspectToolSchemas, context),
    });
    api.logger.info(
      `[${PLUGIN_ID}] registered profile=${PROFILE_VERSION} provider=${PROVIDER_ID} scope=gemini-only`,
    );
  },
});
