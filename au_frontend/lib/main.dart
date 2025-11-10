import 'package:flutter/material.dart';
import 'package:au_frontend/screens/login_screen.dart';
import 'package:au_frontend/screens/attendance_screen.dart';
import 'package:au_frontend/services/secure_storage.dart';
import 'package:au_frontend/services/update_service.dart'; // ✅ new import
import 'package:url_launcher/url_launcher.dart'; // ✅ for "Update Now" button

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
    _checkForAppUpdate(); // ✅ new line
  }

  Future<bool> _checkCreds() async {
    final u = await SecureStore.readUsername();
    final p = await SecureStore.readPassword();
    return (u != null && u.isNotEmpty && p != null && p.isNotEmpty);
  }

  /// ✅ Checks for new version and shows popup
  Future<void> _checkForAppUpdate() async {
    final updateInfo = await UpdateService.checkForUpdate();
    if (updateInfo != null && mounted) {
      _showUpdateDialog(updateInfo);
    }
  }

  /// ✅ Update popup dialog
  void _showUpdateDialog(Map<String, dynamic> updateInfo) {
    showDialog(
      context: context,
      barrierDismissible: false, // User must choose
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("New Update Available 🚀"),
        content: Text(
          "A new version (${updateInfo['version']}) is available.\n\n"
          "What's new:\n${updateInfo['changelog']}",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Later"),
          ),
          ElevatedButton(
            onPressed: () async {
              final url = Uri.parse(updateInfo['url']);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text("Update Now"),
          ),
        ],
      ),
    );
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
