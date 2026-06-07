# Android Skill Config UI Design

## Goal

Give fresh Android users a clear, safe, service-aware way to configure every
current `needs_config` default skill from the Skills page.

The config UI must feel like a product feature, not a raw manifest editor. It
must still preserve OpenClaw's architecture: the app gathers user configuration,
`GatewayProvider.configureAndroidDefaultSkill` submits it, and
`SkillProvisioningService` writes Native `.env` and `openclaw.json` values.
Tool execution remains through the gateway and agent-visible tool layer.

## Current State

The current implementation already has the important backend path:

- `AndroidSkillConfigFormModel` derives env keys and config keys from readiness.
- `AndroidSkillConfigSheet` opens from the Skills page config-gate chips.
- `GatewayProvider.configureAndroidDefaultSkill` calls
  `SkillProvisioningService.auditAndProvision`.
- Env values are written to Native `.env`.
- Dotted config values are written to Native `openclaw.json`.

The gap is user experience and product safety:

- Field labels are raw keys such as `SLACK_BOT_TOKEN`.
- There is no service-specific guidance.
- There are no input kinds such as URL, provider choice, or channel/account
  identifiers.
- There is no metadata model for validation, grouping, or future expansion.
- Secrets are obscured while typed, but the UI does not clearly separate
  credentials from non-secret runtime parameters.

## Product Standard

The GTM-quality shape is a metadata-driven config wizard:

- A generic renderer handles all skills.
- A small catalog gives known skills polished labels, helpers, input kinds,
  validation, and grouping.
- Unknown future keys still render through safe fallback metadata.
- Secrets are never read back into inputs, shown in snackbars, or logged.
- Save always goes through the existing gateway/provisioning path.

This matches the common product pattern used by robust integration settings:
typed forms with service-specific copy, generic storage plumbing, masked
secrets, validation before save, and an immediate status check after save.

## Scope

This phase covers the UI/config wizard. It does not implement new external
service adapters by itself.

The next adapter target after this wizard remains Slack, because Slack needs
both `SLACK_BOT_TOKEN` and `channels.slack`. After Slack, continue with
`mcporter`, `openai-whisper-api`, then smaller service adapters such as
`ordercli` and `sag` if their APIs are sane enough for Android-native support.

## Config Skill Coverage

The first catalog pass covers every current Class B `needs_config` skill:

```text
1password: OP_SERVICE_ACCOUNT_TOKEN
discord: DISCORD_BOT_TOKEN
github: GITHUB_TOKEN
gh-issues: GITHUB_TOKEN
gog: GOG_ACCOUNT_TOKEN
goplaces: GOOGLE_PLACES_API_KEY
mcporter: MCPORTER_ENDPOINT, MCPORTER_TOKEN
notion: NOTION_TOKEN
openai-whisper-api: OPENAI_API_KEY
ordercli: ORDERCLI_API_KEY
sag: SAG_API_KEY
slack: SLACK_BOT_TOKEN, channels.slack
trello: TRELLO_API_KEY, TRELLO_TOKEN
voice-call: VOICE_CALL_PROVIDER, VOICE_CALL_ACCOUNT
```

## Architecture

### Config Field Model

Add a typed field model:

```text
AndroidSkillConfigFieldModel
- key
- target: env or config
- label
- helper
- inputHint
- group
- inputKind
- secret
- required
- enumOptions
- validationPattern
```

Input kinds:

```text
secret
text
url
channelId
accountId
provider
```

The model keeps the existing `envKeys` and `configKeys` API for compatibility,
but also exposes `fields` and grouped views for the sheet.

### Config Catalog

Add a focused catalog beside the form model, either in
`android_skill_config_form_model.dart` if it remains small or in
`android_skill_config_catalog.dart` if the model would become crowded.

The catalog maps skill/key pairs to field metadata. It must also support
key-level fallback so shared credentials such as `GITHUB_TOKEN` can be reused by
`github` and `gh-issues`.

Fallback behavior:

- Uppercase env-like keys become secret credential fields.
- Dotted keys become non-secret config fields.
- Unknown values get readable labels generated from the key.
- Unknown fields remain required when they appear in `requiredConfig`.

### Config Sheet

Update `AndroidSkillConfigSheet` to render model fields instead of raw key
lists.

UI behavior:

- Header shows a friendly service title and runtime gate.
- A notice explains when config can be saved but a pack/binary gate remains.
- Fields are grouped into sections such as `Credentials`, `Workspace`, and
  `Provider`.
- Secret fields are obscured by default and can be revealed only for newly typed
  values.
