import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/node_frame.dart';
import 'capability_handler.dart';

class CameraCapability extends CapabilityHandler {
  List<CameraDescription>? _cameras;
  Future<void> _cameraQueue = Future.value();

  /// Fired after every successful camera.snap. Listeners (e.g. chat_screen)
  /// can attach the image to the current bot message for inline display.
  static Function(String base64, String mimeType)? onSnapTaken;

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

  Future<T> _runExclusive<T>(Future<T> Function() operation) {
    final previous = _cameraQueue;
    final gate = Completer<void>();
    _cameraQueue = gate.future;

    return (() async {
      await previous.catchError((_) {});
      try {
        return await operation();
      } finally {
        if (!gate.isCompleted) gate.complete();
      }
    })();
  }

  @override
  Future<NodeFrame> handleWithPermission(
      String command, Map<String, dynamic> params) async {
    if (!_isPermissionProtectedCommand(command)) {
      return super.handleWithPermission(command, params);
    }

    return _runExclusive(() async {
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
    });
  }

  /// Create a fresh controller for each operation. The caller MUST dispose it
  /// when done so the camera hardware is released immediately.
  Future<CameraController> _createController({String? facing}) async {
    _cameras ??= await availableCameras();
    if (_cameras!.isEmpty) throw Exception('No camera available');

    final direction = facing == 'front'
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    final target = _cameras!.firstWhere(
      (c) => c.lensDirection == direction,
      orElse: () => _cameras!.first,
    );

    final controller = CameraController(
      target,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await controller.initialize();
    return controller;
  }

  Future<void> _disposeController(CameraController? controller) async {
    if (controller == null) return;
    try {
      await controller.dispose();
    } catch (_) {
      // Android may already be tearing the camera session down after permission
      // or lifecycle transitions. Disposal is best-effort cleanup.
    }
  }

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    return _runExclusive(() => _handleUnlocked(command, params));
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
      _cameras ??= await availableCameras();
      final cameraList = _cameras!
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
    CameraController? controller;
    try {
      final facing = params['facing'] as String?;
      controller = await _createController(facing: facing);

      // Brief settle time for auto-exposure/focus
      await Future.delayed(const Duration(milliseconds: 500));

      final file = await controller.takePicture();
      final bytes = await File(file.path).readAsBytes();
      final b64 = base64Encode(bytes);

      // Get image dimensions
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final width = frame.image.width;
      final height = frame.image.height;
      frame.image.dispose();

      // Clean up temp file
      await File(file.path).delete().catchError((_) => File(file.path));

      // Notify listeners (e.g. chat_screen) so the image can be shown inline
      onSnapTaken?.call(b64, 'image/jpeg');

      return NodeFrame.response('', payload: {
        'base64': b64,
        'format': 'jpg',
        'width': width,
        'height': height,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'CAMERA_ERROR',
        'message': '$e',
      });
    } finally {
      // Always release the camera
      await _disposeController(controller);
    }
  }

  Future<NodeFrame> _clip(Map<String, dynamic> params) async {
    CameraController? controller;
    try {
      final durationMs = params['durationMs'] as int? ?? 5000;
      final facing = params['facing'] as String?;
      controller = await _createController(facing: facing);
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
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'CAMERA_ERROR',
        'message': '$e',
      });
    } finally {
      // Always release the camera
      await _disposeController(controller);
    }
  }

  void dispose() {
    // No persistent controller to clean up anymore
  }
}
