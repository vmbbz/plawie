import 'dart:async';

import 'package:permission_handler/permission_handler.dart';
import '../../models/node_frame.dart';
import 'camera_hardware_coordinator.dart';
import 'capability_handler.dart';

class FlashCapability extends CapabilityHandler {
  final CameraHardwareCoordinator _hardware =
      CameraHardwareCoordinator.instance;

  @override
  String get name => 'flash';

  @override
  List<String> get commands => ['on', 'off', 'toggle', 'status'];

  @override
  List<Permission> get requiredPermissions => [Permission.camera];

  @override
  Future<bool> checkPermission() async {
    return await Permission.camera.isGranted;
  }

  @override
  Future<bool> requestPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    switch (command) {
      case 'flash.on':
        return _setTorch(true);
      case 'flash.off':
        return _setTorch(false);
      case 'flash.toggle':
        return _setTorch(!_hardware.torchOn);
      case 'flash.status':
        return NodeFrame.response('', payload: {'on': _hardware.torchOn});
      default:
        return NodeFrame.response('', error: {
          'code': 'UNKNOWN_COMMAND',
          'message': 'Unknown flash command: $command',
        });
    }
  }

  Future<NodeFrame> _setTorch(bool on) async {
    try {
      final torchOn = await _hardware.setTorch(on);
      return NodeFrame.response('', payload: {'on': torchOn});
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'FLASH_ERROR',
        'message': '$e',
      });
    }
  }

  void dispose() {
    unawaited(_hardware.dispose());
  }
}
