// lib/models/routine_day.dart
import 'routine_period.dart';

class RoutineDay {
  final bool success;
  final String dayName;
  final String dayDate;
  final List<RoutinePeriod> periods;
  final String? message;

  RoutineDay({
    required this.success,
    required this.dayName,
    required this.dayDate,
    required this.periods,
    this.message,
  });

  factory RoutineDay.fromJson(Map<String, dynamic> json) {
    final periodsJson = json['periods'] as List<dynamic>? ?? [];

    return RoutineDay(
      success: json['success'] == true,
      dayName: (json['dayName'] ?? '') as String,
      dayDate: (json['dayDate'] ?? '') as String,
      periods: periodsJson
          .map((p) => RoutinePeriod.fromJson(p as Map<String, dynamic>))
          .toList(),
      message: json['message'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'success': success,
        'dayName': dayName,
        'dayDate': dayDate,
        'periods': periods.map((p) => p.toJson()).toList(),
        'message': message,
      };
}
