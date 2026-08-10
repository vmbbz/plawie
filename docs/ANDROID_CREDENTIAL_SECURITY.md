# Android Credential Security

Status: implemented and device-audited on 2026-08-10.

## Security boundary

An APK is a public artifact. Any string, asset, native constant, Dart define,
URL, or certificate packaged into it must be treated as readable by an
attacker. Obfuscation can increase reverse-engineering cost, but it cannot turn
a client-side value into a secret.

Plawie therefore separates values into these classes:

| Class | Examples | APK policy | Runtime policy |
| --- | --- | --- | --- |
| Public client metadata | Reown project ID, dapp origin, chain IDs, contract addresses, public RPC origins | May be packaged | Restrict at the provider dashboard where supported |
| Public verification material | Dependency-pack Ed25519 public key and key ID | Must be packaged | Verification only; signing private key never enters the repository or APK |
| User BYOK credentials | OpenRouter, GIPHY, OpenAI, Gemini, skill tokens | Never packaged | Collected at runtime; temporary setup handoff uses secure storage |
| Local runtime credentials | Gateway token, pairing tokens, Ed25519 device private keys | Never packaged | Android-Keystore-backed secure storage |
| Gateway-consumed provider state | `.env`, `auth-profiles.json`, `openclaw.json` | Never packaged with user values | App-private internal storage, mode `0600`, excluded from backup and D2D transfer |
| Wallet private keys | Plawie EVM account | Never enters Dart assets or ordinary logs | Android-owned Keystore encryption and device-authenticated signing/export surfaces |
| Server credentials | Paid RPC keys, partner API keys, signing keys, webhook secrets | Never packaged | Backend/CI secret manager only |

The upstream OpenClaw Gateway must be able to read its provider credential. For
that reason, the active credential is materialized inside the app-private
Gateway state after installation. This is not an APK secret. It is protected by
Android app sandboxing, `0600` file modes, backup exclusions, non-debuggable
release builds, and log redaction. A rooted or fully compromised device remains
outside this protection boundary; users should revoke affected provider keys.

## Implemented controls

1. `RuntimeCredentialStore` migrates Gateway tokens, pairing tokens, and both
   Ed25519 device private keys out of plaintext SharedPreferences. Migration is
   verified before the legacy preference is removed.
2. Provider setup stores pending API keys in `flutter_secure_storage` behind a
   random one-time reference and deletes the temporary secret after setup.
3. Android backup is disabled. Explicit Android 11 backup rules and Android 12+
   cloud/D2D extraction rules exclude all app state, including secure-storage
   ciphertext and Gateway files.
4. Gateway credential files are created in app-private storage and observed as
   mode `0600` on the physical test device.
5. Native PRoot and terminal exception logs never print command text. Gateway
   log streams redact bearer tokens, API-key fields, token query parameters,
   and common provider-key prefixes.
6. Release builds cannot use Android's debug signing key. Build packaging fails
   unless all four upload-keystore environment values are present.
7. Every supported Android build runs
   `scripts/audit_android_artifact_secrets.ps1` after packaging. The scanner
   checks compiled Dart/Kotlin payloads and text assets for credential-shaped
   values and exact sensitive build-environment values while reporting only
   redacted fingerprints.
8. `ROBINHOOD_RPC_URL`, when supplied, must be a credential-free public HTTPS
   origin. A paid/private RPC URL cannot be protected in an APK and must be
   mediated by a backend instead.

## Current binary evidence

The installed debug APK and the current branch debug APK were compared against
the live device's GIPHY key, OpenRouter key, Gateway token, pairing tokens, and
device private keys. None occurred in either APK. The only matched configured
value was the Reown project ID, which Reown defines as client configuration.

The same live credentials were compared against approximately 44 MB of retained
Android Logcat data; no exact credential value was found. Values and raw matches
were never printed during the audit.

Debug APKs remain intentionally debuggable and must never be distributed as a
production release. An authorized ADB host can use `run-as` against a debug app
and inspect app-private Gateway files. Store/production artifacts must be
release-signed and non-debuggable.

## Required external controls

- Configure the Reown project allowlist for exact origin
  `https://plawie.app` and Android application ID `com.openclaw.plawie`.
  Reown states that project IDs are client inputs and recommends origin/app-ID
  allowlisting to prevent unauthorized use.
- Keep provider account limits, spend limits, key rotation, and revocation
  enabled. BYOK limits the blast radius to the user's own provider account.
- Store the Android upload keystore and its passwords in a CI secret manager or
  an encrypted local release vault. Never commit them or pass them as Dart
  defines.
- Use Play App Signing for store distribution. Retain the upload-key recovery
  material separately from the build machine.
- If Plawie later supplies shared provider credits, place the provider secret
  behind a Plawie backend with authenticated users, rate limits, quotas, abuse
  monitoring, and server-side key rotation. Do not compile a shared key.

## Release invocation

Set the following values in the protected build environment:

- `PLAWIE_UPLOAD_STORE_FILE`
- `PLAWIE_UPLOAD_STORE_PASSWORD`
- `PLAWIE_UPLOAD_KEY_ALIAS`
- `PLAWIE_UPLOAD_KEY_PASSWORD`

Then use:

```powershell
.\scripts\build_plawie_android.ps1 -Mode release -Bundle
```

The script validates signing, validates any public RPC origin, builds the AAB,
and runs the redacted compiled-artifact secret audit. A failed audit blocks the
release.

## References

- Android Keystore: https://developer.android.com/privacy-and-security/keystore
- Android backup security: https://developer.android.com/privacy-and-security/risks/backup-best-practices
- Android debuggable risk: https://developer.android.com/privacy-and-security/risks/android-debuggable
- Android app signing: https://developer.android.com/studio/publish/app-signing
- Reown Relay project ID and allowlist: https://docs.reown.com/cloud/relay
- Flutter secure storage Android guidance: https://pub.dev/packages/flutter_secure_storage
