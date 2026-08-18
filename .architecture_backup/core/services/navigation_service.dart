import 'package:url_launcher/url_launcher.dart';

class NavigationService {
  NavigationService._();

  static Future<void> openGoogleMaps(
    double latitude,
    double longitude,
  ) async {
    final url = Uri.parse(
      "https://www.google.com/maps/search/?api=1&query=$latitude,$longitude",
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
    }
  }

  static Future<void> openWaze(
    double latitude,
    double longitude,
  ) async {
    final url = Uri.parse(
      "https://waze.com/ul?ll=$latitude,$longitude&navigate=yes",
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
    }
  }
}