- URL fields use URL keyboard hints.
- Provider fields use a compact dropdown when known options exist.
- Save button says `Save & Check`.
- After save, readiness is refreshed by the existing provider path.
- Snackbar says whether config was applied or which non-config gate remains.

No visible app text should over-explain OpenClaw internals. The UI should be
direct and operational: what value is needed, what it is used for, and whether
the skill is still blocked after save.

### Save Flow

Save flow remains:

```text
AndroidSkillConfigSheet
  -> GatewayProvider.configureAndroidDefaultSkill
  -> SkillProvisioningService.auditAndProvision
  -> Native .env / Native openclaw.json
  -> gateway config reload when recommended
  -> RPC discovery and health refresh
```

This is important: the UI must not execute tools directly, write config through
ad hoc file code, or bypass the gateway/agent loop.

## Security Requirements

- Do not read existing secret values into text fields.
- Do not display saved secrets.
- Do not log secret values.
- Do not put secret values in snackbars or errors.
- Do not include secret values in docs or test fixtures beyond dummy strings.
- Only newly typed secret text can be revealed by the user.
- Validation errors may mention field labels and keys, never values.

## Field Metadata

Initial field intent:

```text
OP_SERVICE_ACCOUNT_TOKEN
- label: Service account token
- group: Credentials
- kind: secret

DISCORD_BOT_TOKEN
- label: Bot token
- group: Credentials
- kind: secret

GITHUB_TOKEN
- label: GitHub token
- group: Credentials
- kind: secret

GOG_ACCOUNT_TOKEN
- label: Account token
- group: Credentials
- kind: secret

GOOGLE_PLACES_API_KEY
- label: Google Places API key
- group: Credentials
- kind: secret

MCPORTER_ENDPOINT
- label: MCPorter endpoint
- group: Connection
- kind: url

MCPORTER_TOKEN
- label: MCPorter token
- group: Credentials
- kind: secret

NOTION_TOKEN
- label: Integration token
- group: Credentials
- kind: secret

OPENAI_API_KEY
- label: OpenAI API key
- group: Credentials
- kind: secret

ORDERCLI_API_KEY
- label: Order API key
- group: Credentials
- kind: secret

SAG_API_KEY
- label: SAG API key
- group: Credentials
- kind: secret

SLACK_BOT_TOKEN
- label: Bot token
- group: Credentials
- kind: secret

channels.slack
- label: Default Slack channel
- group: Workspace
- kind: channelId

TRELLO_API_KEY
- label: API key
- group: Credentials
- kind: secret

TRELLO_TOKEN
- label: Token
- group: Credentials
- kind: secret

VOICE_CALL_PROVIDER
- label: Provider
- group: Provider
- kind: provider
- options: twilio, telnyx, custom

VOICE_CALL_ACCOUNT
- label: Account identifier
- group: Provider
- kind: accountId
```

## Validation

Validation stays pragmatic and GTM-safe:

- Required fields cannot be blank when the readiness gate reports them missing.
- URL fields must start with `http://` or `https://`.
- Provider dropdown values must be one of the catalog options.
- Channel/account fields trim whitespace but do not over-constrain provider
  formats.
- Secret fields require non-empty input when missing.

The wizard should not attempt to verify whether third-party credentials are
valid during save. Real credential validation belongs to skill execution or a
future explicit "test connection" path, because failed live validation can be
network-dependent, rate-limited, or provider-specific.

## Tests

Add tests before implementation:

- Model test: Slack creates a secret env field and channel config field.
- Model test: MCPorter endpoint is URL and token is secret.
- Model test: Voice Call provider exposes provider options and account field.
- Model test: unknown env/config keys get safe fallback metadata.
- Widget test: known labels render instead of raw-only key UX.
- Widget test: secret fields are obscured by default.
- Widget test: missing required values block save and show labels, not values.
- Widget test: save splits env values and config values correctly.

Keep existing provisioning tests as the proof that actual writes go through the
right service.

## Device Proof

At the next significant milestone:

- Build and install debug APK.
- Use `adb forward tcp:8765 tcp:8765`.
- Open Skills page and configure one representative skill with dummy-safe
  values.
- Confirm save returns through `GatewayProvider`.
- Query `/device/health` and record whether the skill became ready or still has
  a non-config gate.
- Do not claim live provider auth unless valid credentials are intentionally
  supplied.

## Acceptance Criteria

- Every current Class B config skill has an actionable UI path.
- Slack shows both token and channel fields with clear labels.
- Secrets remain masked and are not leaked.
- Save uses existing gateway/provisioning services.
- Tests cover model metadata, sheet behavior, and env/config payload split.
- GTM readiness doc is updated after implementation with proof and remaining
  adapter order.
- A commit is made for the spec and a separate commit is made for the
  implementation round.
