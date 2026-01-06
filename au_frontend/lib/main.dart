import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:au_frontend/screens/login_screen.dart';
import 'package:au_frontend/screens/attendance_screen.dart';
import 'package:au_frontend/screens/routine_screen.dart'; // ✅ ADDED
import 'package:au_frontend/services/secure_storage.dart';
import 'package:au_frontend/services/api.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';


/// ✅ GLOBAL NAVIGATOR KEY (ADDED)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final FirebaseAnalytics analytics = FirebaseAnalytics.instance;

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
      navigatorObservers: [
    FirebaseAnalyticsObserver(analytics: analytics),
  ],
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
  StreamSubscription<String>? _tokenRefreshSub;

  @override
  void initState() {
    super.initState();
    _hasCreds = _checkCreds();

    // Android 13+ requires runtime notification permission
    _ensureNotificationPermission();

    // 🔥 GET & PRINT FCM TOKEN
    FirebaseMessaging.instance.getToken().then((token) {
      debugPrint("🔥 FCM TOKEN: $token");
    });

    // 🔄 PERMANENT FCM TOKEN REFRESH LISTENER
    // Automatically updates backend whenever Firebase rotates the token
    // This ensures notifications continue working even if token changes silently
    _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(
      (newToken) async {
        debugPrint("🔄 FCM token refreshed: $newToken");
        
        // Get username from secure storage (user must be logged in)
        final username = await SecureStore.readUsername();
        
        if (username == null || username.isEmpty) {
          debugPrint("⚠️ Token refresh: No username found, skipping backend update");
          return;
        }

        // Update backend with new token (silently, no UI)
        try {
          await Api.saveFcmToken(username: username, fcmToken: newToken);
          debugPrint("✅ Token refresh: Backend updated successfully for $username");
        } catch (e) {
          // Log error but don't block - token will be retried on next app open or login
          debugPrint("❌ Token refresh: Failed to update backend: $e");
        }
      },
      onError: (error) {
        debugPrint("❌ Token refresh listener error: $error");
      },
    );

    // 🔔 SAFE FOREGROUND NOTIFICATION LISTENER
    // Note: System notifications are handled automatically by FCM
    _fcmSub = FirebaseMessaging.onMessage.listen((message) {
      if (!mounted) return;

      final notif = message.notification;
      if (notif == null) return;

      debugPrint("🔔 FOREGROUND MSG: ${notif.title}");
      // System notification will be shown automatically by FCM
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
    _tokenRefreshSub?.cancel();
    super.dispose();
  }

  Future<bool> _checkCreds() async {
    final u = await SecureStore.readUsername();
    final p = await SecureStore.readPassword();
    return (u != null && u.isNotEmpty && p != null && p.isNotEmpty);
  }

  Future<void> _ensureNotificationPermission() async {
    try {
      if (Platform.isAndroid) {
        final status = await Permission.notification.status;
        if (!status.isGranted) {
          await Permission.notification.request();
        }
      }
    } catch (_) {
      // best-effort; do not block app startup
    }
  }

  /// ✅ NAVIGATE TO ROUTINE SCREEN (ADDED)
  void _openRoutineScreen() {
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const RoutineScreen()),
    );
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    final type = data['type'];

    if (type == 'attendance') {
      _openRoutineScreen();
    }
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
