import 'package:flutter/material.dart';
import 'package:au_frontend/screens/login_screen.dart';
import 'package:au_frontend/screens/attendance_screen.dart';
import 'package:au_frontend/services/secure_storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const _Bootstrapper(),
    );
  }
}

/// Decides whether to show Login or Attendance based on saved creds.
class _Bootstrapper extends StatefulWidget {
  const _Bootstrapper({super.key});

  @override
  State<_Bootstrapper> createState() => _BootstrapperState();
}

class _BootstrapperState extends State<_Bootstrapper> {
  Future<bool>? _hasCreds;

  @override
  void initState() {
    super.initState();
    _hasCreds = _checkCreds();
  }

  Future<bool> _checkCreds() async {
    final u = await SecureStore.readUsername();
    final p = await SecureStore.readPassword();
    return (u != null && u.isNotEmpty && p != null && p.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasCreds,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.data == true) {
          return const AttendanceScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
