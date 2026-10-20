// ApartmentPhotosScreen.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:rentit/screen/Apartment/Apartment/ApartmentSchedule.dart';
import 'package:rentit/core/image_utils.dart';

import 'package:shared_preferences/shared_preferences.dart';

// -- Design Tokens (matches Commercial flow) -----------------------------------
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

class ApartmentPhotosScreen extends StatefulWidget {
  const ApartmentPhotosScreen({super.key});

  @override
  State<ApartmentPhotosScreen> createState() => _ApartmentPhotosScreenState();
}

class _ApartmentPhotosScreenState extends State<ApartmentPhotosScreen> {
  final String API_BASE = "https://rentit-backend-omega.vercel.app";

  // ? Existing images from server (URLs)
  List<String> existingImageUrls = [];
  final int currentStep = 5; // Property details = step 2

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
    loadExistingData(); // ? Load saved images on screen open
  }

  // -- API: Load existing photos & video ---------------------
  Future<void> loadExistingData() async {
    final prefs = await SharedPreferences.getInstance();
    final propertyId = prefs.getInt("propertyId");
    final token = prefs.getString("token");

    if (propertyId == null || token == null) {
      debugPrint("? propertyId or token missing");
      if (mounted) {
        setState(() => loadingData = false);
      }
      return;
    }

    try {
      debugPrint("?? Loading Apartment ID: $propertyId");

      final res = await http.get(
        Uri.parse("$API_BASE/apartment/$propertyId"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      debugPrint("?? STATUS CODE: ${res.statusCode}");
      debugPrint("?? RESPONSE: ${res.body}");

      if (!mounted) return;

      if (res.statusCode == 200) {
        final responseData = jsonDecode(res.body);

        // Backend sometimes returns {data:{...}}
        final data = responseData["data"] ?? responseData;

        List<String> loadedImages = [];

        // ? Images
        if (data["images"] != null && data["images"] is List) {
          loadedImages = (data["images"] as List).map((e) {
            final img = e.toString();

            // Full URL already
            if (img.startsWith("http")) {
              return img;
            }

            // Relative URL
            return "$API_BASE$img";
          }).toList();

          debugPrint("?? Loaded Images Count: ${loadedImages.length}");

          for (final img in loadedImages) {
            debugPrint("?? IMAGE => $img");
          }
        }

        // ? Video
        String? loadedVideo;

        if (data["video"] != null &&
            data["video"].toString().trim().isNotEmpty) {
          final videoUrl = data["video"].toString();

          loadedVideo = videoUrl.startsWith("http")
              ? videoUrl
              : "$API_BASE$videoUrl";

          debugPrint("?? VIDEO => $loadedVideo");
        }

        setState(() {
          existingImageUrls = loadedImages;
          existingVideoUrl = loadedVideo;
          loadingData = false;
        });

        debugPrint("? Existing data loaded successfully");
      } else {
        debugPrint("? Load failed: ${res.statusCode}");

        setState(() {
          loadingData = false;
        });
      }
    } catch (e, s) {
      debugPrint("? loadExistingData error: $e");
      debugPrint("$s");

      if (mounted) {
        setState(() {
          loadingData = false;
        });
      }
    }
  }

  // -- Total images count --------------------
  int get totalImageCount => existingImageUrls.length + newImages.length;

  // -- Pick images ---------------------------
  Future<void> pickImages() async {
    final int remaining = 6 - totalImageCount;
    if (remaining <= 0) {
      showSnack("Maximum 6 images allowed");
      return;
    }

    final List<XFile> picked = await _picker.pickMultiImage();
    if (picked.isEmpty) return;

    final List<XFile> limited = picked.length > remaining
        ? picked.sublist(0, remaining)
        : picked;

    if (picked.length > remaining) {
      showSnack(
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
        existingVideoUrl = null; // replaced by new file
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
    // ?? If no new images, still send existing images
    if (newImages.isEmpty && existingImageUrls.isEmpty) return;

    final request = http.MultipartRequest(
      "POST",
      Uri.parse("$API_BASE/apartment/$propertyId/upload-images"),
    );

    request.headers["Authorization"] = "Bearer $token";

    // ? Send existing images so backend can keep them
    request.fields["existingImages"] = jsonEncode(existingImageUrls);

    // ? Add new image files
    for (final file in newImages) {
      request.files.add(await http.MultipartFile.fromPath("files", file.path));
    }

    // ? Send request
    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    debugPrint("?? IMAGE UPLOAD STATUS: ${response.statusCode}");
    debugPrint("?? IMAGE UPLOAD RESPONSE: $responseBody");

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        "Image upload failed: ${response.statusCode}\n$responseBody",
      );
    }

    debugPrint("? Images uploaded successfully");
  }

  // -- Upload video --------------------------
  Future<void> uploadVideo(int propertyId, String token) async {
    if (video == null) return;

    final request = http.MultipartRequest(
      "POST",
      Uri.parse("$API_BASE/apartment/$propertyId/upload-video"),
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
    final prefs = await SharedPreferences.getInstance();
    final propertyId = prefs.getInt("propertyId");
    final token = prefs.getString("token");
    print("?? propertyId = $propertyId");
    print("?? token = $token");

    if (token == null) {
      showSnack("Session expired. Please login again.");
      return;
    }
    if (propertyId == null) {
      showSnack("Property ID missing.");
      return;
    }

    try {
      setState(() => loading = true);

      // Upload only newly picked images
      if (newImages.isNotEmpty) {
        await uploadImages(propertyId, token);
      }

      // Upload video only if a new one was picked
      if (video != null) {
        await uploadVideo(propertyId, token);
      }

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ApartmentScheduleForm()),
      );
    } catch (e) {
      debugPrint("? handleNext error: $e");
      if (mounted) showSnack("Upload failed: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // -- Snackbar ------------------------------
  void showSnack(String msg) {
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

  /// Segmented progress bar � 5 of 7 filled (matches apartment steps)
  Widget _progressBar() {
    const int total = 7;
    const int current = 5;
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
            color: Colors.black.withValues(alpha: 0.04),
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

  // -- Image Grid ----------------------------
  Widget _imageGrid() {
    // Combine existing URLs + new files into a unified list of 6 slots
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
                    // ? Show network image for existing, file image for new
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
                    // Remove button
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
                            color: Colors.black.withValues(alpha: 0.55),
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
                        color: kSecondaryText.withValues(alpha: 0.6),
                        size: 26,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${i + 1}",
                        style: TextStyle(
                          color: kSecondaryText.withValues(alpha: 0.5),
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

  // -- Video Preview -------------------------
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
                          color: kAccentBlue.withValues(alpha: 0.1),
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
                        color: Colors.black.withValues(alpha: 0.55),
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
                    color: kSecondaryText.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_circle_outline_rounded,
                    size: 28,
                    color: kSecondaryText.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "No video uploaded yet",
                  style: TextStyle(
                    color: kSecondaryText.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
    );
  }

  // -- Build ---------------------------------
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: kScaffoldBg,

        // -- AppBar --------------------------------------------------------
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
                  "5 / 7",
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

        // -- Body ----------------------------------------------------------
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
                          // -- Photos Card --------------------------------
                          _card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label("Property Photos"),
                                // Counter badge
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: totalImageCount > 0
                                            ? kAccentBlue.withValues(
                                                alpha: 0.08,
                                              )
                                            : kGridSlotBg,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: totalImageCount > 0
                                              ? kAccentBlue.withValues(
                                                  alpha: 0.25,
                                                )
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

                                // Grid
                                _imageGrid(),

                                const SizedBox(height: 14),

                                // Upload button
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
                                      color: kSecondaryText.withValues(
                                        alpha: 0.8,
                                      ),
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // -- Video Card ---------------------------------
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
                                            ? kAccentBlue.withValues(
                                                alpha: 0.08,
                                              )
                                            : kGridSlotBg,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color:
                                              (video != null ||
                                                  existingVideoUrl != null)
                                              ? kAccentBlue.withValues(
                                                  alpha: 0.25,
                                                )
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

                                // Preview
                                _videoPreview(),

                                const SizedBox(height: 14),

                                // Upload button
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
                                      color: kSecondaryText.withValues(
                                        alpha: 0.8,
                                      ),
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

                  // -- Sticky Next Button -----------------------------------
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
