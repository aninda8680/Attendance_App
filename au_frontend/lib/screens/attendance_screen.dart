// screens/attendance_screen.dart
import 'package:flutter/material.dart';
import 'package:au_frontend/models/attendance_item.dart';
import 'package:au_frontend/services/api.dart';
import 'package:au_frontend/services/secure_storage.dart';
import 'login_screen.dart';
import 'dart:math' as math;
import 'bunk_calculator_screen.dart';
import 'loading.dart';
import 'package:au_frontend/components/animated_action_button.dart';
import 'package:au_frontend/components/attendance_fab.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late Future<List<AttendanceItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<AttendanceItem>> _load() async {
    final u = await SecureStore.readUsername();
    final p = await SecureStore.readPassword();
    if (u == null || p == null) throw Exception('Missing credentials');
    return Api.fetchAttendance(username: u, password: p);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Attendance updated')));
    }
  }

  Future<void> _logout() async {
    await SecureStore.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final isSmall = height < 700 || width < 360;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 225, 229, 255),
      body: FutureBuilder<List<AttendanceItem>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const AttendanceLoading();
          }

          if (snap.hasError) {
            return _ErrorView(
              message: snap.error.toString(),
              onRetry: _refresh,
            );
          }

          final items = snap.data ?? [];
          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                children: [
                  const SizedBox(height: 160),
                  const Center(
                    child: Text(
                      'No attendance data found.\nPlease check your username or password.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: AnimatedActionButton(
                      onPressed: _logout,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.logout),
                          SizedBox(width: 8),
                          Text('Logout'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final avg = _calcAverage(items);
          final usernameFuture = SecureStore.readUsername();

          // 🌈 Dynamic header colors
          final headerGradient = avg >= 75
              ? [Colors.green.shade400, Colors.green.shade700]
              : avg >= 60
              ? [Colors.orange.shade400, Colors.orange.shade700]
              : [Colors.red.shade400, Colors.red.shade700];

          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: isSmall ? 150 : 200,
                  backgroundColor: headerGradient.last,
                  surfaceTintColor: Colors.transparent,
                  centerTitle: true,
                  elevation: 0,
                  flexibleSpace: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints constraints) {
                      final double expandRatio =
                          ((constraints.maxHeight - kToolbarHeight) /
                                  ((isSmall ? 130 : 200) - kToolbarHeight))
                              .clamp(0.0, 1.0);

                      return FlexibleSpaceBar(
                        centerTitle: true,
                        title: Opacity(
                          opacity: 1 - expandRatio,
                          child: const Text(
                            "My Atendance",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        background: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: headerGradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Opacity(
                            opacity: expandRatio,
                            child: SingleChildScrollView(
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  20,
                                  isSmall ? 40 : 60,
                                  20,
                                  16,
                                ),
                                child: FutureBuilder<String?>(
                                  future: usernameFuture,
                                  builder: (context, snapUser) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text(
                                          "My Attendance",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.9,
                                            ),
                                            fontSize: 18,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "Adamas University",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.9,
                                            ),
                                            fontSize: 18,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          snapUser.data != null
                                              ? "Reg No: ${snapUser.data}"
                                              : "Loading user...",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _MiniStatCard(
                                                icon: Icons.book_outlined,
                                                label: "Subjects",
                                                value: items.length.toString(),
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: _MiniStatCard(
                                                icon: Icons.trending_up,
                                                label: "Average",
                                                value:
                                                    "${avg.toStringAsFixed(1)}%",
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      onPressed: _logout,
                    ),
                  ],
                ),

                // 🧾 Attendance Cards
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, i) {
                      final it = items[i];
                      final percent = _parsePercent(it.percent) ?? 0;
                      final color = percent >= 75
                          ? Colors.green
                          : (percent >= 60 ? Colors.orange : Colors.redAccent);

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            colors: [Colors.white, Colors.grey.shade100],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 5,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Text(
                            it.subject,
                            maxLines: 3,
                            softWrap: true,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Held: ${it.held}  •  Present: ${it.attended}  •  Absent: ${it.totalAbsent}",
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(height: 8),
                                TweenAnimationBuilder<double>(
                                  duration: const Duration(milliseconds: 800),
                                  curve: Curves.easeOutCubic,
                                  tween: Tween<double>(begin: 0, end: percent),
                                  builder: (context, val, _) {
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: LinearProgressIndicator(
                                        value: val / 100,
                                        backgroundColor: Colors.grey.shade200,
                                        color: color,
                                        minHeight: 8,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    TweenAnimationBuilder<double>(
                                      duration: const Duration(
                                        milliseconds: 500,
                                      ),
                                      tween: Tween(begin: 0, end: 1),
                                      curve: Curves.easeOut,
                                      builder: (context, value, child) {
                                        return Opacity(
                                          opacity: value,
                                          child: Transform.translate(
                                            offset: Offset(0, (1 - value) * 6),
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: Text(
                                        "Attendance: ${it.percent}",
                                        style: TextStyle(
                                          color: color,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    TweenAnimationBuilder<double>(
                                      duration: const Duration(
                                        milliseconds: 500,
                                      ),
                                      tween: Tween(begin: 0, end: 1),
                                      builder: (context, value, child) {
                                        return Transform.scale(
                                          scale: value,
                                          child: child,
                                        );
                                      },
                                      child: Icon(
                                        Icons.circle,
                                        size: 10,
                                        color: color,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }, childCount: items.length),
                  ),
                ),
              ],
            ),
          );
        },
      ),

      floatingActionButton: SafeArea(
        child: AttendanceFAB(future: _future, onRefresh: _refresh),
      ),
    );
  }

  double? _parsePercent(String s) {
    final cleaned = s.replaceAll('%', '').trim();
    return double.tryParse(cleaned);
  }

  double _calcAverage(List<AttendanceItem> items) {
    final validPercents = items
        .map((e) => _parsePercent(e.percent))
        .whereType<double>()
        .toList();
    if (validPercents.isEmpty) return 0.0;
    return validPercents.reduce((a, b) => a + b) / validPercents.length;
  }
}

class _MiniStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MiniStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // NOTE: return a plain Container. The caller already wraps this widget with Expanded.
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: FittedBox(
        alignment: Alignment.topLeft,
        fit: BoxFit.scaleDown,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: color.withOpacity(0.9), fontSize: 12),
            ),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedActionButton(
                  onPressed: () => onRetry(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.refresh),
                      SizedBox(width: 8),
                      Text('Try Again'),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                AnimatedActionButton(
                  delay: const Duration(milliseconds: 200),
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                  backgroundColor: Colors.redAccent,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.logout),
                      SizedBox(width: 8),
                      Text('Logout'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
