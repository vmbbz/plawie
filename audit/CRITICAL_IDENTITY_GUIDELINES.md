# Critical Identity & Handshake Guidelines

## ⚠️ The "Identity Mismatch" Trap (1008)

The OpenClaw gateway enforces a strict cryptographic link between a device's identity and its public key. Failing to adhere to these rules results in an immediate WebSocket disconnect with code `1008` and the reason `device identity mismatch`.

### 1. The ID Format (Must be Hex)
**RULE**: The `deviceId` MUST be the **Hex SHA-256 hash** of the raw 32-byte Ed25519 public key.
*   **CORRECT**: `hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()`
*   **INCORRECT**: Using Base64Url or any other encoding for the `deviceId`.

### 2. No Suffixes Allowed
**RULE**: The `deviceId` sent in the `device.id` field of the `connect` frame must be the **exact** result of the hash. Do NOT append logical suffixes like `:node` or `:operator`.
*   **Why?**: The gateway performs `hash(publicKey) == claimedDeviceId`. If you send `ABC:node`, the check fails because `ABC != ABC:node`.
*   **How to Isolate Sessions**: To run multiple sessions (e.g., UI and Background Node) from one device, use **Isolated Key Storage**. Give the Node its own private key so it has its own unique `deviceId`.

### 3. Key Storage Isolation
**RULE**: Always use dedicated SharedPreferences/storage keys for background services.
*   **Operator Keys**: `openclaw_device_ed25519_private`, `openclaw_device_id`
*   **Node Keys**: `openclaw_node_ed25519_private`, `openclaw_node_id`
*   **Why?**: If they share keys, they share nonces. Concurrent connections will cause `nonce mismatch` errors as they overwrite each other's state in the gateway.

### 4. Token Cache Synchronization
**RULE**: When the gateway reloads or rotates its token, all services must invalidate their cached tokens.
*   **Implementation**: Use a Singleton pattern for the Node service and call `clearCachedToken()` whenever `GatewayService` restarts. This ensures the Node re-reads the fresh token from `openclaw.json`.

---
*Last Updated: May 7, 2026*
