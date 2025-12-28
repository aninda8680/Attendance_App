// routine_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:au_frontend/services/secure_storage.dart';
import 'package:au_frontend/components/routine_fab.dart';
import 'package:shared_preferences/shared_preferences.dart';




const String API_BASE = 'https://attendance-app-vfsw.onrender.com';

class RoutineScreen extends StatefulWidget {
  const RoutineScreen({Key? key}) : super(key: key);

  @override
  _RoutineScreenState createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen> {
  bool _loading = false;
  String _error = '';
  String _dayName = '';
  String _dayDate = '';
  List<RoutinePeriod> _periods = [];
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchRoutineForDate(_selectedDate);
  }

  String _formatDate(DateTime dt) {
    return DateFormat('dd-MM-yyyy').format(dt);
  }

  // ---------------- STATUS COLORS & GRADIENTS ----------------

  List<Color> _getStatusGradient(String status) {
    if (status == 'P') {
      return [Colors.green.shade400, Colors.green.shade700];
    } else if (status == 'A') {
      return [Colors.red.shade400, Colors.red.shade700];
    }
    return [Colors.grey.shade300, Colors.grey.shade400];
  }

  Color _getStatusIconColor(String status) {
    if (status == 'P') return Colors.green.shade700;
    if (status == 'A') return Colors.red.shade700;
    return Colors.grey.shade600;
  }

  IconData _getStatusIcon(String status) {
    if (status == 'P') return Icons.check_circle;
    if (status == 'A') return Icons.cancel;
    return Icons.remove_circle;
  }

  // ---------------- API ----------------

  Future<void> _fetchRoutineForDate(DateTime date) async {
    setState(() {
      _loading = true;
      _error = '';
      _periods.clear();
      _dayName = '';
      _dayDate = '';
    });

    try {
      final username = await SecureStore.readUsername();
      final password = await SecureStore.readPassword();

      if (username == null || password == null) {
        setState(() {
          _error = 'Missing credentials. Please login again.';
          _loading = false;
        });
        return;
      }

      final resp = await http.post(
        Uri.parse('$API_BASE/routine'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "username": username,
          "password": password,
          "date": _formatDate(date),
        }),
      );

      if (resp.statusCode != 200) {
        setState(() {
          _error = 'Server error: ${resp.statusCode}';
          _loading = false;
        });
        return;
      }

      final data = jsonDecode(resp.body);

      if (data['success'] != true) {
        setState(() {
          _error = data['message'] ?? 'No routine found';
          _loading = false;
        });
        return;
      }

      setState(() {
        _dayName = data['dayName'] ?? '';
        _dayDate = data['dayDate'] ?? _formatDate(date);
        _periods = (data['periods'] as List)
            .map((e) => RoutinePeriod.fromJson(e))
            .toList();
        _loading = false;
      });
      // 🔔 Detect P/A change and notify
_checkForAttendanceChange(_periods);

    } catch (e) {
      setState(() {
        _error = 'Failed to fetch routine';
        _loading = false;
      });
    }

    
  }

Future<void> _checkForAttendanceChange(
  List<RoutinePeriod> newPeriods,
) async {
  final prefs = await SharedPreferences.getInstance();

  // 🔑 Get username once
  final username = await SecureStore.readUsername() ?? 'unknown';

  for (final p in newPeriods) {
    // Skip free periods
    if (p.subject.isEmpty || p.attendance.isEmpty) continue;

    // ✅ UNIQUE KEY: user + date + subject
    final key = 'attendance_${username}_${_dayDate}_${p.subject}';

    final oldStatus = prefs.getString(key);
    final newStatus = p.attendance;

    // 🔔 NOTIFY WHEN:
    // 1️⃣ First time of the day (oldStatus == null)
    // 2️⃣ Attendance changes (P ↔ A)
    if (oldStatus == null || oldStatus != newStatus) {
      final statusText = newStatus == 'P' ? 'PRESENT' : 'ABSENT';

      _showTopNotification(
        title: statusText,
        body: 'in ${p.subject}',
      );
    }

    // 💾 Save latest status
    await prefs.setString(key, newStatus);
  }
}



void _showTopNotification({
  required String title,
  required String body,
}) {
  final overlay = Overlay.of(context);
  if (overlay == null) return;

  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (context) => Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
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

  // Auto dismiss after 3 seconds
  Future.delayed(const Duration(seconds: 3), () {
    entry.remove();
  });
}



  // ---------------- DATE PICKER ----------------

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
      _fetchRoutineForDate(picked);
    }
  }

  void _goToPreviousDay() {
    final prevDate = _selectedDate.subtract(const Duration(days: 1));
    setState(() => _selectedDate = prevDate);
    _fetchRoutineForDate(prevDate);
  }

  void _goToNextDay() {
    final nextDate = _selectedDate.add(const Duration(days: 1));
    setState(() => _selectedDate = nextDate);
    _fetchRoutineForDate(nextDate);
  }

  // ---------------- PERIOD CARD ----------------

  Widget _buildPeriodCard(RoutinePeriod p, int index) {
    final bool hasClass = p.subject.isNotEmpty;
    final bool isFreeLike = p.subject.isEmpty || p.attendance.isEmpty;


    final gradient = isFreeLike
    ? [Colors.white, Colors.grey.shade50]
    : _getStatusGradient(p.attendance);

    final statusIcon = _getStatusIcon(p.attendance);
    final statusColor = _getStatusIconColor(p.attendance);

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
  colors: gradient,
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
),

          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (hasClass ? gradient[0] : Colors.grey.shade300)
                  .withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Period Number Badge
                  // Period Number Badge (SMALLER)
