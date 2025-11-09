//models/attendance_item.dart
class AttendanceItem {
  final String subject;
  final String totalClasses;
  final String totalPresent;
  final String totalAbsent;
  final String percent;

  AttendanceItem({
    required this.subject,
    required this.totalClasses,
    required this.totalPresent,
    required this.totalAbsent,
    required this.percent,
  });

  factory AttendanceItem.fromJson(Map<String, dynamic> j) {
    // ✅ Defensive conversion for any nulls or numbers
    String safe(dynamic val, [String def = '']) {
      if (val == null) return def;
      return val.toString().trim();
    }

    return AttendanceItem(
      subject: safe(j['subject']),
      totalClasses: safe(j['total_classes'] ?? j['held'], '0'),
      totalPresent: safe(j['total_present'] ?? j['attended'], '0'),
      totalAbsent: safe(j['total_absent'] ?? j['absent'], '0'),
      percent: safe(j['percent'], '0%'),
    );
  }

  // ✅ Optional alias getters for older UI
  String get held => totalClasses;
  String get attended => totalPresent;
  String get absent => totalAbsent;
}
