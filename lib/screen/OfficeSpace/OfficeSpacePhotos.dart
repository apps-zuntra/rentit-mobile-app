import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'OfficeSpaceContact.dart';

const String baseUrl = "https://rentit-backend-yti9.onrender.com";

class OfficeSpacePhotos extends StatefulWidget {
  const OfficeSpacePhotos({super.key});

  @override
  State<OfficeSpacePhotos> createState() => _OfficeSpacePhotosState();
}

class _OfficeSpacePhotosState extends State<OfficeSpacePhotos> {
  List<File> images = [];
  File? video;

  bool loading = false;

  final ImagePicker picker = ImagePicker();

  /*
  ==============================
  PICK IMAGES (MAX 6)
  ==============================
  */

  Future pickImages() async {
    final List<XFile> selected = await picker.pickMultiImage();

    if (selected.isEmpty) return;

    if (selected.length > 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Maximum 6 images allowed")));

      return;
    }

    setState(() {
      images = selected.map((e) => File(e.path)).toList();
    });
  }

  /*
  ==============================
  PICK VIDEO
  ==============================
  */

  Future pickVideo() async {
    final XFile? picked = await picker.pickVideo(source: ImageSource.gallery);

    if (picked != null) {
      setState(() {
        video = File(picked.path);
      });
    }
  }

  /*
  ==============================
  UPLOAD IMAGES
  ==============================
  */

  Future uploadImages(String propertyId, String token) async {
    var request = http.MultipartRequest(
      "POST",
      Uri.parse("$baseUrl/property/$propertyId/upload-images"),
    );

    request.headers["Authorization"] = "Bearer $token";

    for (var img in images) {
      request.files.add(await http.MultipartFile.fromPath("files", img.path));
    }

    var response = await request.send();

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception("Image upload failed");
    }
  }

  /*
  ==============================
  UPLOAD VIDEO
  ==============================
  */

  Future<void> uploadVideo(String propertyId, String token) async {
    if (video == null) return;

    final request = http.MultipartRequest(
      'POST',
      Uri.parse("$baseUrl/property/$propertyId/upload-video"),
    );

    /// ? HEADER
    request.headers['Authorization'] = 'Bearer $token';

    /// ? FILE (ONLY ONCE)
    request.files.add(
      await http.MultipartFile.fromPath(
        'file', // ?? MUST MATCH BACKEND
        video!.path,
      ),
    );

    /// ? SEND REQUEST
    final response = await request.send();

    final responseBody = await response.stream.bytesToString();

    print("VIDEO STATUS: ${response.statusCode}");
    print("VIDEO RESPONSE: $responseBody");

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception("Video upload failed");
    }
  }

  /*
  ==============================
  NEXT STEP
  ==============================
  */

  Future handleNext() async {
    final prefs = await SharedPreferences.getInstance();

    final dynamic propertyRaw = prefs.get("propertyId");
    final String? propertyId = propertyRaw?.toString();

    final dynamic tokenRaw = prefs.get("token");
    final String? token = tokenRaw?.toString();

    if (propertyId == null || token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Session expired. Login again")),
      );

      return;
    }

    if (images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Upload at least one image")),
      );

      return;
    }

    try {
      setState(() {
        loading = true;
      });

      await uploadImages(propertyId, token);

      if (video != null) {
        await uploadVideo(propertyId, token);
      }

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const OfficeSpaceContact()),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Upload Failed: $e")));
    } finally {
      if (!mounted) return;

      setState(() {
        loading = false;
      });
    }
  }

  /*
  ==============================
  IMAGE PREVIEW GRID
  ==============================
  */

  Widget imagePreview() {
    if (images.isEmpty) {
      return const Text("No images selected");
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),

      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),

      itemCount: images.length,

      itemBuilder: (context, index) {
        return Image.file(images[index], fit: BoxFit.cover);
      },
    );
  }

  /*
  ==============================
  UI
  ==============================
  */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Upload Photos & Video")),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            const Text("Upload Images (Max 6)", style: TextStyle(fontSize: 16)),

            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: pickImages,
              child: const Text("Select Images"),
            ),

            const SizedBox(height: 10),

            imagePreview(),

            const SizedBox(height: 30),

            const Text("Upload Video", style: TextStyle(fontSize: 16)),

            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: pickVideo,
              child: const Text("Select Video"),
            ),

            const SizedBox(height: 10),

            Text(video == null ? "No Video Selected" : "Video Selected"),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 50,

              child: ElevatedButton(
                onPressed: loading ? null : handleNext,

                child: Text(loading ? "Uploading..." : "Next Step"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
