import 'package:flutter/material.dart';
import 'package:au_frontend/models/attendance_item.dart';
import 'package:au_frontend/screens/bunk_calculator_screen.dart';

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
            FloatingActionButton(
              heroTag: "btn_bunk",
              onPressed: () async {
                final data = await future;
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BunkCalculatorScreen(items: data),
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
