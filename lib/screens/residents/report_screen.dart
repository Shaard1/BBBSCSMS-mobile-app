import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  /* ---------------- VARIABLES ---------------- */

  final supabase = Supabase.instance.client;
  final TextEditingController descriptionController = TextEditingController();

  final ImagePicker picker = ImagePicker();

  File? selectedImage;
  bool isLoading = false;

  /* ---------------- IMAGE PICKER ---------------- */

  Future<void> pickImage() async {
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        selectedImage = File(image.path);
      });
    }
  }

  /* ---------------- IMAGE UPLOAD ---------------- */

  Future<String?> uploadImage(File imageFile) async {
    try {
      final fileName = path.basename(imageFile.path);

      final filePath = "${supabase.auth.currentUser!.id}/"
          "${DateTime.now().millisecondsSinceEpoch}_$fileName";

      await supabase.storage.from('report-images').upload(filePath, imageFile);

      final imageUrl =
          supabase.storage.from('report-images').getPublicUrl(filePath);

      return imageUrl;
    } catch (e) {
      debugPrint("Upload error: $e");
      return null;
    }
  }

  /* ---------------- SUBMIT REPORT ---------------- */

  Future<void> submitReport() async {
    /* ---------------- VALIDATION ---------------- */

    if (descriptionController.text.isEmpty || selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add description and image")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      /* ---------------- UPLOAD IMAGE ---------------- */

      final imageUrl = await uploadImage(selectedImage!);

      if (imageUrl == null) {
        throw Exception("Image upload failed");
      }

      /* ---------------- INSERT TO DATABASE ---------------- */

      await supabase.from('reports').insert({
        'user_id': supabase.auth.currentUser!.id,
        'description': descriptionController.text.trim(),
        'image_url': imageUrl,
        'latitude': 0, // temporary
        'longitude': 0, // temporary
        'status': 'pending',
      });

      if (!mounted) return;

      /* ---------------- RESET FORM ---------------- */

      setState(() {
        isLoading = false;
        descriptionController.clear();
        selectedImage = null;
      });

      /* ---------------- SUCCESS MESSAGE ---------------- */

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Report submitted successfully!")),
      );
    } catch (e) {
      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  /* ---------------- UI BUILD ---------------- */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Submit Report"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            /* ---------------- DESCRIPTION LABEL ---------------- */

            const Text(
              "Describe the problem:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            /* ---------------- DESCRIPTION FIELD ---------------- */

            TextField(
              controller: descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Enter description...",
              ),
            ),
            const SizedBox(height: 20),

            /* ---------------- PICK IMAGE BUTTON ---------------- */

            ElevatedButton(
              onPressed: pickImage,
              child: const Text("Pick Image"),
            ),
            const SizedBox(height: 10),

            /* ---------------- IMAGE PREVIEW ---------------- */

            if (selectedImage != null) Image.file(selectedImage!, height: 200),
            const SizedBox(height: 20),

            /* ---------------- SUBMIT BUTTON ---------------- */

            isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: submitReport,
                    child: const Text("Submit Report"),
                  ),
          ],
        ),
      ),
    );
  }
}
