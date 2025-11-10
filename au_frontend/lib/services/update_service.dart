import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class UpdateService {
  static const String versionUrl =
      "https://anindadebta.github.io/myapp-updates/version.json"; // your GitHub Pages URL

  static Future<Map<String, dynamic>?> checkForUpdate() async {
    try {
      final response = await http.get(Uri.parse(versionUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final PackageInfo info = await PackageInfo.fromPlatform();
        final currentVersion = info.version;
        final latestVersion = data["version"];

        if (_isNewerVersion(latestVersion, currentVersion)) {
          return data;
        }
      }
    } catch (e) {
      print("⚠️ Update check failed: $e");
    }
    return null;
  }

  static bool _isNewerVersion(String latest, String current) {
    final latestParts = latest.split('.').map(int.parse).toList();
    final currentParts = current.split('.').map(int.parse).toList();

    for (int i = 0; i < latestParts.length; i++) {
      if (i >= currentParts.length) return true;
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return false;
  }
}
