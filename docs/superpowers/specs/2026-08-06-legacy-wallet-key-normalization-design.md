# Legacy Base Wallet Key Normalization Design

Date: 2026-08-06

Status: approved direction; implementation pending

## Problem

The historical Dart wallet creator persisted `base_private_key` using
Web3dart's `EthPrivateKey.createRandom()` byte representation. That version
used Pointy Castle's signed, minimal ASN.1 integer encoding. A valid 256-bit
secp256k1 scalar could therefore be serialized as:

- 33 bytes with a leading zero sign byte;
- 32 bytes in the common unsigned representation; or
- fewer than 32 bytes when the scalar began with one or more zero bytes.

The current Base service can parse the stored scalar and derive the existing
wallet address, but migration rejects every representation except exactly 64
hexadecimal characters. On the attached device this leaves the valid legacy
wallet `0xab29...B434` visible but impossible to secure.

The failure occurs in Dart before the Android Keystore import method runs. No
native envelope exists, and the legacy FlutterSecureStorage value remains the
only wallet-key record.

## Approaches considered

### 1. Delete the legacy record and create a new wallet

This is operationally simple and would work for the currently unused wallet,
but it is unsafe product behavior. A future user could have funds at the legacy
address. The app must not make destructive replacement the normal response to
a compatible historical encoding.

### 2. Accept any string Web3dart can parse

This maximizes compatibility but makes the migration boundary too permissive.
It could accept unintended formatting or values outside the historical storage
contract and would make later compatibility behavior difficult to audit.

### 3. Strict historical normalization with address continuity

This is the selected approach. Accept only even-length hexadecimal payloads
that can represent at most 33 bytes. A 33-byte payload is accepted only when
its first byte is the historical zero sign byte. Shorter payloads are left
padded to 32 bytes. The normalized scalar must be non-zero, within the
secp256k1 private-key range, and derive the same address that the app displayed
before migration.

## Architecture

Add a small pure Dart legacy-key normalizer next to the Base wallet service.
It owns no storage and performs no I/O. Its only responsibility is converting
the historical serialized form into a canonical 32-byte private key while
enforcing the compatibility boundary.

`BaseService.migrateLegacyWallet()` remains the transaction coordinator:

1. Read the legacy key from FlutterSecureStorage.
2. Normalize it through the pure compatibility component.
3. Derive the normalized key's public address and compare it with the address
   already derived during initialization.
4. Pass exactly 32 bytes to Android's bounded secure-wallet import method.
5. Validate that Android reports a verified envelope with the same address.
6. Apply the native wallet status.
7. Delete `base_private_key` only after all identity checks pass.
8. Clear the temporary key bytes in a `finally` block.

Android remains the long-term owner of the encrypted key, authentication, and
signing. No new generic signing capability is introduced, and no private-key
material is logged or returned from Android after migration.

## Compatibility boundary

Accepted inputs:

- optional historical lowercase `0x` prefix;
- an even number of hexadecimal characters;
- 2 through 64 hexadecimal characters, normalized by left padding;
- exactly 66 hexadecimal characters only when they begin with `00`.

Rejected inputs:

- empty, odd-length, or non-hexadecimal values;
- values longer than 33 bytes;
- a 33-byte value without the zero sign byte;
- zero or a scalar greater than or equal to the secp256k1 curve order;
- any normalized key whose address differs from the initialized legacy
  address;
- any native import result whose address differs from the normalized address.

## Failure and recovery behavior

Every failure is fail-closed. The legacy record is retained and the UI keeps
showing the migration action with a concise error. Cancellation of Android
authentication also retains the legacy record. If Android writes an envelope
but the returned identity fails continuity validation, the legacy record is
still retained for recovery and the inconsistency is surfaced instead of
silently choosing one identity.

The app must not display Create Wallet while a legacy record remains. Removal
of a legacy wallet stays an explicit destructive user action and is outside
this compatibility fix.

## Testing

The red-green regression suite will cover:

- canonical 32-byte keys;
- the historical 33-byte leading-zero representation that reproduces the
  attached-device failure;
- short historical representations normalized to 32 bytes;
- rejection of non-zero 33-byte prefixes, odd lengths, non-hex input, zero,
  and out-of-range scalars;
- preservation of the derived wallet address after normalization;
- source/transaction contracts proving the legacy record is deleted only
  after native status and address validation.

Device acceptance requires one in-place APK update without clearing data,
successful Android authentication, creation of
`no_backup/base_evm_wallet_v1.json`, disappearance of the legacy migration
card, preservation of `0xab29...B434`, and zero private-key output in logs.