Container(
  width: 40,   // ⬅ reduced from 56
  height: 40,  // ⬅ reduced from 56
  decoration: BoxDecoration(
    color: Colors.white.withOpacity(0.95),
    shape: BoxShape.circle,
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.08),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
    ],
  ),
  child: Center(
    child: Text(
      '${p.period}',
      style: TextStyle(
        fontSize: 14, // ⬅ reduced from 20
        fontWeight: FontWeight.w600,
        color: isFreeLike ? Colors.grey.shade700 : gradient[0],
      ),
    ),
  ),
),

                  const SizedBox(width: 16),
                  // Subject & Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasClass ? p.subject : 'Free Period',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isFreeLike
    ? Colors.grey.shade800
    : Colors.white,

                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (hasClass && p.teacher.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 14,
                                color: isFreeLike
    ? Colors.grey.shade600
    : Colors.white.withOpacity(0.9),

                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  p.teacher,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isFreeLike
    ? Colors.grey.shade600
    : Colors.white.withOpacity(0.9),

                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (hasClass && p.room.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: hasClass
                                    ? Colors.white.withOpacity(0.9)
                                    : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  p.room,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isFreeLike
    ? Colors.grey.shade600
    : Colors.white.withOpacity(0.9),

                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Attendance Status Badge
                  if (!isFreeLike)
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.95),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(statusIcon, size: 18, color: statusColor),
        const SizedBox(width: 4),
        Text(
          p.attendance,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: statusColor,
          ),
        ),
      ],
    ),
  ),

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final dateLabel = _dayDate.isNotEmpty
        ? _dayDate
        : _formatDate(_selectedDate);
    final dayNameDisplay = _dayName.isNotEmpty
        ? _dayName
        : DateFormat('EEEE').format(_selectedDate);

    // Calculate stats
    final presentCount = _periods.where((p) => p.attendance == 'P').length;
    final absentCount = _periods.where((p) => p.attendance == 'A').length;
    final totalClasses = presentCount + absentCount;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 225, 229, 255),
      body: CustomScrollView(
        slivers: [
          // Beautiful Gradient Header
          SliverAppBar(
  pinned: true,
  elevation: 4,
  backgroundColor: Colors.deepPurple,
  centerTitle: true,

  leading: IconButton(
    icon: const Icon(Icons.arrow_back, color: Colors.white),
    onPressed: () => Navigator.pop(context),
  ),

  title: const Text(
    "Class Routine",
    style: TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w600,
      fontSize: 25,
    ),
  ),

  actions: [
    IconButton(
      icon: const Icon(Icons.calendar_today, color: Colors.white),
      onPressed: _pickDate,
    ),
  ],
),




// Content
SliverToBoxAdapter(
  child: Column(
    children: [
      // const SizedBox(height: 2), // gap after header

      // ================= DATE NAVIGATION (ALWAYS VISIBLE) =================
      Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavButton(
                icon: Icons.chevron_left,
                onPressed: _goToPreviousDay,
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF667EEA),
                      const Color(0xFF764BA2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      dayNameDisplay,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateLabel,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _buildNavButton(
                icon: Icons.chevron_right,
                onPressed: _goToNextDay,
              ),
            ],
          ),
        ),
      ),

      // ================= LOADING INDICATOR =================
      if (_loading)
        const Padding(
          padding: EdgeInsets.only(top: 40),
          child: CircularProgressIndicator(),
        ),

      // ================= CONTENT (ONLY WHEN NOT LOADING) =================
      if (!_loading) ...[
        // Error Message
        if (_error.isNotEmpty)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _error,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // No data
        if (_periods.isEmpty && _error.isEmpty)
          Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              children: [
                Icon(
                  Icons.event_busy,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No routine data',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

        // Period Cards
        if (_periods.isNotEmpty)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _periods.length,
            padding: const EdgeInsets.only(bottom: 24),
            itemBuilder: (context, index) =>
                _buildPeriodCard(_periods[index], index),
          ),
      ],
    ],
  ),
),

        ],
      ),

      floatingActionButton: SafeArea(
    child: RoutineFAB(
      onRefresh: () async {
        await _fetchRoutineForDate(_selectedDate);
      },
    ),
  ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.grey.shade700),
        ),
      ),
    );
  }
}

// ---------------- MODEL ----------------

class RoutinePeriod {
  final int period;
  final String subject;
  final String teacher;
  final String attendance;
  final String room;

  RoutinePeriod({
    required this.period,
    required this.subject,
    required this.teacher,
    required this.attendance,
    required this.room,
  });

  factory RoutinePeriod.fromJson(Map<String, dynamic> json) {
    return RoutinePeriod(
      period: int.tryParse('${json['period']}') ?? 0,
      subject: json['subject']?.toString() ?? '',
      teacher: json['teacher']?.toString() ?? '',
      attendance: json['attendance']?.toString() ?? '',
      room: json['room']?.toString() ?? '',
    );
  }
}
