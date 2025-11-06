import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_page.dart';

final storage = FlutterSecureStorage();
const baseUrl = "http://192.168.0.133:3000";

class AttendancePage extends StatefulWidget {
  final String uid;
  AttendancePage(this.uid);

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  bool loading = true;
  dynamic attendance;
  String error = '';

  @override
  void initState() {
    super.initState();
    fetchAttendance();
  }

  Future<void> fetchAttendance() async {
    setState(() {
      loading = true;
      error = '';
    });

    try {
      final resp = await http.get(Uri.parse('$baseUrl/fetch-attendance?uid=${widget.uid}'));
      if (resp.statusCode == 200) {
        final j = jsonDecode(resp.body);
        setState(() {
          attendance = j['attendance'];
          loading = false;
        });
      } else {
        setState(() {
          error = 'Failed: ${resp.body}';
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Widget buildBody() {
    if (loading) return Center(child: CircularProgressIndicator());
    if (error.isNotEmpty) return Center(child: Text('Error: $error'));
    if (attendance == null) return Center(child: Text('No attendance data'));
    if (attendance is List) {
      return ListView.builder(
        itemCount: attendance.length,
        itemBuilder: (ctx, i) {
          final a = attendance[i];
          return ListTile(
            title: Text(a['course'] ?? '—'),
            subtitle: Text('Attended: ${a['totalPresent']} / ${a['totalClasses']}'),
            trailing: Text(a['percentage'] ?? ''),
          );
        },
      );
    }
    return Center(child: Text('Unknown data format'));
  }

  Future<void> logout() async {
    await storage.deleteAll();
    await http.post(
      Uri.parse('$baseUrl/clear-credentials'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'uid': widget.uid}),
    );
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Attendance'),
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: fetchAttendance),
          IconButton(icon: Icon(Icons.logout), onPressed: logout),
        ],
      ),
      body: buildBody(),
    );
  }
}
