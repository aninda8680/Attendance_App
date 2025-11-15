class RoutineDay {
  final String selected;
  final String dayName;
  final String dayDate;
  final List<RoutinePeriod> periods;

  RoutineDay({
    required this.selected,
    required this.dayName,
    required this.dayDate,
    required this.periods,
  });

  factory RoutineDay.fromJson(Map<String, dynamic> json) {
    return RoutineDay(
      selected: json['selected'],
      dayName: json['dayName'],
      dayDate: json['dayDate'],
      periods: (json['periods'] as List)
          .map((e) => RoutinePeriod.fromJson(e))
          .toList(),
    );
  }
}

class RoutinePeriod {
  final String subject;
  final String teacher;
  final String room;
  final String attendance;
  final int periodIndex;
  final int colspan;

  RoutinePeriod({
    required this.subject,
    required this.teacher,
    required this.room,
    required this.attendance,
    required this.periodIndex,
    required this.colspan,
  });

  factory RoutinePeriod.fromJson(Map<String, dynamic> json) {
    return RoutinePeriod(
      subject: json['subject'],
      teacher: json['teacher'],
      room: json['room'],
      attendance: json['attendance'],
      periodIndex: json['periodIndex'],
      colspan: json['colspan'],
    );
  }
}
