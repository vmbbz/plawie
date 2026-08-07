# Wallet Security and Recovery

## Scope

Plawie's Wallet is one app-owned EVM identity shared across Base Mainnet, Base
Sepolia, and Robinhood Chain Mainnet. It is used for explicit user transfers
and bounded AI-provider payments. Selecting a network never creates or copies
a second key. It is not a generic background signer: every private-key unwrap
requires an Android system authentication prompt, and transaction construction
remains constrained by native policy before signing.

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

## Network and asset policy

| Network | Chain ID | Ordinary sends | Provider x402 |
| --- | ---: | --- | --- |
| Base Mainnet | 8453 | ETH and native Base USDC | Exact native Base USDC only |
| Robinhood Chain | 4663 | ETH and official USDG only | Disabled |
| Base Sepolia | 84532 | ETH and test USDC | Disabled |

Robinhood USDG is the exact published contract
`0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168`; it is never labelled as USDC or
accepted as a provider payment. Robinhood ordinary signing permits only a
positive native ETH transfer with empty calldata or the exact USDG contract's
ERC-20 `transfer` call. Arbitrary contract calls and bridge calldata are
rejected by Android before key unwrap.

Release builds require an HTTPS `ROBINHOOD_RPC_URL` for internal Robinhood
sends and production RPC reliability. Debug/internal builds may use
Robinhood's documented rate-limited public RPC. A release without the define
can still attempt public reads but disables internal Robinhood sends without
affecting Base, wallet recovery, external funding, or the native Gateway.

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

### Bounded Venice identity signing

Venice wallet authentication uses a dedicated native SIWE operation; it does
not add `personal_sign`, arbitrary typed-data signing, or a caller-controlled
domain or statement. Native policy builds `Sign in to Venice AI` itself and
accepts only these exact HTTPS resources:

- `GET /api/v1/models`;
- `POST /api/v1/chat/completions`;
- `GET /api/v1/x402/balance/{the same secure wallet address}`.

`POST /api/v1/responses` remains disabled until its proxy contract is enabled
and tested. Every inference authorization uses a fresh alphanumeric nonce and
a lifetime of at most five minutes, verifies the returned payer and exact SIWE
message in Dart, and is never cached. The existing balance-read compatibility
path may cache its exact identity header in memory for up to five minutes.

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

### Bounded recovery contract

Recovery is exposed through two dedicated native operations rather than a
generic reset command:

- `recoverOrphanedSecureEvmAlias` is accepted only in
  `orphanedKeystoreAlias`. An Android-owned warning must be confirmed, the
  state is revalidated, and only the known Plawie Keystore alias is removed.
- `removeDamagedSecureEvmWallet` is accepted only in `envelopeCorrupt`,
  `keystoreKeyMissing`, or `keystoreKeyInvalidated`. Android shows the
  destructive warning. If a usable alias remains, a system authentication
  prompt must succeed before the known envelope and alias are removed. A
  missing or permanently invalidated key cannot be authenticated, so explicit
  warning confirmation is the final available approval boundary.

Both operations are exactly-once, report stable cancellation/error codes, and
clear the busy flag before returning the freshly classified status. They never
run through create/import and cannot remove a healthy wallet. Ordinary healthy
wallet removal still authenticates by decrypting the existing envelope first.

The Wallet page maps each state to its allowed actions. Create/import are
shown only for `absent`; damaged states offer restore/removal; orphan state
offers alias cleanup; busy, unknown, and authentication-unavailable states are
read-only. The agent skill page can display wallet capability and open the
human wallet manager, but it cannot invoke creation, import, backup, or recovery
as an agent action.

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

## Canonical interactive payment approval

`PaidProviderApprovalHost` is the single app-scoped owner of paid-provider
foreground state and BlockRun approval dialogs. A request fails closed unless
the app is resumed, the host is subscribed, and no other approval is active.
The non-dismissible dialog shows the exact USDC amount, provider, model,
network, purpose, resource host, expiry, full recipient, and redacted request
fingerprint. It never shows or stores the prompt, tool payload, signature, or
private key.

Backgrounding completes the broker decision as `appBackgrounded`, removes the
owned dialog route, invalidates Venice foreground-turn authorization, and never
calls the signer. Approval completes only the one process-local broker intent;
the Android wallet then independently requires strong biometric or device
credential authentication and revalidates the bounded EIP-3009 payload.

While the dialog is visible, Android applies `FLAG_SECURE`, filters touches from
obscuring windows, and on Android 12 or newer hides non-system overlays. If that
secure surface cannot be enabled, the dialog is not shown and the payment is
cancelled. The app clears the temporary window policy after the dialog closes.

## Funding before a provider top-up

AI-provider settlement remains Base Mainnet native USDC. If a fresh provider
challenge exceeds the exact refreshed Base balance, Plawie rejects that
challenge before opening the funding modal. The modal may offer Robinhood ETH
or official USDG only when live LI.FI/Relay capability discovery confirms the
route to Base USDC. It warns users to retain ETH for source-chain gas.

A completed bridge receipt is not payment approval. Plawie switches back to
Base, fails closed if the USDC balance cannot be freshly read, verifies that
the delivered balance is sufficient, obtains a new provider challenge, and
then shows a separate exact x402 approval followed by Android authentication.
Closing or backgrounding the modal, partial delivery, refund, expiry, unknown
submission state, or an increased fresh challenge stops the provider payment.
