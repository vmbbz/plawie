# Native Provider Owner Live

Date: 2026-05-31

## Goal

Let embedded native Node temporarily own the production Gateway port `18789`
and perform one explicitly bounded OpenRouter provider call before rolling back
to PRoot.

This is the first production-port owner phase allowed to touch provider network
or billing surfaces. It remains diagnostics-only and requires an OpenRouter API
key from the app config.

## Flow

- PRoot starts as the healthy production runtime on `18789`.
- Embedded native Node smoke on `18790` is stopped.
- PRoot is stopped and the production port is released.
- Native binds `18789` as a temporary owner.
- Native accepts a `chat.send` canary on
  `/gateway/chat-provider-live-canary-stream`.
- Native sends a tiny OpenRouter chat-completions request with:

```text
stream: true
max_tokens: 32
temperature: 0
```

- Native streams provider chunks or forwards the raw provider error payload.
- Native stops, releases `18789`, restarts PRoot, and restores native smoke.

## Diagnostics Endpoint

Diagnostics builds expose:

```text
POST /api/native-gateway/production-provider-live-canary
```

Optional body:

```json
{
  "model": "openrouter/openai/gpt-oss-20b:free",
  "prompt": "native production provider live canary"
}
```

The endpoint resolves the OpenRouter API key from the app's OpenClaw config. A
test harness may pass an explicit `providerConfig`, but reports never include
the API key.

## Hidden Command

Diagnostics builds also expose:

```text
/native-live-owner
```

Aliases:

```text
/native-production-live
/native-provider-live-owner
```

## Success Shape

Expected successful diagnostics report:

```text
ok: true
phase: hidden-production-port-provider-live-canary
mode: native-production-port-provider-live-with-rollback
nativeInitialGuardOk: true
liveCanaryOk: true
liveSuccessOk: true
providerRequestOk: true
providerCallStartedOk: true
providerResponseOk: true
liveOrderOk: true
liveEndOk: true
postLiveGuardOk: true
rollbackHealthOk: true
```

If OpenRouter rejects the request because of billing, quota, or credentials, the
canary can still prove the production-port provider path reached the provider
and preserved the raw error:

```text
providerCallStartedOk: true
providerErrorSurfaceOk: true
rawProviderErrorForwarded: true
rollbackHealthOk: true
```

That outcome is useful plumbing proof, but not a successful provider stream.

## Boundary

This phase still does not promote native Node to production. The call is
explicit, tiny, diagnostics-only, OpenRouter-only, and followed by mandatory
PRoot rollback.
