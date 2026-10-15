// PGPhotosScreen.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:rentit/pg_page/pg_page/pg_post/PGContactDetailsScreen.dart';
import 'package:rentit/core/image_utils.dart';
import 'package:rentit/providers/pg_draft_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// -- Design Tokens (matches full Commercial flow) ------------------------------
const Color kScaffoldBg = Color(0xFFF4F6F9);
const Color kCardBg = Colors.white;
const Color kPrimaryText = Color(0xFF1A2332);
const Color kSecondaryText = Color(0xFF8A97A8);
const Color kBorderColor = Color(0xFFE4E9F0);
const Color kAccentBlue = Color(0xFF2C3E50);
const Color kInputBg = Color(0xFFF8FAFC);
const Color kLabelText = Color(0xFF8A97A8);
const Color kDivider = Color(0xFFEEF2F7);
const Color kGridSlotBg = Color(0xFFF0F3F7);
// -----------------------------------------------------------------------------

class PGPhotosScreen extends ConsumerStatefulWidget {
  const PGPhotosScreen({super.key});

  @override
  ConsumerState<PGPhotosScreen> createState() => _PGPhotosScreenState();
}

class _PGPhotosScreenState extends ConsumerState<PGPhotosScreen> {
  final String API_BASE = "https://rentit-backend-yti9.onrender.com";

  // ? Existing images from server (URLs)
  List<String> existingImageUrls = [];
  final int currentStep = 5;

  // ? Newly picked images (Files)
  List<File> newImages = [];

  File? video;
  String? existingVideoUrl;

  bool loading = false;
  bool loadingData = true;

  final ImagePicker _picker = ImagePicker();

  // -- Lifecycle -----------------------------
  @override
  void initState() {
    super.initState();
    loadExistingData();
  }

