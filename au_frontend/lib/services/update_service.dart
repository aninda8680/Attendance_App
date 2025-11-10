// import 'dart:convert';
// import 'dart:io';
// import 'package:dio/dio.dart';
// import 'package:http/http.dart' as http;
// import 'package:package_info_plus/package_info_plus.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:open_filex/open_filex.dart';

// class UpdateInfo {
//   final String version;
//   final String url;
//   final String changelog;

//   UpdateInfo({required this.version, required this.url, required this.changelog});

//   factory UpdateInfo.fromJson(Map<String, dynamic> json) => UpdateInfo(
//         version: json['version'],
//         url: json['url'],
//         changelog: json['changelog'] ?? '',
//       );
// }

// class UpdateService {
//   // 👇 your hosted version.json URL
//   static const String versionUrl =
//       "https://aninda8680.github.io/myapp-updates/version.json";

//   static Future<UpdateInfo?> checkForUpdate() async {
//     try {
//       final response = await http.get(Uri.parse(versionUrl));
//       if (response.statusCode != 200) return null;

//       final data = json.decode(response.body);
//       final update = UpdateInfo.fromJson(data);

//       final info = await PackageInfo.fromPlatform();
//       final currentVersion = info.version;

//       if (_isNewer(update.version, currentVersion)) return update;
//     } catch (e) {
//       print("Update check failed: $e");
//     }
//     return null;
//   }

//   static bool _isNewer(String latest, String current) {
//     List<int> l = latest.split('.').map(int.parse).toList();
//     List<int> c = current.split('.').map(int.parse).toList();
//     for (int i = 0; i < l.length; i++) {
//       if (l[i] > c[i]) return true;
//       if (l[i] < c[i]) return false;
//     }
//     return false;
//   }

//   static Future<String?> downloadApk(String url, Function(double) onProgress) async {
//     try {
//       final dir = await getExternalStorageDirectory();
//       final filePath = '${dir!.path}/update.apk';

//       final dio = Dio();
//       await dio.download(
//         url,
//         filePath,
//         onReceiveProgress: (received, total) {
//           if (total != -1) onProgress(received / total);
//         },
//       );

//       return filePath;
//     } catch (e) {
//       print("Download failed: $e");
//       return null;
//     }
//   }

//   static Future<void> installApk(String filePath) async {
//     await OpenFilex.open(filePath);
//   }
// }
