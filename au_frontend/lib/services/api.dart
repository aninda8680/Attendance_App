import 'dart:convert';
import 'dart:io'; // <-- IMPORTANT for SocketException
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

    try {
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      // Successful request
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final list = (data['attendance'] as List<dynamic>? ?? []);
        return list
            .map((e) => AttendanceItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      if (resp.statusCode == 403 ||
          resp.statusCode == 500 ||
          resp.statusCode == 502 ||
          resp.statusCode == 503 ||
          resp.statusCode == 504) {
        throw ApiError(
          "The college server is currently unavailable.\nPlease try again later.",
        );
      }

      // Invalid credentials
      if (resp.statusCode == 401) {
        throw ApiError('Invalid username or password');
      }

      // Backend error with a message
      try {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        throw ApiError(data['error']?.toString() ?? 'Unknown error');
      } catch (_) {
        throw ApiError(
          'University server is not responding.\n'
          'Please try again later. (Error ${resp.statusCode})',
        );
      }
    } on SocketException catch (_) {
      // DNS failure / host not reachable / network down
      throw ApiError(
        'The college server is currently unreachable.\n'
        'Please check your connection or try again later.',
      );
    } on HandshakeException catch (_) {
      // SSL failure (usually server down)
      throw ApiError(
        'Secure connection failed.\n'
        'The college server might be down right now.',
      );
    } catch (e) {
      // Catch-all fallback
      throw ApiError('Something went wrong.\n$e');
    }
  }

  static Future<void> saveFcmToken({
    required String username,
    required String fcmToken,
  }) async {
    final url = Uri.parse('$API_BASE/save-fcm-token');

    try {
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'fcmToken': fcmToken}),
      );

      if (resp.statusCode != 200) {
        throw ApiError('Failed to register device for notifications');
      }
    } on SocketException {
      // Ignore silently — token will retry next login
      throw ApiError('Network unavailable while saving FCM token');
    } catch (e) {
      throw ApiError('FCM token error: $e');
    }
  }

  static Future<void> registerUser({
    required String username,
    required String password,
    required String fcmToken,
  }) async {
    final url = Uri.parse('$API_BASE/register-user');
    try {
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'fcmToken': fcmToken,
        }),
      );

      if (resp.statusCode != 200) {
        // capture backend error message if any
        String errMsg = 'Registration failed';
        try {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          if (data['message'] != null) errMsg = data['message'].toString();
          if (data['error'] != null) errMsg = data['error'].toString();
        } catch (_) {}
        throw ApiError(errMsg);
      }
    } on SocketException {
      throw ApiError('Network unavailable while registering user');
    } catch (e) {
      throw ApiError('Register user error: $e');
    }
  }
}

class ApiError implements Exception {
  final String message;
  ApiError(this.message);

  @override
  String toString() => message;
}
