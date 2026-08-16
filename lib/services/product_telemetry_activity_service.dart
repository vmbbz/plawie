import 'dart:async';

import 'package:flutter/widgets.dart';

import 'product_telemetry_event.dart';
import 'product_telemetry_service.dart';

typedef ProductTelemetryTimerFactory = Timer Function(
  Duration duration,
  VoidCallback callback, {
  required bool periodic,
});

Timer _createTelemetryTimer(
  Duration duration,
  VoidCallback callback, {
  required bool periodic,
}) {
  if (periodic) {
    return Timer.periodic(duration, (_) => callback());
  }
  return Timer(duration, callback);
}

/// Records consented visible app activity without treating background services
/// or a live Gateway process as user activity.
///
/// Android can briefly pause Flutter for permission surfaces and while entering
/// PiP. A short grace period keeps those transitions inside one activity
/// session. A true background transition cancels the bounded heartbeat timer.
class ProductTelemetryActivityService with WidgetsBindingObserver {
  ProductTelemetryActivityService({
    required ProductTelemetryService telemetry,
    ProductTelemetryTimerFactory timerFactory = _createTelemetryTimer,
    bool observeBinding = true,
  })  : _telemetry = telemetry,
        _timerFactory = timerFactory,
        _observeBinding = observeBinding;

  static final ProductTelemetryActivityService instance =
      ProductTelemetryActivityService(
    telemetry: ProductTelemetryService.instance,
  );

  static const Duration heartbeatInterval = Duration(minutes: 5);
  static const Duration backgroundGrace = Duration(seconds: 2);

  final ProductTelemetryService _telemetry;
  final ProductTelemetryTimerFactory _timerFactory;
  final bool _observeBinding;

  AppLifecycleState? _lifecycleState;
  Timer? _heartbeatTimer;
  Timer? _backgroundGraceTimer;
  bool _started = false;
  bool _surfaceActive = false;
  bool _measurementSessionActive = false;
  bool _pictureInPictureActive = false;

  bool get isSurfaceActive => _surfaceActive;
  bool get isPictureInPictureActive => _pictureInPictureActive;

  void start() {
    if (_started) return;
    _started = true;
    _telemetry.addListener(_handleTelemetryStateChanged);
    if (_observeBinding) {
      WidgetsBinding.instance.addObserver(this);
      final state = WidgetsBinding.instance.lifecycleState;
      if (state != null) unawaited(updateLifecycleState(state));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(updateLifecycleState(state));
  }

  @visibleForTesting
  Future<void> updateLifecycleState(AppLifecycleState state) async {
    _lifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      _backgroundGraceTimer?.cancel();
      _backgroundGraceTimer = null;
      await _setSurfaceActive(true);
      return;
    }

    if (_pictureInPictureActive) return;
    if (state == AppLifecycleState.detached) {
      _backgroundGraceTimer?.cancel();
      _backgroundGraceTimer = null;
      await _setSurfaceActive(false);
      return;
    }
    _scheduleBackgroundTransition();
  }

  Future<void> setPictureInPictureActive(bool active) async {
    if (_pictureInPictureActive == active) return;
    _pictureInPictureActive = active;
    if (active) {
      _backgroundGraceTimer?.cancel();
      _backgroundGraceTimer = null;
      await _setSurfaceActive(true);
      return;
    }
    if (_lifecycleState == AppLifecycleState.resumed) return;
    _scheduleBackgroundTransition();
  }

  void _scheduleBackgroundTransition() {
    if (_backgroundGraceTimer?.isActive == true) return;
    _backgroundGraceTimer = _timerFactory(
      backgroundGrace,
      () {
        _backgroundGraceTimer = null;
        if (_pictureInPictureActive ||
            _lifecycleState == AppLifecycleState.resumed) {
          return;
        }
        unawaited(_setSurfaceActive(false));
      },
      periodic: false,
    );
  }

  Future<void> _setSurfaceActive(bool active) async {
    if (_surfaceActive != active) {
      _surfaceActive = active;
      if (!active) {
        _endMeasurementSession();
        return;
      }
    }
    await _syncMeasurementSession();
  }

  void _handleTelemetryStateChanged() {
    unawaited(_syncMeasurementSession());
  }

  bool get _canMeasure =>
      _telemetry.consentGranted && _telemetry.analyticsConfigured;

  Future<void> _syncMeasurementSession() async {
    if (!_started || !_surfaceActive || !_canMeasure) {
      _endMeasurementSession();
      return;
    }
    if (_measurementSessionActive) return;

    _measurementSessionActive = true;
    await _telemetry.record(
      ProductTelemetryEventName.appForegrounded,
      properties: <String, Object?>{
        'source': 'app_lifecycle',
        'surface': _currentSurface,
      },
    );
    if (!_measurementSessionActive || !_surfaceActive || !_canMeasure) return;

    await _recordHeartbeat();
    if (!_measurementSessionActive || !_surfaceActive || !_canMeasure) return;
    _heartbeatTimer ??= _timerFactory(
      heartbeatInterval,
      () => unawaited(_recordHeartbeat()),
      periodic: true,
    );
  }

  Future<void> _recordHeartbeat() async {
    if (!_measurementSessionActive || !_surfaceActive || !_canMeasure) return;
    await _telemetry.record(
      ProductTelemetryEventName.appActiveHeartbeat,
      properties: <String, Object?>{
        'source': 'app_lifecycle',
        'surface': _currentSurface,
      },
    );
  }

  String get _currentSurface => _pictureInPictureActive ? 'pip' : 'foreground';

  void _endMeasurementSession() {
    _measurementSessionActive = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  @visibleForTesting
  void dispose() {
    if (!_started) return;
    _started = false;
    _telemetry.removeListener(_handleTelemetryStateChanged);
    if (_observeBinding) WidgetsBinding.instance.removeObserver(this);
    _backgroundGraceTimer?.cancel();
    _backgroundGraceTimer = null;
    _endMeasurementSession();
  }
}
