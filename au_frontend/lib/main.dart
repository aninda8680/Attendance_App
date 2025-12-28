import 'dart:async';

import 'package:flutter/material.dart';
import 'package:au_frontend/screens/login_screen.dart';
import 'package:au_frontend/screens/attendance_screen.dart';
import 'package:au_frontend/screens/routine_screen.dart'; // ✅ ADDED
import 'package:au_frontend/services/secure_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// ✅ GLOBAL NAVIGATOR KEY (ADDED)
final GlobalKey<NavigatorState> navigatorKey =
    GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // ✅ ADDED
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

  late final StreamSubscription<RemoteMessage> _fcmSub;

  @override
  void initState() {
    super.initState();
    _hasCreds = _checkCreds();

    // 🔥 GET & PRINT FCM TOKEN
    FirebaseMessaging.instance.getToken().then((token) {
      debugPrint("🔥 FCM TOKEN: $token");
    });

    // 🔔 SAFE FOREGROUND NOTIFICATION LISTENER
    _fcmSub = FirebaseMessaging.onMessage.listen((message) {
      if (!mounted) return;

      final notif = message.notification;
      if (notif == null) return;

      debugPrint("🔔 FOREGROUND MSG: ${notif.title}");

      _showTopNotification(
        title: notif.title ?? 'AU Attendance',
        body: notif.body ?? '',
      );
    });

    // 🔔 Notification tapped (APP IN BACKGROUND)
FirebaseMessaging.onMessageOpenedApp.listen((message) {
  debugPrint("📲 Notification tapped (background)");
  debugPrint("📦 DATA: ${message.data}");
  _handleNotificationTap(message.data);
});

// 🔔 Notification tapped (APP TERMINATED)
FirebaseMessaging.instance.getInitialMessage().then((message) {
  if (message != null) {
    debugPrint("📲 Notification tapped (terminated)");
    debugPrint("📦 DATA: ${message.data}");
    _handleNotificationTap(message.data);
  }
});

  }

  @override
  void dispose() {
    _fcmSub.cancel();
    super.dispose();
  }

  Future<bool> _checkCreds() async {
    final u = await SecureStore.readUsername();
    final p = await SecureStore.readPassword();
    return (u != null && u.isNotEmpty && p != null && p.isNotEmpty);
  }

  /// ✅ NAVIGATE TO ROUTINE SCREEN (ADDED)
  void _openRoutineScreen() {
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => const RoutineScreen(),
      ),
    );
  }

void _handleNotificationTap(Map<String, dynamic> data) {
  final type = data['type'];

  if (type == 'attendance') {
    _openRoutineScreen();
  }
}


  void _showTopNotification({
    required String title,
    required String body,
  }) {
    if (!mounted) return;

    final overlay = Overlay.of(context);
    if (overlay == null) return;

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => Positioned(
        top: MediaQuery.of(context).padding.top + 12,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);

    // ⏱ Auto dismiss
    Future.delayed(const Duration(seconds: 3), () {
      entry.remove();
    });
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
