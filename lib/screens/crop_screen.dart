import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:path/path.dart' as path;

class CropScreen extends StatefulWidget {
  final Uint8List imageBytes;
  final String sourcePath;

  const CropScreen({
    super.key,
    required this.imageBytes,
    required this.sourcePath,
  });

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  final CropController controller = CropController();
  bool _isCropping = false;

  Future<void> _saveCroppedImage(CropResult result) async {
    if (_isCropping) return;

    setState(() {
      _isCropping = true;
    });

    try {
      if (result is CropSuccess) {
        final image = result.croppedImage;
        final originalFile = File(widget.sourcePath);
        final directory = originalFile.parent.path;
        final extension = path.extension(widget.sourcePath);
        final filename = path.basenameWithoutExtension(widget.sourcePath);
        final croppedPath = path.join(
          directory,
          "${filename}_cropped_${DateTime.now().microsecondsSinceEpoch}$extension",
        );
        final croppedFile = await File(croppedPath).writeAsBytes(image);

        if (!mounted) return;

        Navigator.pop(context, croppedFile);
      } else {
        // Handle failure
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Failed to crop image. Please try again.")),
        );
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Failed to crop image. Please try again.")),
      );
      setState(() {
        _isCropping = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Crop Profile Photo")),
      body: Column(
        children: [
          Expanded(
            child: Crop(
              image: widget.imageBytes,
              controller: controller,
              aspectRatio: 1,
              onCropped: _saveCroppedImage,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton(
              onPressed: _isCropping
                  ? null
                  : () {
                      controller.crop();
                    },
              child: _isCropping
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Crop Image"),
            ),
          ),
        ],
      ),
    );
  }
}
