//screens/attendance_screen.dart
import 'package:flutter/material.dart';
import 'package:au_frontend/models/attendance_item.dart';
import 'package:au_frontend/services/api.dart';
import 'package:au_frontend/services/secure_storage.dart';
import 'login_screen.dart';
import 'dart:math' as math;
import 'bunk_calculator_screen.dart';
import 'loading.dart';
import 'package:au_frontend/services/update_service.dart';

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
    _checkForUpdate();
  }

  Future<List<AttendanceItem>> _load() async {
    final u = await SecureStore.readUsername();
    final p = await SecureStore.readPassword();
    if (u == null || p == null) throw Exception('Missing credentials');
    return Api.fetchAttendance(username: u, password: p);
  }

  Future<void> _checkForUpdate() async {
  final update = await UpdateService.checkForUpdate();
  if (update != null && mounted) {
    _showUpdateDialog(update);
  }
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
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 225, 229, 255),
      body: FutureBuilder<List<AttendanceItem>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const AttendanceLoading();
            // // 🌈 Gradient based on your design preference (orange by default)
            // const gradientColors = [Color(0xFFFFA726), Color(0xFFFF7043)];

            // return Container(
            //   decoration: const BoxDecoration(
            //     gradient: LinearGradient(
            //       colors: gradientColors,
            //       begin: Alignment.topLeft,
            //       end: Alignment.bottomRight,
            //     ),
            //   ),
            //   child: Center(
            //     child: Column(
            //       mainAxisSize: MainAxisSize.min,
            //       children: [
            //         // 🎓 Logo / Icon
            //         TweenAnimationBuilder<double>(
            //           tween: Tween(begin: 0.8, end: 1.2),
            //           duration: const Duration(seconds: 2),
            //           curve: Curves.easeInOut,
            //           builder: (context, scale, _) {
            //             return Transform.scale(
            //               scale: scale,
            //               child: const Icon(
            //                 Icons.school_rounded,
            //                 color: Colors.white,
            //                 size: 80,
            //               ),
            //             );
            //           },
            //           onEnd: () {},
            //         ),
            //         const SizedBox(height: 24),
            //         // 💬 Loading Text
            //         TweenAnimationBuilder<double>(
            //           tween: Tween(begin: 0.3, end: 1),
            //           duration: const Duration(milliseconds: 1500),
            //           curve: Curves.easeInOut,
            //           builder: (context, opacity, _) {
            //             return Opacity(
            //               opacity: opacity,
            //               child: const Text(
            //                 "Loading your attendance...",
            //                 style: TextStyle(
            //                   color: Colors.white,
            //                   fontSize: 18,
            //                   fontWeight: FontWeight.w600,
            //                   letterSpacing: 0.5,
            //                 ),
            //               ),
            //             );
            //           },
            //         ),
            //         const SizedBox(height: 24),
            //         // 🔄 Progress Indicator
            //         const SizedBox(
            //           width: 48,
            //           height: 48,
            //           child: CircularProgressIndicator(
            //             strokeWidth: 4,
            //             color: Colors.white,
            //           ),
            //         ),
            //       ],
            //     ),
            //   ),
            // );
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
                children: const [
                  SizedBox(height: 160),
                  Center(child: Text('No attendance data found')),
                ],
              ),
            );
          }

          final avg = _calcAverage(items);
          final username = SecureStore.readUsername();

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
                  expandedHeight: 200,
                  backgroundColor: headerGradient.last,
                  surfaceTintColor: Colors.transparent,
                  centerTitle: true,
                  elevation: 0,
                  flexibleSpace: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints constraints) {
                      final double expandRatio =
                          ((constraints.maxHeight - kToolbarHeight) /
                                  (200 - kToolbarHeight))
                              .clamp(
                                0.0,
                                1.0,
                              ); // 1 = fully expanded, 0 = collapsed

                      return FlexibleSpaceBar(
                        centerTitle: true,
                        title: Opacity(
                          opacity:
                              1 -
                              expandRatio, // ✅ Show "My Attendance" only when collapsed
                          child: const Text(
                            "My Attendance",
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
                            opacity:
                                expandRatio, // ✅ Fades out while collapsing
                            child: SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  60,
                                  20,
                                  16,
                                ),
                                child: FutureBuilder<String?>(
                                  future: username,
                                  builder: (context, snap) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text(
                                          "My Attendance",
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.9,
                                            ),
                                            fontSize: 18,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),

                                        // const SizedBox(height: 4),
                                        Text(
                                          "Adamas University",
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.9,
                                            ),
                                            fontSize: 18,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        // const SizedBox(height: 4),
                                        Text(
                                          snap.data != null
                                              ? "Reg No: ${snap.data}"
                                              : "Loading user...",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            _MiniStatCard(
                                              icon: Icons.book_outlined,
                                              label: "Subjects",
                                              value: items.length.toString(),
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 16),
                                            _MiniStatCard(
                                              icon: Icons.trending_up,
                                              label: "Average",
                                              value:
                                                  "${avg.toStringAsFixed(1)}%",
                                              color: Colors.white,
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
                            maxLines: 2,
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Attendance: ${it.percent}",
                                      style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Icon(Icons.circle, size: 10, color: color),
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
      floatingActionButton: FutureBuilder<List<AttendanceItem>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SizedBox.shrink(); // ✅ Hide FABs while loading
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton(
                heroTag: "btn_bunk",
                onPressed: () async {
                  final data = await _future;
                  if (!mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BunkCalculatorScreen(items: data),
                    ),
                  );
                },
                backgroundColor: Colors.deepOrange,
                child: const Icon(Icons.calculate),
              ),
              const SizedBox(height: 12),
              FloatingActionButton(
                heroTag: "btn_refresh",
                onPressed: _refresh,
                backgroundColor: Colors.indigo,
                child: const Icon(Icons.refresh, color: Colors.white),
              ),
            ],
          );
        },
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
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: color.withOpacity(0.8), fontSize: 12),
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
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => onRetry(),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
