import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/routine_day.dart';

class RoutineAPI {
  static const String baseUrl = "https://attendance-app-vfsw.onrender.com";

  static Future<RoutineDay> fetchRoutine(
    String username,
    String password,
    DateTime date,
  ) async {
    final uri = Uri.parse("$baseUrl/routine");

    final res = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "username": username,
        "password": password,
        "date": "${date.toIso8601String().split('T')[0]}"
      }),
    );

    if (res.statusCode != 200) {
      throw Exception("Failed: ${res.body}");
    }

    final json = jsonDecode(res.body);
    return RoutineDay.fromJson(json);
  }
}