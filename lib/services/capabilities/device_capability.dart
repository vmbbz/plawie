import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

import '../../models/node_frame.dart';
import '../native_bridge.dart';
import '../skill_parity_audit_service.dart';
import 'capability_handler.dart';

class DeviceCapability extends CapabilityHandler {
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
        return _health();
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

  Future<NodeFrame> _health() async {
    try {
      final status = await _status();
      final permissions = await _permissions();
      final parity = await SkillParityAuditService.instance.audit(
        repairNativeFromProot: false,
        cacheTtl: const Duration(seconds: 15),
      );
      return NodeFrame.response('', payload: {
        'status': status.payload,
        'permissions': permissions.payload,
        'skillReadiness': parity.readinessCounts,
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
