import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
// Note: XFile is usually exported by share_plus. If not, we might need cross_file.

class ShareUtils {
  /// The Deep Link prefix you provide.
  /// UPDATE THIS when you have your exact deep link URL structure!
  static String deepLinkPrefix = 'rentit://property';

  static Future<void> shareProperty({
    required String title,
    required String loc,
    required String area,
    required String rent,
    required String imageUrl,
    required String propertyId,
  }) async {
    final link = 'http://192.168.1.37/property/$propertyId';

    final StringBuffer sb = StringBuffer();
    sb.writeln('Check out this $title in $loc!');
    if (area.isNotEmpty && area != '0') sb.writeln('Area: $area sq.ft');
    if (rent.isNotEmpty && rent != '0') sb.writeln('Rent: ₹$rent/month');

    sb.writeln('\nCheck-out this property on the RentIt App! Click at');
    sb.writeln(link);

    final text = sb.toString();

    if (imageUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(imageUrl));
        if (response.statusCode == 200) {
          final xFile = XFile.fromData(
            response.bodyBytes,
            mimeType: 'image/jpeg',
            name: 'property_$propertyId.jpg',
          );
          await Share.shareXFiles([xFile], text: text);
          return;
        }
      } catch (e) {
        // Fallback to text if image download fails
      }
    }

    // Fallback to text only if no image or download failed
    await Share.share(text);
  }
}
