import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/routine_api.dart';
import '../models/routine_day.dart';

List<String> monthNames = [
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
  ];

class RoutineScreen extends StatefulWidget {
  final String username;
  final String password;

  const RoutineScreen({
    super.key,
    required this.username,
    required this.password,
  });

  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen> {
  DateTime selectedDate = DateTime.now();
  int selectedMonth = DateTime.now().month;
  int selectedWeek = 1;
  Future<RoutineDay>? futureRoutine;

  @override
  void initState() {
    super.initState();
    selectedWeek = getWeekOfMonth(selectedDate);
    loadRoutine();
  }

  int getWeekOfMonth(DateTime date) {
    return ((date.day - 1) ~/ 7) + 1;
  }

  void loadRoutine() {
    setState(() {
      futureRoutine = RoutineAPI.fetchRoutine(
        widget.username,
        widget.password,
        selectedDate,
      );
    });
  }

  void changeDate(DateTime newDate) {
    setState(() {
      selectedDate = newDate;
      selectedMonth = newDate.month;
      selectedWeek = getWeekOfMonth(newDate);
      loadRoutine();
    });
  }

  @override
  Widget build(BuildContext context) {
    final formatted = DateFormat("dd-MM-yyyy").format(selectedDate);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("Routine"),
        elevation: 0,
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),

          // -----------------------------
          // Prev <  DATE  > Next
          // -----------------------------
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 26),
                onPressed: () =>
                    changeDate(selectedDate.subtract(const Duration(days: 1))),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  formatted,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 26),
                onPressed: () =>
                    changeDate(selectedDate.add(const Duration(days: 1))),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // --------------------------------
          // Month / Week / Date Inputs
          // --------------------------------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: selectedMonth,
                    decoration: const InputDecoration(labelText: "Month"),
                    items: List.generate(
                      12,
                      (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text(monthNames[i]),
                      ),
                    ),
                    onChanged: (v) {
                      if (v != null) {
                        DateTime newDate = DateTime(
                          selectedDate.year,
                          v,
                          selectedDate.day,
                        );
                        changeDate(newDate);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    readOnly: true,
                    controller: TextEditingController(text: formatted),
                    decoration: const InputDecoration(labelText: "Pick Date"),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) changeDate(picked);
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          const Divider(),

          // --------------------------------
          // Routine List
          // --------------------------------
          Expanded(
            child: FutureBuilder<RoutineDay>(
              future: futureRoutine,
              builder: (context, s) {
                if (!s.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final routine = s.data!;

                return ListView(
                  padding: const EdgeInsets.all(10),
                  children: [
                    Center(
                      child: Text(
                        "${routine.dayName}  •  ${routine.dayDate}",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ...routine.periods.map(buildRoutineCard),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget buildRoutineTable(RoutineDay routine) {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade400),
      columnWidths: const {0: FixedColumnWidth(60), 1: FlexColumnWidth()},
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade300),
          children: const [
            Padding(
              padding: EdgeInsets.all(6),
              child: Text("P#", textAlign: TextAlign.center),
            ),
            Padding(
              padding: EdgeInsets.all(6),
              child: Text("Details", textAlign: TextAlign.center),
            ),
          ],
        ),

        ...routine.periods.map((p) {
          return TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text("P${p.periodIndex}", textAlign: TextAlign.center),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      p.subject,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(p.teacher),
                    Text(p.room, style: TextStyle(color: Colors.grey.shade600)),
                    const SizedBox(height: 6),
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: p.attendance == "P"
                          ? Colors.green
                          : Colors.red,
                      child: Text(
                        p.attendance,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget buildRoutineCard(RoutinePeriod p) {
    Color attendanceColor = p.attendance == "P"
        ? Colors.green
        : p.attendance == "A"
        ? Colors.red
        : Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "Period ${p.periodIndex}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              CircleAvatar(
                radius: 14,
                backgroundColor: attendanceColor,
                child: Text(
                  p.attendance,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            p.subject,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(p.teacher, style: const TextStyle(fontSize: 15)),
          const SizedBox(height: 4),
          Text(
            p.room,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  
}
