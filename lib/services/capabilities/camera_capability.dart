import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/node_frame.dart';
import '../tool_media_event_bus.dart';
import 'camera_hardware_coordinator.dart';
import 'capability_handler.dart';

class CameraCapability extends CapabilityHandler {
  final CameraHardwareCoordinator _hardware =
      CameraHardwareCoordinator.instance;

  @override
  String get name => 'camera';

  @override
  List<String> get commands => ['snap', 'clip', 'list'];

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

  bool _isPermissionProtectedCommand(String command) {
    return command == 'camera.snap' ||
        command == 'camera.clip' ||
        command == 'camera.list';
  }

  @override
  Future<NodeFrame> handleWithPermission(
      String command, Map<String, dynamic> params) async {
    if (!_isPermissionProtectedCommand(command)) {
      return super.handleWithPermission(command, params);
    }

    if (!await checkPermission()) {
      for (final perm in requiredPermissions) {
        if (await perm.isPermanentlyDenied) {
          return NodeFrame.response('', error: {
            'code': 'PERMISSION_PERMANENTLY_DENIED',
            'message':
                '$name permission permanently denied. Enable it in Android Settings > Apps > Plawie > Permissions.',
          });
        }
      }

      final granted = await requestPermission();
      if (!granted) {
        return NodeFrame.response('', error: {
          'code': 'PERMISSION_DENIED',
          'message': '$name permission not granted',
        });
      }
    }
    return _handleUnlocked(command, params);
  }

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    return _handleUnlocked(command, params);
  }

  Future<NodeFrame> _handleUnlocked(
      String command, Map<String, dynamic> params) async {
    switch (command) {
      case 'camera.snap':
        return _snap(params);
      case 'camera.clip':
        return _clip(params);
      case 'camera.list':
        return _list();
      default:
        return NodeFrame.response('', error: {
          'code': 'UNKNOWN_COMMAND',
          'message': 'Unknown camera command: $command',
        });
    }
  }

  Future<NodeFrame> _list() async {
    try {
      final cameraList = (await _hardware.cameras())
          .map((c) => {
                'id': c.name,
                'facing': c.lensDirection == CameraLensDirection.front
                    ? 'front'
                    : 'back',
              })
          .toList();
      return NodeFrame.response('', payload: {
        'cameras': cameraList,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'CAMERA_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _snap(Map<String, dynamic> params) async {
    try {
      final facing = params['facing'] as String?;
      return _hardware.withCaptureController(
        facing: facing,
        resolution: ResolutionPreset.medium,
        body: (controller) async {
          await Future.delayed(const Duration(milliseconds: 500));

          final file = await controller.takePicture();
          final bytes = await File(file.path).readAsBytes();
          final b64 = base64Encode(bytes);

          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          final width = frame.image.width;
          final height = frame.image.height;
          frame.image.dispose();

          await File(file.path).delete().catchError((_) => File(file.path));

          ToolMediaEventBus.instance.publish(ToolMediaEvent(
            source: 'camera.snap',
            base64: b64,
            mimeType: 'image/jpeg',
            width: width,
            height: height,
          ));

          return NodeFrame.response('', payload: {
            'base64': b64,
            'format': 'jpg',
            'width': width,
            'height': height,
            'attachedImage': true,
            'timestamp': DateTime.now().toIso8601String(),
          });
        },
      );
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'CAMERA_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _clip(Map<String, dynamic> params) async {
    try {
      final durationMs = params['durationMs'] as int? ?? 5000;
      final facing = params['facing'] as String?;
      return _hardware.withCaptureController(
        facing: facing,
        resolution: ResolutionPreset.medium,
        body: (controller) async {
          await controller.startVideoRecording();
          await Future.delayed(Duration(milliseconds: durationMs));
          final file = await controller.stopVideoRecording();
          final bytes = await File(file.path).readAsBytes();
          final b64 = base64Encode(bytes);
          await File(file.path).delete().catchError((_) => File(file.path));
          return NodeFrame.response('', payload: {
            'base64': b64,
            'format': 'mp4',
            'durationMs': durationMs,
            'hasAudio': false,
          });
        },
        enableAudio: false,
      );
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'CAMERA_ERROR',
        'message': '$e',
      });
    }
  }

  void dispose() {
    unawaited(_hardware.dispose());
  }
}
