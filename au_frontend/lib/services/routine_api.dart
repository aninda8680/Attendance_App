// lib/services/routine_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/routine_day.dart';

class RoutineApi {
  static const String BASE = "https://attendance-app-vfsw.onrender.com";

  static Future<RoutineDay> fetchRoutine({
    required String username,
    required String password,
    required String date,
  }) async {
    final uri = Uri.parse("$BASE/routine");
    print("API URL => $uri");

    final response = await http.post(
      uri,
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Cache-Control": "no-cache",
        "Pragma": "no-cache",
        "Expires": "0",
        // helpful UA for some servers
        "User-Agent": "Mozilla/5.0 (Flutter)",
      },
      body: jsonEncode({
        "username": username,
        "password": password,
        "date": date,
      }),
    );

    print("HTTP STATUS: ${response.statusCode}");
    print("RAW RESPONSE: ${response.body}");

    if (response.statusCode != 200) {
      // try parse possible JSON error message
      try {
        final err = jsonDecode(response.body);
        final msg = err['error'] ?? err['message'] ?? response.body;
        throw Exception("Server error: $msg");
      } catch (_) {
        throw Exception("Server returned status ${response.statusCode}");
      }
    }

    final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
    return RoutineDay.fromJson(jsonMap);
  }
}
