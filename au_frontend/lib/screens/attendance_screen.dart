import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:au_frontend/models/attendance_item.dart';
import 'package:au_frontend/services/api.dart';
import 'package:au_frontend/services/secure_storage.dart';
import 'login_screen.dart';
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
      backgroundColor: const Color(0xFFF4F7FF),
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
                        color: Color(0xFF333333),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: AnimatedActionButton(
                      onPressed: _logout,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.logout, size: 20),
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
          final Color primaryColor = avg >= 75
              ? const Color(0xFF10B981)
              : avg >= 60
                  ? Colors.amber.shade700
                  : const Color(0xFFE11D48);

          final headerGradient = avg >= 75
              ? [const Color(0xFF10B981), const Color(0xFF047857)]
              : avg >= 60
                  ? [const Color(0xFFF59E0B), const Color(0xFFB45309)]
                  : [const Color(0xFFEF4444), const Color(0xFFB91C1C)];

          return RefreshIndicator(
            onRefresh: _refresh,
            displacement: 40,
            color: primaryColor,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: isSmall ? 100 : 108,
                  backgroundColor: headerGradient.last,
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  centerTitle: true,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white, size: 22),
                      onPressed: _logout,
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.parallax,
                    centerTitle: true,
                    titlePadding: const EdgeInsets.only(bottom: 16),
                    title: LayoutBuilder(
                      builder: (context, constraints) {
                        final expandRatio = ((constraints.maxHeight - kToolbarHeight) /
                                ((isSmall ? 100 : 108) - kToolbarHeight))
                            .clamp(0.0, 1.0);
                        return Opacity(
                          opacity: (1 - expandRatio).clamp(0.0, 1.0),
                          child: Text(
                            "Attendance",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              letterSpacing: 0.5,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                                Shadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    background: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: headerGradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                        // Content
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 32, 16, 0),
                          child: FutureBuilder<String?>(
                            future: usernameFuture,
                            builder: (context, snapUser) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  _CircularAverageIndicator(
                                    average: avg,
                                    color: Colors.white,
                                    size: 68,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          snapUser.data ?? "Student",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 19,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          "Adamas University",
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.9),
                                            fontSize: 17,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            _HeaderStat(
                                              label: "Subjects",
                                              value: items.length.toString(),
                                            ),
                                            const SizedBox(width: 14),
                                            _HeaderStat(
                                              label: "Status",
                                              value: avg >= 75 ? "Safe" : "Low",
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ---------------------------------------------------------
                // ATTENDANCE SUBJECT CARDS LIST
                // ---------------------------------------------------------
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        // START: INDIVIDUAL ATTENDANCE CARD
                        final it = items[i];
                        final percent = _parsePercent(it.percent) ?? 0;
                        final color = percent >= 75
                            ? const Color(0xFF10B981)
                            : (percent >= 60 ? Colors.amber.shade700 : const Color(0xFFE11D48));

                        return _FadeInSlide(
                          index: i,
                          child: _InteractiveCard(
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.grey.withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                    },
                                    splashColor: color.withOpacity(0.1),
                                    child: IntrinsicHeight(
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          // PROPER COLOUR LINE LEFT
                                          Container(
                                            width: 5,
                                            decoration: BoxDecoration(
                                              color: color,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: color.withOpacity(0.3),
                                                  blurRadius: 4,
                                                  offset: const Offset(2, 0),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.all(16.0),
                                              child: Column(
                                                children: [
                                                  Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.center,
                                                    children: [
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment.start,
                                                          children: [
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(
                                                                  horizontal: 8, vertical: 2),
                                                              decoration: BoxDecoration(
                                                                color: color.withOpacity(0.08),
                                                                borderRadius:
                                                                    BorderRadius.circular(4),
                                                              ),
                                                              child: Text(
                                                                it.subject
                                                                    .split('||')
                                                                    .first
                                                                    .trim(),
                                                                style: TextStyle(
                                                                  fontWeight: FontWeight.w800,
                                                                  fontSize: 10,
                                                                  color: color,
                                                                  letterSpacing: 0.3,
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(height: 6),
                                                            Text(
                                                              it.subject.contains('||')
                                                                  ? it.subject
                                                                      .split('||')
                                                                      .last
                                                                      .trim()
                                                                  : it.subject,
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                              style: const TextStyle(
                                                                fontWeight: FontWeight.bold,
                                                                fontSize: 16,
                                                                color: Color(0xFF111827),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      _PercentBadge(
                                                          percent: percent, color: color),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 16),
                                                  _BuildAttendanceStats(it: it),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: items.length,
                    ),
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

class _CircularAverageIndicator extends StatelessWidget {
  final double average;
  final Color color;
  final double size;

  const _CircularAverageIndicator({
    required this.average,
    required this.color,
    this.size = 80,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            value: average / 100,
            strokeWidth: size / 10,
            backgroundColor: color.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            strokeCap: StrokeCap.round,
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "${average.toStringAsFixed(0)}%",
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: size * 0.22,
              ),
            ),
            Text(
              "AVG",
              style: TextStyle(
                color: color.withOpacity(0.8),
                fontSize: size * 0.12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String label;
  final String value;

  const _HeaderStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _PercentBadge extends StatelessWidget {
  final double percent;
  final Color color;

  const _PercentBadge({required this.percent, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        "${percent.toStringAsFixed(1)}%",
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _BuildAttendanceStats extends StatelessWidget {
  final AttendanceItem it;
  const _BuildAttendanceStats({required this.it});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _StatItem(label: "Held", value: it.held, icon: Icons.event_available),
        _StatItem(label: "Attended", value: it.attended, icon: Icons.check_circle_outline),
        _StatItem(label: "Absent", value: it.totalAbsent, icon: Icons.cancel_outlined),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF6B7280)),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Color(0xFF374151),
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF9CA3AF),
          ),
        ),
      ],
    );
  }
}

class _CustomProgressBar extends StatelessWidget {
  final double percent;
  final Color color;

  const _CustomProgressBar({required this.percent, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeOutQuart,
          tween: Tween<double>(begin: 0, end: percent / 100),
          builder: (context, val, _) {
            return Stack(
              children: [
                Container(
                  height: 10,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: val,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color.withOpacity(0.7), color],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _InteractiveCard extends StatefulWidget {
  final Widget child;
  const _InteractiveCard({required this.child});

  @override
  State<_InteractiveCard> createState() => _InteractiveCardState();
}

class _InteractiveCardState extends State<_InteractiveCard> {
  double scale = 1;
  double elevation = 16;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          scale = 0.98;
          elevation = 12;
        });
      },
      onTapUp: (_) {
        setState(() {
          scale = 1;
          elevation = 6;
        });
      },
      onTapCancel: () {
        setState(() {
          scale = 1;
          elevation = 6;
        });
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        scale: scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: elevation,
                offset: Offset(0, elevation / 2),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _FadeInSlide extends StatelessWidget {
  final Widget child;
  final int index;
  const _FadeInSlide({required this.child, required this.index});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + (index * 120)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
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
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline_rounded, size: 64, color: const Color(0xFFE11D48)),
            ),
            const SizedBox(height: 24),
            const Text(
              "Something went wrong",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text("Try Again"),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    backgroundColor: Colors.indigo,
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {
                     Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text("Logout"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    side: const BorderSide(color: Color(0xFFFECDD3)),
                    foregroundColor: const Color(0xFFE11D48),
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
