import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:au_frontend/models/attendance_item.dart';

// TODO: Replace with your deployed Render service base URL (no trailing slash)
const String API_BASE = 'https://attendance-app-vfsw.onrender.com';


class Api {
  static Future<List<AttendanceItem>> fetchAttendance({
    required String username,
    required String password,
  }) async {
    final url = Uri.parse('$API_BASE/attendance');

    final resp = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final list = (data['attendance'] as List<dynamic>? ?? []);
      return list
          .map((e) => AttendanceItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    if (resp.statusCode == 401) {
      throw ApiError('Invalid username or password');
    }

    // Attempt to surface backend error message if present
    try {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      throw ApiError(data['error']?.toString() ?? 'Unknown error');
    } catch (_) {
      throw ApiError('Network/Server error (${resp.statusCode})');
    }
  }
}

class ApiError implements Exception {
  final String message;
  ApiError(this.message);

  @override
  String toString() => message;
}
