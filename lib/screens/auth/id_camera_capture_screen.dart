import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class IdCameraCaptureScreen extends StatefulWidget {
  const IdCameraCaptureScreen({super.key});

  @override
  State<IdCameraCaptureScreen> createState() => _IdCameraCaptureScreenState();
}

class _IdCameraCaptureScreenState extends State<IdCameraCaptureScreen> {
  CameraController? _controller;
  bool _isInitializing = true;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) Navigator.pop(context);
        return;
      }

      final rear = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        rear,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _isInitializing = false;
      });
    } catch (_) {
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isCapturing) {
      return;
    }

    setState(() => _isCapturing = true);
    try {
      final shot = await controller.takePicture();
      if (!mounted) return;
      Navigator.pop(context, File(shot.path));
    } catch (_) {
      if (!mounted) return;
      setState(() => _isCapturing = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      body: _isInitializing || controller == null
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(controller),
                const _IdFrameOverlay(),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 12,
                  left: 12,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  ),
                ),
                Positioned(
                  bottom: 34,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: _capture,
                      child: Container(
                        width: 74,
                        height: 74,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: Center(
                          child: Container(
                            width: 58,
                            height: 58,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: _isCapturing
                                ? const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.black,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _IdFrameOverlay extends StatelessWidget {
  const _IdFrameOverlay();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final frameWidth = constraints.maxWidth * 0.78;
        final frameHeight = frameWidth * 0.62;
        final left = (constraints.maxWidth - frameWidth) / 2;
        final top = (constraints.maxHeight - frameHeight) / 2;
        final right = left + frameWidth;
        final bottom = top + frameHeight;

        return Stack(
          children: [
            // Dark mask around the guide frame
            Positioned(
              left: 0,
              top: 0,
              right: 0,
              height: top,
              child: Container(color: Colors.black.withOpacity(0.35)),
            ),
            Positioned(
              left: 0,
              top: top,
              width: left,
              height: frameHeight,
              child: Container(color: Colors.black.withOpacity(0.35)),
            ),
            Positioned(
              left: right,
              top: top,
              right: 0,
              height: frameHeight,
              child: Container(color: Colors.black.withOpacity(0.35)),
            ),
            Positioned(
              left: 0,
              top: bottom,
              right: 0,
              bottom: 0,
              child: Container(color: Colors.black.withOpacity(0.35)),
            ),
            Positioned(
              left: left,
              top: top,
              width: frameWidth,
              height: frameHeight,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withOpacity(0.9), width: 2),
                ),
              ),
            ),
            CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _FrameCornerPainter(
                frameWidth: frameWidth,
                frameHeight: frameHeight,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FrameCornerPainter extends CustomPainter {
  _FrameCornerPainter({
    required this.frameWidth,
    required this.frameHeight,
  });

  final double frameWidth;
  final double frameHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: frameWidth,
      height: frameHeight,
    );

    const cornerLen = 22.0;
    const stroke = 3.2;
    final p = Paint()
      ..color = Colors.white
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    // top-left
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(cornerLen, 0), p);
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(0, cornerLen), p);
    // top-right
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(-cornerLen, 0), p);
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(0, cornerLen), p);
    // bottom-left
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(cornerLen, 0), p);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(0, -cornerLen), p);
    // bottom-right
    canvas.drawLine(
      rect.bottomRight,
      rect.bottomRight + const Offset(-cornerLen, 0),
      p,
    );
    canvas.drawLine(
      rect.bottomRight,
      rect.bottomRight + const Offset(0, -cornerLen),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _FrameCornerPainter oldDelegate) {
    return oldDelegate.frameWidth != frameWidth ||
        oldDelegate.frameHeight != frameHeight;
  }
}
