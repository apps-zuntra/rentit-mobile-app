// lib/core/image_utils.dart
import 'dart:convert';
import 'package:flutter/material.dart';

const String kDefaultImageBaseUrl = "https://rentit-backend-omega.vercel.app";

/// Universal image URL sanitizer and encoder
String? sanitizeImageUrl(dynamic url, [String baseUrl = kDefaultImageBaseUrl]) {
  if (url == null) return null;

  // If it's a Map / JSON object containing a URL field
  if (url is Map) {
    final inner =
        url['url'] ??
        url['src'] ??
        url['path'] ??
        url['fileUrl'] ??
        url['link'] ??
        url['secure_url'] ??
        url['imageUrl'];
    if (inner != null) return sanitizeImageUrl(inner, baseUrl);
    return null;
  }

  var s = url.toString().trim();
  if (s.isEmpty ||
      s == 'null' ||
      s == 'undefined' ||
      s == '[]' ||
      s == '{}' ||
      s.toLowerCase() == 'none') {
    return null;
  }

  // Remove surrounding quotes and brackets if present
  while ((s.startsWith('"') && s.endsWith('"')) ||
      (s.startsWith("'") && s.endsWith("'")) ||
      (s.startsWith('[') && s.endsWith(']'))) {
    s = s.substring(1, s.length - 1).trim();
  }

  // Remove escaped quotes and normalize backslashes in paths
  s = s
      .replaceAll(r'\"', '')
      .replaceAll(r"\'", '')
      .replaceAll(r'\', '/')
      .trim();
  if (s.isEmpty || s == 'null' || s == 'undefined' || s == '[]') return null;

  // Handle Base64 Data URLs directly
  if (s.startsWith('data:image/')) {
    return s;
  }

  // Determine base origin (protocol + host + port)
  final baseUri = Uri.tryParse(baseUrl);
  final host = baseUri?.host ?? '192.168.1.37';
  final portStr = (baseUri?.hasPort == true)
      ? ':${baseUri!.port}'
      : (baseUri?.scheme == 'https' ? '' : ':5000');
  final baseOrigin = baseUri != null && baseUri.scheme.isNotEmpty
      ? '${baseUri.scheme}://$host$portStr'
      : baseUrl;

  // Replace localhost / 127.0.0.1 / 10.0.2.2 with base origin
  if (s.startsWith('http://localhost') ||
      s.startsWith('http://127.0.0.1') ||
      s.startsWith('http://10.0.2.2') ||
      s.startsWith('https://localhost') ||
      s.startsWith('https://127.0.0.1')) {
    s = s.replaceFirst(
      RegExp(r'https?:\/\/(localhost|127\.0\.0\.1|10\.0\.2\.2)(:\d+)?'),
      baseOrigin,
    );
  }

  // Convert relative URLs to absolute URLs
  if (!s.startsWith('http://') && !s.startsWith('https://')) {
    if (s.startsWith('//')) {
      s = 'https:$s';
    } else if (s.startsWith('/')) {
      s = '$baseOrigin$s';
    } else {
      s = '$baseOrigin/$s';
    }
  }

  // Encode spaces and special characters so Dart's Uri.parse won't throw FormatException
  try {
    return Uri.encodeFull(s);
  } catch (_) {
    return s;
  }
}

/// Extract all valid image URLs from any Property object or image field
List<String> extractPropertyImages(
  dynamic source, [
  String baseUrl = kDefaultImageBaseUrl,
]) {
  if (source == null) return [];

  dynamic raw;
  if (source is Map) {
    raw =
        source['images'] ??
        source['photos'] ??
        source['photo'] ??
        source['image'] ??
        source['coverImage'] ??
        source['imageUrl'] ??
        source['image_url'] ??
        source['propertyImages'] ??
        source['media'];
  } else {
    raw = source;
  }

  if (raw == null) return [];
  if (raw is bool || raw is num) return [];

  List<dynamic> list = [];

  // Parse if it's a JSON string
  if (raw is String) {
    final s = raw.trim();
    if (s.isEmpty ||
        s == 'null' ||
        s == '[]' ||
        s == '{}' ||
        s == 'undefined') {
      return [];
    }
    if ((s.startsWith('[') && s.endsWith(']')) ||
        (s.startsWith('{') && s.endsWith('}'))) {
      try {
        final decoded = jsonDecode(s);
        if (decoded is List) {
          list = decoded;
        } else if (decoded is Map) {
          list = decoded.values.toList();
        } else {
          list = [s];
        }
      } catch (_) {
        if (s.startsWith('[') && s.endsWith(']')) {
          list = s
              .substring(1, s.length - 1)
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        } else {
          list = [s];
        }
      }
    } else {
      list = [s];
    }
  } else if (raw is List) {
    list = raw;
  } else if (raw is Map) {
    list = raw.values.toList();
  }

  final List<String> result = [];

  for (var item in list) {
    if (item == null) continue;

    // If item is a Map
    if (item is Map) {
      final u =
          item['url'] ??
          item['src'] ??
          item['path'] ??
          item['fileUrl'] ??
          item['link'] ??
          item['secure_url'] ??
          item['imageUrl'];
      if (u != null) {
        final clean = sanitizeImageUrl(u, baseUrl);
        if (clean != null && clean.isNotEmpty && !result.contains(clean)) {
          result.add(clean);
        }
      }
      continue;
    }

    String str = item.toString().trim();
    if (str.isEmpty || str == 'null' || str == '[]' || str == '{}') continue;

    // Check if item is itself a nested JSON string (e.g. "[\"https://...\"]")
    if ((str.startsWith('[') && str.endsWith(']')) ||
        (str.startsWith('"[') && str.endsWith(']"'))) {
      try {
        final inner = jsonDecode(str.startsWith('"') ? jsonDecode(str) : str);
        if (inner is List) {
          for (var sub in inner) {
            final clean = sanitizeImageUrl(sub, baseUrl);
            if (clean != null && clean.isNotEmpty && !result.contains(clean)) {
              result.add(clean);
            }
          }
          continue;
        }
      } catch (_) {}
    }

    final clean = sanitizeImageUrl(str, baseUrl);
    if (clean != null && clean.isNotEmpty && !result.contains(clean)) {
      result.add(clean);
    }
  }

  return result;
}

/// A safe, resilient image widget that handles network URLs, base64 data URIs, and fallbacks
Widget buildPropertyImage(
  dynamic imageSource, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  BorderRadius? borderRadius,
  Widget Function()? placeholder,
  String baseUrl = kDefaultImageBaseUrl,
}) {
  String? url;
  if (imageSource is String) {
    url = sanitizeImageUrl(imageSource, baseUrl);
  } else if (imageSource is List && imageSource.isNotEmpty) {
    url = sanitizeImageUrl(imageSource.first, baseUrl);
  } else if (imageSource is Map) {
    final list = extractPropertyImages(imageSource, baseUrl);
    url = list.isNotEmpty ? list.first : null;
  }

  Widget defaultPlaceholder() => Container(
    width: width ?? double.infinity,
    height: height ?? 200,
    decoration: BoxDecoration(
      color: const Color(0xFFEFF6F3),
      borderRadius: borderRadius,
    ),
    child: const Center(
      child: Icon(Icons.apartment_rounded, size: 40, color: Color(0xFF0A7C66)),
    ),
  );

  Widget errorWidget = placeholder != null
      ? placeholder()
      : defaultPlaceholder();

  if (url == null || url.isEmpty) {
    return errorWidget;
  }

  Widget imgWidget;

  // Handle Base64 Data URLs
  if (url.startsWith('data:image/')) {
    try {
      final commaIndex = url.indexOf(',');
      final base64String = commaIndex != -1
          ? url.substring(commaIndex + 1)
          : url;
      final bytes = base64Decode(base64String.trim());
      imgWidget = Image.memory(
        bytes,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => errorWidget,
      );
    } catch (_) {
      return errorWidget;
    }
  } else {
    // Handle Network URLs
    imgWidget = Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => errorWidget,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: width,
          height: height,
          color: const Color(0xFFF3F4F6),
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                    : null,
                color: const Color(0xFF0A7C66),
              ),
            ),
          ),
        );
      },
    );
  }

  if (borderRadius != null) {
    return ClipRRect(borderRadius: borderRadius, child: imgWidget);
  }

  return imgWidget;
}
