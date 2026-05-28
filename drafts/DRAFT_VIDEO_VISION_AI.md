# Draft: Video Vision AI

Last updated: 2026-05-28

## Status

Historical draft. The local-video plan in this file originally assumed a PRoot
`llama-server` on `:8081`. That is not current architecture.

Current local inference uses fllama/NDK through `LocalLlmService`. Any future
offline video or multimodal work must start from the current fllama APIs and the
current model lanes:

- Cloud Gateway model for cloud multimodal/video routing.
- Direct `local-llm/...` for private local fllama inference.
- Manual `plawie_ndk/local-llm` bridge only when Gateway tool transport is
  explicitly required.

## Preserved Product Idea

Video vision remains a valid feature idea:

1. Record a short clip on device.
2. Extract representative frames.
3. Send frames to an active multimodal-capable model.
4. Summarize the scene for the user.

The old implementation details are not valid:

- Do not post frames to local `llama-server :8081`.
- Do not assume PRoot ffmpeg is part of local model inference.
- Do not describe this as complete without verifying current code paths.

## Future Design Starting Point

Use current source files:

- `lib/services/local_llm_service.dart`
- `lib/services/gateway_service.dart`
- `lib/services/model_execution_policy.dart`
- `lib/services/model_provider_catalog.dart`

Design questions for a future pass:

- Which active local models actually support image/video through fllama?
- What frame count and resolution fit the active local context budget?
- Should cloud video remain Gateway-only for tool/session visibility?
- How should the UI disclose when local vision is unavailable?
