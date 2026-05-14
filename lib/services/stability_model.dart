class StabilityModel {
  /// PRoot system-call translation overhead on Android ARM (observed 2x–4x, median ~2.5x).
  static const double phi = 2.5;

  /// Milliseconds to wait for a gateway pairing request to become visible after node connect.
  /// Used by the proactive approval check in BootstrapService.
  static final int injectDelay = (1500 * phi).toInt(); // ~3.75s

  /// Milliseconds for the gateway to finish processing an openclaw reload (SIGUSR1).
  static final int reloadGrace = (2000 * phi).toInt(); // ~5.0s

  /// Milliseconds for a fresh WebSocket handshake to complete after a reload.
  static final int wsHandshake = (2000 * phi).toInt(); // ~5.0s

  /// Total cooldown after a 1008 pairing-required event: reload grace + WS handshake.
  /// Used by NodeService._handleNodePairingRequired() before reconnecting.
  static Duration get pairingHealDuration => Duration(milliseconds: reloadGrace + wsHandshake);
}
