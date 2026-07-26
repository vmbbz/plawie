import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

import '../../models/node_frame.dart';
import '../android_skill_readiness_service.dart';
import '../native_bridge.dart';
import '../skill_parity_audit_service.dart';
import '../skill_provisioning_service.dart';
import 'capability_handler.dart';

class DeviceCapability extends CapabilityHandler {
  static const Duration _healthCacheTtl = Duration(seconds: 15);
  static NodeFrame? _cachedHealth;
  static DateTime? _cachedHealthAt;
  static Future<NodeFrame>? _healthInFlight;

  @override
  String get name => 'device';

  @override
  List<String> get commands => ['status', 'health', 'permissions', 'info'];

  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    switch (command) {
      case 'device.status':
      case 'device.info':
        return _status();
      case 'device.health':
        return _health(
          forceRefresh: _isTruthy(params['refresh']) ||
              _isTruthy(params['forceRefresh']) ||
              _isTruthy(params['fresh']),
        );
      case 'device.permissions':
        return _permissions();
      default:
        return NodeFrame.response('', error: {
          'code': 'UNKNOWN_COMMAND',
          'message': 'Unknown device command: $command',
        });
    }
  }

  Future<NodeFrame> _status() async {
    try {
      final filesDir = await NativeBridge.getFilesDir();
      final stat = await Directory(filesDir).stat();
      return NodeFrame.response('', payload: {
        'deviceId': await NativeBridge.getDeviceId(),
        'brand': await NativeBridge.getDeviceBrand(),
        'model': await NativeBridge.getDeviceModel(),
        'appVersion': await NativeBridge.getAppVersion(),
        'arch': await NativeBridge.getArch(),
        'totalMemoryMb': await NativeBridge.getTotalMemoryMb(),
        'batteryLevel': await NativeBridge.getBatteryLevel(),
        'isCharging': await NativeBridge.isCharging(),
        'filesDir': filesDir,
        'filesDirModified': stat.modified.toIso8601String(),
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'DEVICE_STATUS_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _health({bool forceRefresh = false}) {
    final now = DateTime.now();
    final cached = _cachedHealth;
    final cachedAt = _cachedHealthAt;
    if (!forceRefresh &&
        cached != null &&
        cachedAt != null &&
        now.difference(cachedAt) < _healthCacheTtl) {
      return Future.value(_withHealthCacheMetadata(
        cached,
        cachedAt: cachedAt,
        cacheHit: true,
      ));
    }

    final pending = _healthInFlight;
    if (!forceRefresh && pending != null) return pending;

    final future = _computeHealth();
    if (!forceRefresh) _healthInFlight = future;
    return future.then((frame) {
      if (frame.isOk) {
        _cachedHealth = frame;
        _cachedHealthAt = DateTime.now();
      }
      return _withHealthCacheMetadata(
        frame,
        cachedAt: _cachedHealthAt,
        cacheHit: false,
      );
    }).whenComplete(() {
      if (identical(_healthInFlight, future)) _healthInFlight = null;
    });
  }

  Future<NodeFrame> _computeHealth() async {
    try {
      final status = await _status();
      final permissions = await _permissions();
      final parity = await SkillParityAuditService.instance.audit(
        repairNativeFromProot: false,
        cacheTtl: const Duration(seconds: 15),
      );
      final provisioning =
          await SkillProvisioningService.instance.planSnapshot(parity);
      final androidReadiness = AndroidSkillReadinessService.instance.summarize(
        snapshot: parity,
        provisioning: provisioning,
      );
      return NodeFrame.response('', payload: {
        'status': status.payload,
        'permissions': permissions.payload,
        'androidDefaultReadiness': androidReadiness.toHealthJson(),
        'skillReadiness': parity.readinessCounts,
        'skillProvisioning': provisioning.toHealthJson(maxResults: 12),
        'skillGateCount': parity.gates.length,
        'toolsAllowParity': parity.toolsAllowParity,
        'nativeSkillCount': parity.nativeSkillCount,
        'prootSkillCount': parity.prootSkillCount,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'DEVICE_HEALTH_ERROR',
        'message': '$e',
      });
    }
  }

  static bool _isTruthy(Object? value) {
    if (value == true) return true;
    final normalized = value?.toString().trim().toLowerCase();
    return normalized == '1' ||
        normalized == 'true' ||
        normalized == 'yes' ||
        normalized == 'on';
  }

  static NodeFrame _withHealthCacheMetadata(
    NodeFrame frame, {
    required DateTime? cachedAt,
    required bool cacheHit,
  }) {
    final payload = frame.payload;
    if (payload == null) return frame;
    return NodeFrame(
      type: frame.type,
      id: frame.id,
      method: frame.method,
      params: frame.params,
      ok: frame.ok,
      payload: <String, dynamic>{
        ...payload,
        'healthCache': <String, dynamic>{
          'hit': cacheHit,
          if (cachedAt != null) 'generatedAt': cachedAt.toIso8601String(),
          if (cachedAt != null)
            'ageMs': DateTime.now().difference(cachedAt).inMilliseconds,
          'ttlMs': _healthCacheTtl.inMilliseconds,
        },
      },
      error: frame.error,
      event: frame.event,
    );
  }

  Future<NodeFrame> _permissions() async {
    try {
      Future<String> state(Permission permission) async {
        final status = await permission.status;
        return status.toString().split('.').last;
      }

      return NodeFrame.response('', payload: {
        'camera': await state(Permission.camera),
        'location': await state(Permission.location),
        'microphone': await state(Permission.microphone),
        'notification': await state(Permission.notification),
        'storage': await NativeBridge.checkStoragePermission(),
        'batteryOptimized': await NativeBridge.isBatteryOptimized(),
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'DEVICE_PERMISSIONS_ERROR',
        'message': '$e',
      });
    }
  }
}
