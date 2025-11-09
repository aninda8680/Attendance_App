import 'package:flutter/material.dart';
import 'package:au_frontend/models/attendance_item.dart';
import '../models/bunk_math.dart';

class BunkCalculatorScreen extends StatelessWidget {
  final List<AttendanceItem> items;

  const BunkCalculatorScreen({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2FF),

      appBar: AppBar(
        title: const Text(
          "Bunk Calculator",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        elevation: 4,
      ),

      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final it = items[i];

          final A = int.tryParse(it.attended) ?? 0;
          final T = int.tryParse(it.held) ?? 0;
          final math = BunkMath.compute(attended: A, total: T);

          final color = math.currentPct >= 75
              ? Colors.green
              : math.currentPct >= 60
                  ? Colors.orange
                  : Colors.red;

          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Subject Name
                Text(
                  it.subject,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 10),

                // Basic Stats
                Text(
                  "Held: ${it.held}   |   Present: ${it.attended}   |   Absent: ${it.totalAbsent}",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),

                const SizedBox(height: 10),

                // Current %
                Text(
                  "Current Attendance: ${math.currentPct.toStringAsFixed(2)}%",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),

                const SizedBox(height: 10),

                // Calculated Insights
                
                Text(" Max bunkable: ${math.xMax}",
                    style: const TextStyle(fontSize: 14)),
                Text(
                  " Attend at least ${math.classesToGain1Bunk} more → +1 bunk",
                  style: const TextStyle(fontSize: 14),
                ),

                const SizedBox(height: 8),

                // Warnings
                if (math.isCloseTo75)
                  Text(
                    "⚠ You're close to 75%! Bunk carefully.",
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                if (math.currentPct < 75)
                  Text(
                    " Below 75%. Attend more classes!",
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          );
        },
      ),

      // ✅ FAB - Back Button
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pop(context),
        backgroundColor: Colors.deepPurple,
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        label: const Text(
          "Back",
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
