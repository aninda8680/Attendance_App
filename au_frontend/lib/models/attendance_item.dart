class AttendanceItem {
final String subject;
final String held;
final String attended;
final String percent; // keep as string for direct display


AttendanceItem({
required this.subject,
required this.held,
required this.attended,
required this.percent,
});


factory AttendanceItem.fromJson(Map<String, dynamic> j) {
return AttendanceItem(
subject: (j['subject'] ?? '').toString(),
held: (j['held'] ?? '').toString(),
attended: (j['attended'] ?? '').toString(),
percent: (j['percent'] ?? '').toString(),
);
}
}