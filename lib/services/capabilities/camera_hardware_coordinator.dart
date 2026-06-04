import 'dart:async';

import 'package:camera/camera.dart';

class CameraHardwareCoordinator {
  CameraHardwareCoordinator._();
  static final CameraHardwareCoordinator instance =
      CameraHardwareCoordinator._();

  Future<void> _queue = Future.value();
  List<CameraDescription>? _cameras;
  CameraController? _torchController;
  bool _torchOn = false;

  bool get torchOn => _torchOn;

  Future<T> runExclusive<T>(Future<T> Function() operation) {
    final previous = _queue;
    final gate = Completer<void>();
    _queue = gate.future;
    return (() async {
      await previous.catchError((_) {});
      try {
        return await operation();
      } finally {
        if (!gate.isCompleted) gate.complete();
      }
    })();
  }

  Future<List<CameraDescription>> cameras() async {
    _cameras ??= await availableCameras();
    return _cameras!;
  }

  Future<T> withCaptureController<T>({
    String? facing,
    ResolutionPreset resolution = ResolutionPreset.medium,
    bool enableAudio = false,
    required Future<T> Function(CameraController controller) body,
  }) {
    return runExclusive(() async {
      if (_torchController != null) {
        await _disposeTorchController();
      }
      final camera = await _selectCamera(facing);
      CameraController? controller;
      try {
        controller = CameraController(
          camera,
          resolution,
          enableAudio: enableAudio,
        );
        await controller.initialize();
        return await body(controller);
      } finally {
        try {
          await controller?.dispose();
        } catch (_) {}
      }
    });
  }

  Future<bool> setTorch(bool on) {
    return runExclusive(() async {
      if (!on && _torchController == null) {
        _torchOn = false;
        return _torchOn;
      }
      for (var attempt = 0; attempt < 2; attempt += 1) {
        try {
          final controller = await _torchControllerForBackCamera();
          await controller.setFlashMode(on ? FlashMode.torch : FlashMode.off);
          _torchOn = on;
          if (!on) await _disposeTorchController();
          return _torchOn;
        } catch (_) {
          await _disposeTorchController();
          if (attempt == 1) rethrow;
          await Future.delayed(const Duration(milliseconds: 120));
        }
      }
      return _torchOn;
    });
  }

  Future<CameraDescription> _selectCamera(String? facing) async {
    final list = await cameras();
    if (list.isEmpty) throw Exception('No camera available');
    final direction = facing == 'front'
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    return list.firstWhere(
      (camera) => camera.lensDirection == direction,
      orElse: () => list.first,
    );
  }

  Future<CameraController> _torchControllerForBackCamera() async {
    if (_torchController != null &&
        _torchController!.value.isInitialized &&
        !_torchController!.value.hasError) {
      return _torchController!;
    }
    await _disposeTorchController();
    final camera = await _selectCamera('back');
    _torchController = CameraController(camera, ResolutionPreset.low);
    await _torchController!.initialize();
    return _torchController!;
  }

  Future<void> _disposeTorchController() async {
    try {
      if (_torchController?.value.isInitialized == true) {
        await _torchController?.setFlashMode(FlashMode.off);
      }
    } catch (_) {}
    try {
      await _torchController?.dispose();
    } catch (_) {}
    _torchController = null;
    _torchOn = false;
  }

  Future<void> dispose() => runExclusive(_disposeTorchController);
}
