import 'package:flutter/material.dart';
import 'package:au_frontend/screens/login_screen.dart';
import 'package:au_frontend/screens/attendance_screen.dart';
import 'package:au_frontend/services/secure_storage.dart';
import 'package:au_frontend/services/update_service.dart'; // 👈 ADD THIS

void main() async {
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
    _checkForUpdate(); // 👈 update check runs silently at startup
  }

  Future<bool> _checkCreds() async {
    final u = await SecureStore.readUsername();
    final p = await SecureStore.readPassword();
    return (u != null && u.isNotEmpty && p != null && p.isNotEmpty);
  }

  Future<void> _checkForUpdate() async {
    final update = await UpdateService.checkForUpdate();
    if (update != null && mounted) {
      _showUpdateDialog(update);
    }
  }

  void _showUpdateDialog(UpdateInfo update) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        double progress = 0.0;
        bool downloading = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text("Update Available (${update.version})"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(update.changelog),
                  const SizedBox(height: 16),
                  if (downloading)
                    Column(
                      children: [
                        LinearProgressIndicator(value: progress),
                        const SizedBox(height: 8),
                        Text("${(progress * 100).toStringAsFixed(0)}%"),
                      ],
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: downloading ? null : () => Navigator.pop(context),
                  child: const Text("Later"),
                ),
                ElevatedButton(
                  onPressed: downloading
                      ? null
                      : () async {
                          setState(() {
                            downloading = true;
                            progress = 0;
                          });

                          final path = await UpdateService.downloadApk(
                            update.url,
                            (p) => setState(() => progress = p),
                          );

                          if (path != null) {
                            await UpdateService.installApk(path);
                          }

                          Navigator.pop(context);
                        },
                  child: Text(downloading ? "Downloading..." : "Update"),
                ),
              ],
            );
          },
        );
      },
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
