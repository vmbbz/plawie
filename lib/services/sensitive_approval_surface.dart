import 'native_bridge.dart';

typedef SensitiveUiSetter = Future<void> Function(bool visible);

/// One app-wide lease for screen-capture-protected approval surfaces.
///
/// Payment and Agent Wallet brokers are intentionally separate, but they must
/// never display competing approval dialogs or disable FLAG_SECURE while the
/// other operation is still under review.
class SensitiveApprovalSurface {
  SensitiveApprovalSurface({SensitiveUiSetter? setVisible})
      : _setVisible = setVisible ?? NativeBridge.setSensitiveUiVisible;

  static final SensitiveApprovalSurface instance = SensitiveApprovalSurface();

  final SensitiveUiSetter _setVisible;
  String? _owner;

  String? get activeOwner => _owner;

  Future<bool> acquire(String owner) async {
    final normalized = owner.trim();
    if (normalized.isEmpty || normalized.length > 180) {
      throw const FormatException('Sensitive approval owner is invalid.');
    }
    if (_owner != null) return false;
    _owner = normalized;
    try {
      await _setVisible(true);
      return true;
    } catch (_) {
      if (_owner == normalized) _owner = null;
      rethrow;
    }
  }

  Future<void> release(String owner) async {
    if (_owner != owner) return;
    try {
      await _setVisible(false);
    } finally {
      if (_owner == owner) _owner = null;
    }
  }
}
