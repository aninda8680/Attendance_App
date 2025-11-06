import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'pages/login_page.dart';
import 'pages/attendance_page.dart';

final storage = FlutterSecureStorage();

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: Root(),
    );
  }
}

class Root extends StatefulWidget {
  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  bool loading = true;
  String? uid;

  @override
  void initState() {
    super.initState();
    checkCreds();
  }

  Future<void> checkCreds() async {
    uid = await storage.read(key: 'uid');
    setState(() => loading = false);

    if (uid != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => AttendancePage(uid!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return Scaffold(body: Center(child: CircularProgressIndicator()));
    return LoginPage();
  }
}
