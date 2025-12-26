// lib/models/routine_period.dart
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
      period: (json['period'] is int) ? json['period'] as int : int.tryParse('${json['period']}') ?? 0,
      subject: json['subject'] ?? '',
      teacher: json['teacher'] ?? '',
      attendance: json['attendance'] ?? '',
      room: json['room'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'period': period,
      'subject': subject,
      'teacher': teacher,
      'attendance': attendance,
      'room': room,
    };
  }
}
