import 'package:flutter/material.dart';

class RoutineFAB extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const RoutineFAB({
    super.key,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [

/// -------------------------------
        /// REFRESH BUTTON
        /// -------------------------------
        FloatingActionButton(
          heroTag: "routine_btn_refresh",
          backgroundColor: Colors.indigo,
          onPressed: onRefresh,
          child: const Icon(Icons.refresh, color: Colors.white),
        ),

const SizedBox(height: 12),
        /// -------------------------------
        /// BACK BUTTON
        /// -------------------------------
        FloatingActionButton.extended(
  heroTag: "routine_btn_back",
  backgroundColor: Colors.deepPurple,
  onPressed: () => Navigator.pop(context),
  icon: const Icon(Icons.arrow_back, color: Colors.white),
  label: const Text(
    "Back",
    style: TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
    ),
  ),
),


        

        
      ],
    );
  }
}
