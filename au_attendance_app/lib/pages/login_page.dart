//pages/login_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'attendance_page.dart';

final storage = FlutterSecureStorage();
const baseUrl = "http://192.168.0.133:3000";

class LoginPage extends StatefulWidget {
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final uCtrl = TextEditingController();
  final pCtrl = TextEditingController();
  bool saving = false;

  Future<void> saveCreds() async {
    setState(() => saving = true);

    String? uid = await storage.read(key: 'uid');
    if (uid == null || uid.isEmpty) {
      uid = const Uuid().v4();
      await storage.write(key: 'uid', value: uid);
    }

    final username = uCtrl.text.trim();
    final password = pCtrl.text.trim();

    await storage.write(key: 'username', value: username);
    await storage.write(key: 'password', value: password);

    final body = jsonEncode({'uid': uid, 'username': username, 'password': password});

    try {
      final resp = await http.post(
        Uri.parse('$baseUrl/save-credentials'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (resp.statusCode == 200) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => AttendancePage(uid!)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Server Error: ${resp.body}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Network error: $e')));
    }

    setState(() => saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login / Save Credentials')),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(controller: uCtrl, decoration: InputDecoration(labelText: 'Username')),
            TextField(controller: pCtrl, decoration: InputDecoration(labelText: 'Password'), obscureText: true),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: saving ? null : saveCreds,
              child: saving
                  ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('Save & View Attendance'),
            )
          ],
        ),
      ),
    );
  }
}
