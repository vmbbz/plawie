# Native Provider Owner Stream Parity

Date: 2026-05-31

## Goal

Let embedded native Node temporarily own the production Gateway port `18789`
and prove provider stream parsing, provider error forwarding, timeout
normalization, and cancellation mapping under the production-port owner lane.

This follows the bounded live provider canary. It still remains explicit,
diagnostics-only, OpenRouter-only, and followed by mandatory PRoot rollback.

## Flow

- PRoot starts as the healthy production runtime on `18789`.
- Embedded native Node smoke on `18790` is stopped.
- PRoot is stopped and the production port is released.
- Native binds `18789` as a temporary owner.
- Native accepts a `chat.send` canary on
  `/gateway/chat-provider-stream-parser-parity-stream`.
- Native emits deterministic parser fixtures before touching provider network:

```text
parser_fixture
error_fixture
timeout_fixture
cancellation_fixture
```

- Native attempts one tiny OpenRouter stream with:

```text
stream: true
max_tokens: 32
temperature: 0
```

- Native either parses live provider deltas or forwards the raw provider error.
- Native stops, releases `18789`, restarts PRoot, and restores native smoke.

## Diagnostics Endpoint

Diagnostics builds expose:

```text
POST /api/native-gateway/production-provider-stream-parser-parity
```

Optional body:

```json
{
  "model": "openrouter/openai/gpt-oss-20b:free",
  "prompt": "native production provider stream parser parity"
}
```

The endpoint resolves the OpenRouter API key from the app's OpenClaw config. A
test harness may pass an explicit `providerConfig`, but reports never include
the API key.

## Hidden Command

Diagnostics builds also expose:

```text
/native-stream-owner
```

Aliases:

```text
/native-production-stream
/native-stream-parity-owner
/native-provider-stream-owner
```

## Success Shape

Expected successful diagnostics report for a live HTTP 200 stream:

```text
ok: true
phase: hidden-production-port-provider-stream-parser-parity
mode: native-production-port-provider-stream-parser-parity-with-rollback
parserFixtureOk: true
errorFixtureOk: true
timeoutFixtureOk: true
cancellationFixtureOk: true
providerCallStartedOk: true
providerResponseOk: true
liveParserSummaryOk: true
streamSuccessOk: true
rollbackHealthOk: true
```

If OpenRouter rejects the request because of billing, quota, or upstream rate
limits, the canary can still prove the production-port parser/error path:

```text
parserFixtureOk: true
errorFixtureOk: true
timeoutFixtureOk: true
cancellationFixtureOk: true
providerCallStartedOk: true
providerErrorSurfaceOk: true
rawProviderErrorForwarded: true
rollbackHealthOk: true
```

That outcome is useful stream/error plumbing proof, but not a successful live
delta parse.

## Boundary

This phase still does not promote native Node to production. Provider calls are
allowed only for this explicit canary, and Android/OpenClaw tool execution
remains disabled.
