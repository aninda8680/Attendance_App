import 'package:flutter/material.dart';
import 'package:au_frontend/models/attendance_item.dart';
import 'package:au_frontend/screens/bunk_calculator_screen.dart';
import 'package:au_frontend/screens/routine_screen.dart';

class AttendanceFAB extends StatelessWidget {
  final Future<List<AttendanceItem>> future;
  final Future<void> Function() onRefresh;

  const AttendanceFAB({
    super.key,
    required this.future,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AttendanceItem>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink(); // hide while loading
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [

            /// -------------------------------
            /// BUNK BUTTON
            /// -------------------------------
            FloatingActionButton(
              heroTag: "btn_bunk",
              onPressed: () async {
                final data = await future;
                if (!context.mounted) return;

                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) =>
                        BunkCalculatorScreen(items: data),
                    transitionsBuilder: (_, animation, __, child) {
                      final offsetAnim = Tween(
                        begin: const Offset(1, 0),
                        end: Offset.zero,
                      ).animate(animation);
                      return SlideTransition(
                          position: offsetAnim, child: child);
                    },
                  ),
                );
              },
              backgroundColor: Colors.deepOrange,
              child: const Text(
                "BUNK?",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
            ),

            const SizedBox(height: 12),

            /// -------------------------------
            /// NEW SCHEDULE BUTTON
            /// -------------------------------
            FloatingActionButton(
              heroTag: "btn_routine",
              onPressed: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) => RoutineScreen(
                      username: "YOUR_USERNAME",
                      password: "YOUR_PASSWORD",
                    ),
                    transitionsBuilder: (_, animation, __, child) {
                      final anim = Tween(
                        begin: const Offset(1, 0),
                        end: Offset.zero,
                      ).animate(animation);
                      return SlideTransition(position: anim, child: child);
                    },
                  ),
                );
              },
              backgroundColor: Colors.teal,
              child: const Icon(Icons.schedule, color: Colors.white),
            ),

            const SizedBox(height: 12),

            /// -------------------------------
            /// REFRESH BUTTON
            /// -------------------------------
            FloatingActionButton(
              heroTag: "btn_refresh",
              onPressed: onRefresh,
              backgroundColor: Colors.indigo,
              child: const Icon(Icons.refresh, color: Colors.white),
            ),
          ],
        );
      },
    );
  }
}