  // -- API: Load existing photos -------------
  Future<void> loadExistingData() async {
    final prefs = await SharedPreferences.getInstance();
    final propertyId = prefs.getInt("propertyId");
    final token = prefs.getString("token");

    if (propertyId == null || token == null) {
      debugPrint("? propertyId or token missing");
      setState(() => loadingData = false);
      return;
    }

    try {
      final res = await http.get(
        Uri.parse("$API_BASE/property/$propertyId"),
        headers: {"Authorization": "Bearer $token"},
      );

      debugPrint("?? PHOTOS RESPONSE: ${res.body}");

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        setState(() {
          if (data["images"] != null && data["images"] is List) {
            existingImageUrls = List<String>.from(
              data["images"].map((e) => e.toString()),
            );
          }
          if (data["video"] != null && data["video"].toString().isNotEmpty) {
            existingVideoUrl = data["video"].toString();
          }
          loadingData = false;
        });
      } else {
        debugPrint("? Load failed: ${res.statusCode}");
        setState(() => loadingData = false);
      }
    } catch (e) {
      debugPrint("? loadExistingData error: $e");
      if (mounted) setState(() => loadingData = false);
    }
  }

  // -- Total images count --------------------
  int get totalImageCount => existingImageUrls.length + newImages.length;

  // -- Pick images ---------------------------
  Future<void> pickImages() async {
    final int remaining = 6 - totalImageCount;
    if (remaining <= 0) {
      _showSnack("Maximum 6 images allowed");
      return;
    }

    final List<XFile> picked = await _picker.pickMultiImage();
    if (picked.isEmpty) return;

    final List<XFile> limited = picked.length > remaining
        ? picked.sublist(0, remaining)
        : picked;

    if (picked.length > remaining) {
      _showSnack(
        "Only $remaining more image(s) can be added. Extra images ignored.",
      );
    }

    setState(() {
      newImages.addAll(limited.map((x) => File(x.path)));
    });
  }

  // -- Pick video ----------------------------
  Future<void> pickVideo() async {
    final XFile? picked = await _picker.pickVideo(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        video = File(picked.path);
        existingVideoUrl = null;
      });
    }
  }

  // -- Remove image --------------------------
  void removeExistingImage(int index) {
    setState(() => existingImageUrls.removeAt(index));
  }

  void removeNewImage(int index) {
    setState(() => newImages.removeAt(index));
  }

  // -- Remove video --------------------------
  void removeVideo() {
    setState(() {
      video = null;
      existingVideoUrl = null;
    });
  }

  // -- Upload new images ---------------------
  Future<void> uploadImages(int propertyId, String token) async {
    if (newImages.isEmpty) return;

    final request = http.MultipartRequest(
      "POST",
      Uri.parse("$API_BASE/property/$propertyId/upload-images"),
    );

    request.headers["Authorization"] = "Bearer $token";

    for (final file in newImages) {
      final bytes = await file.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          "files",
          bytes,
          filename: file.path.split("/").last,
        ),
      );
    }

    final response = await request.send();
    debugPrint("IMAGE UPLOAD STATUS: ${response.statusCode}");

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception("Image upload failed: ${response.statusCode}");
    }

    debugPrint("? Images uploaded successfully");
  }

  // -- Upload video --------------------------
  Future<void> uploadVideo(int propertyId, String token) async {
    if (video == null) return;

    final request = http.MultipartRequest(
      "POST",
      Uri.parse("$API_BASE/property/$propertyId/upload-video"),
    );

    request.headers["Authorization"] = "Bearer $token";

    final bytes = await video!.readAsBytes();
    request.files.add(
      http.MultipartFile.fromBytes(
        "file",
        bytes,
        filename: video!.path.split("/").last,
      ),
    );

    final response = await request.send();
    final respStr = await response.stream.bytesToString();

    debugPrint("VIDEO STATUS: ${response.statusCode}");
    debugPrint("VIDEO RESPONSE: $respStr");

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception("Video upload failed: ${response.statusCode}");
    }
  }

  // -- Handle Next ---------------------------
  Future<void> handleNext() async {
    if (newImages.isEmpty && existingImageUrls.isEmpty) {
      _showSnack("Please upload at least one image");
      return;
    }

    final draftProvider = ref.read(pgDraftProvider);

    draftProvider.update(() {
      draftProvider.draft.images = List.from(newImages);

      draftProvider.draft.video = video;
    });

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PGContactDetailsScreen()),
    );
  }

  // -- Snackbar ------------------------------
  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: kAccentBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // --------------------------------------------------------------------------
  //  UI HELPERS
  // --------------------------------------------------------------------------

  /// Segmented progress bar � 5 of 7 filled (PG has 7 steps, Photos = step 5)
  Widget _progressBar() {
    const int total = 8;
    const int current = 6;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
      child: Row(
        children: List.generate(total, (i) {
          final active = i < current;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i < total - 1 ? 4 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: active ? kAccentBlue : kBorderColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// White card wrapper
  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  /// Small all-caps section label
  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: kLabelText,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  /// Upload outline button
  Widget _uploadButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: kAccentBlue, size: 18),
        label: Text(
          label,
          style: const TextStyle(
            color: kAccentBlue,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: kAccentBlue, width: 1.5),
          backgroundColor: kInputBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  // -- Image Grid -------------------------------------------------------------
  Widget _imageGrid() {
    final List<dynamic> allImages = [...existingImageUrls, ...newImages];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemCount: 6,
      itemBuilder: (context, i) {
        final hasImage = i < allImages.length;
        final isExisting = hasImage && allImages[i] is String;
        final isNew = hasImage && allImages[i] is File;

        return Container(
          decoration: BoxDecoration(
            color: kGridSlotBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kBorderColor, width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: hasImage
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    isExisting
                        ? buildPropertyImage(
                            allImages[i] as String,
                            fit: BoxFit.cover,
                            placeholder: () => const Center(
                              child: Icon(
                                Icons.broken_image,
                                color: kSecondaryText,
                              ),
                            ),
                          )
                        : Image.file(allImages[i] as File, fit: BoxFit.cover),
                    Positioned(
                      top: 5,
                      right: 5,
                      child: GestureDetector(
                        onTap: () {
                          if (isExisting) {
                            removeExistingImage(i);
                          } else if (isNew) {
                            removeNewImage(i - existingImageUrls.length);
                          }
                        },
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        color: kSecondaryText.withOpacity(0.6),
                        size: 26,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${i + 1}",
                        style: TextStyle(
                          color: kSecondaryText.withOpacity(0.5),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  // -- Video Preview ----------------------------------------------------------
  Widget _videoPreview() {
    final hasVideo = video != null || existingVideoUrl != null;
    final videoName = video != null
        ? video!.path.split("/").last
        : existingVideoUrl != null
        ? existingVideoUrl!.split("/").last
        : "";

    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: kGridSlotBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorderColor, width: 1),
      ),
      child: hasVideo
          ? Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: kAccentBlue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.videocam_rounded,
                          size: 28,
                          color: kAccentBlue,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          videoName,
                          style: const TextStyle(
                            fontSize: 13,
                            color: kPrimaryText,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (existingVideoUrl != null && video == null) ...[
                        const SizedBox(height: 4),
                        const Text(
                          "Saved video",
                          style: TextStyle(fontSize: 11, color: kSecondaryText),
                        ),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: removeVideo,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: kSecondaryText.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_circle_outline_rounded,
                    size: 28,
                    color: kSecondaryText.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "No video uploaded yet",
                  style: TextStyle(
                    color: kSecondaryText.withOpacity(0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
    );
  }

  // -- Build ------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: kScaffoldBg,

        // -- AppBar ----------------------------------------------------------
        appBar: AppBar(
          backgroundColor: kCardBg,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          leading: GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kInputBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kBorderColor),
              ),
              child: const Icon(
                Icons.chevron_left_rounded,
                color: kPrimaryText,
                size: 22,
              ),
            ),
          ),
          title: const Text(
            "Photos & Video",
            style: TextStyle(
              color: kPrimaryText,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  "6 / 8",
                  style: TextStyle(
                    color: kSecondaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _progressBar(),
            ),
          ),
        ),

        // -- Body ------------------------------------------------------------
        body: loadingData
            ? const Center(
                child: CircularProgressIndicator(
                  color: kAccentBlue,
                  strokeWidth: 2,
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // -- Photos Card ----------------------------------
                          _card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label("Property Photos"),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: totalImageCount > 0
                                            ? kAccentBlue.withOpacity(0.08)
                                            : kGridSlotBg,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: totalImageCount > 0
                                              ? kAccentBlue.withOpacity(0.25)
                                              : kBorderColor,
                                        ),
                                      ),
                                      child: Text(
                                        "$totalImageCount / 6 photos added",
                                        style: TextStyle(
                                          color: totalImageCount > 0
                                              ? kAccentBlue
                                              : kSecondaryText,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                _imageGrid(),

                                const SizedBox(height: 14),

                                _uploadButton(
                                  label: "Upload Photos",
                                  icon: Icons.add_photo_alternate_outlined,
                                  onTap: totalImageCount >= 6
                                      ? null
                                      : pickImages,
                                ),

                                const SizedBox(height: 6),
                                Center(
                                  child: Text(
                                    "Upload up to 6 high-quality photos",
                                    style: TextStyle(
                                      color: kSecondaryText.withOpacity(0.8),
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // -- Video Card -----------------------------------
                          _card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label("Property Video"),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            (video != null ||
                                                existingVideoUrl != null)
                                            ? kAccentBlue.withOpacity(0.08)
                                            : kGridSlotBg,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color:
                                              (video != null ||
                                                  existingVideoUrl != null)
                                              ? kAccentBlue.withOpacity(0.25)
                                              : kBorderColor,
                                        ),
                                      ),
                                      child: Text(
                                        (video != null ||
                                                existingVideoUrl != null)
                                            ? "1 video added"
                                            : "Optional � MP4 � max 30 MB",
                                        style: TextStyle(
                                          color:
                                              (video != null ||
                                                  existingVideoUrl != null)
                                              ? kAccentBlue
                                              : kSecondaryText,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                _videoPreview(),

                                const SizedBox(height: 14),

                                _uploadButton(
                                  label:
                                      video != null || existingVideoUrl != null
                                      ? "Replace Video"
                                      : "Upload Video",
                                  icon: Icons.video_call_outlined,
                                  onTap: pickVideo,
                                ),

                                const SizedBox(height: 6),
                                Center(
                                  child: Text(
                                    "A walkthrough video helps tenants decide faster",
                                    style: TextStyle(
                                      color: kSecondaryText.withOpacity(0.8),
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),

                  // -- Sticky Save & Continue Button ------------------------
                  Container(
                    color: kCardBg,
                    padding: EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      12 + MediaQuery.of(context).padding.bottom,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kAccentBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: loading ? null : handleNext,
                        child: loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                "Save & Continue",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
