# Base Wallet Security and Recovery

## Scope

Plawie's Base wallet is an app-owned EVM wallet for Base Mainnet. It is used for
explicit user transfers and bounded AI-provider payments. It is not a generic
background signer: every private-key unwrap requires an Android system
authentication prompt, and payment construction remains constrained by native
policy before signing.

## Key storage and persistence

- The secp256k1 private key is generated in the Android process.
- Because Android Keystore does not expose secp256k1 signing keys, the private
  key is encrypted with AES-256-GCM under a non-exportable Android Keystore key.
- The encrypted envelope is stored atomically as
  `no_backup/base_evm_wallet_v1.json`. Ordinary APK upgrades with the same
  application ID and signing identity preserve both app data and the Keystore
  alias.
- Clearing app data or uninstalling the app intentionally removes the envelope
  and its Keystore key. Users must export and securely retain a private-key
  backup before either action if the wallet holds funds.
- A lock-screen or biometric-security change may invalidate the Keystore key.
  The encrypted envelope cannot be recovered without the exported private key.

The private key is only shown through the authenticated backup dialog. Ordinary
transaction and x402 flows never return key material to Dart.

## Android authentication policy

Android exposes two different authenticator constant families:

| Consumer | Required constants |
| --- | --- |
| `BiometricManager` and `BiometricPrompt` | `BiometricManager.Authenticators.*` |
| `KeyGenParameterSpec` | `KeyProperties.AUTH_*` |

The numeric masks are not interchangeable. `WalletAuthenticatorPolicy` owns
both masks so prompt/status calls cannot silently reuse the Keystore mask. On
Android 11 and newer, the wallet accepts a Class 3 biometric or secure device
credential. Android 10 requires an enrolled Class 3 biometric.

Capability checks fail closed. If an OEM biometric service rejects a policy,
wallet status reports authentication as unavailable and logs the native error;
it does not crash initialization or weaken the signing policy.

## Creation and signing lifecycle

1. Classify envelope, Keystore alias, authenticator, invalidation, and busy
   state without decrypting or prompting. Create/import is allowed only from
   the explicit `absent` state.
2. Start a transaction that records whether the known envelope and alias
   existed before this attempt.
3. Create the authenticated AES envelope key in Android Keystore and ask
   Android to authenticate the user for the exact encryption operation.
4. Encrypt the new EVM key, atomically persist the envelope, reopen it, and
   compare version, address, IV, and ciphertext byte-for-byte.
5. Re-derive the address from the still-in-memory key, clear those bytes, then
   perform a second authenticated decrypt and verify the recovered address.
6. On each later operation, authenticate again, decrypt in Android memory,
   validate the bounded request, sign, self-verify where applicable, and clear
   private-key bytes.

Cancellation or failure before a verified atomic commit removes only an
envelope or Keystore alias created by that attempt. It never removes a
pre-existing alias or envelope. Cancelling the second verification prompt
retains the atomically verified wallet and returns
`WALLET_CREATED_VERIFICATION_PENDING`; a cryptographic identity mismatch
removes that newly created attempt.

## Recovery states

| State | User-visible behavior | Recovery |
| --- | --- | --- |
| `absent` | Wallet can be created or imported | Create a wallet or import a backup |
| `healthy` | Wallet address and security level are available | Authenticate for operations |
| `authenticationUnavailable` | Creation and signing fail closed | Configure a secure lock or Class 3 biometric |
| `envelopeCorrupt` | The damaged envelope is never treated as absent | Restore from backup or use explicit destructive recovery |
| `keystoreKeyMissing` | Address remains known but signing/export is blocked | Restore from backup or use explicit destructive recovery |
| `keystoreKeyInvalidated` | Signing and export are blocked | Restore from backup or use explicit destructive recovery |
| `orphanedKeystoreAlias` | Ordinary creation/import remains blocked | Explicitly remove only the orphaned protection record |
| `operationBusy` | Wallet actions are temporarily disabled | Wait for the active authentication to finish |

The compatibility fields remain available to older Dart callers, but product
decisions must use the stable `state` and `errorCode` fields. In particular,
neither a damaged envelope nor an unknown Keystore probe is inferred as an
ordinary missing wallet.

## 2026-08-06 device incident

On a Samsung SM-A556E running Android 14, wallet creation failed with
`WALLET_SECURITY_ERROR: Invalid authenticator configuration`. Device logs showed
the same exception in the Base-service status call. The app had passed
`KeyProperties.AUTH_*` to `BiometricManager` and `BiometricPrompt`; no wallet
envelope had been written. The fix separates the masks, adds regression tests,
and makes status fail closed on OEM `SecurityException` responses.

## 2026-08-06 legacy migration incident

The same device retained a historical FlutterSecureStorage wallet whose public
address could be derived, but `Secure existing wallet` failed in Dart with
`FormatException: Legacy wallet key is invalid.` Android authentication and
Keystore import were never reached, and no native envelope had been written.

The historical Web3dart creator serialized its scalar through a signed,
minimal ASN.1 integer representation. Valid secp256k1 keys could therefore be
33 bytes with a zero sign prefix or shorter than 32 bytes when high-order bytes
were zero. The migration incorrectly accepted only exactly 32 serialized
bytes.

Legacy migration now accepts only those bounded historical forms, normalizes
them to exactly 32 bytes, validates the secp256k1 range, and proves the derived
address is unchanged. Android must then report the same address from the new
envelope before Dart removes the legacy record. Authentication cancellation,
invalid input, or any identity mismatch retains the legacy record. No key,
ciphertext, or signature is written to logs.

## Mainnet payment boundary

Base Mainnet does not remove the approval boundary. Plawie must show the asset,
amount, destination, network, provider, and estimated network fee before asking
Android to authenticate. Agent-initiated payment intents may prepare this
review, but they cannot authenticate, sign, or broadcast without the human.
