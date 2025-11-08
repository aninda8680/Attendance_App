import 'package:flutter/material.dart';
import 'package:au_frontend/models/attendance_item.dart';
import 'package:au_frontend/services/api.dart';
import 'package:au_frontend/services/secure_storage.dart';
import 'login_screen.dart';

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
    if (u == null || p == null) {
      throw Exception('Missing credentials');
    }
    return Api.fetchAttendance(username: u, password: p);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Attendance'),
        actions: [
          IconButton(
            onPressed: _logout,
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: FutureBuilder<List<AttendanceItem>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorView(message: snap.error.toString(), onRetry: _refresh);
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

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final it = items[i];
                final percent = _parsePercent(it.percent);
                return Card(
                  elevation: 1,
                  child: ListTile(
                    title: Text(it.subject, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Held: ${it.held} • Attended: ${it.attended}'),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(value: percent != null ? (percent / 100.0) : null),
                          const SizedBox(height: 4),
                          Text('Attendance: ${it.percent}')
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _refresh,
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh'),
      ),
    );
  }

  double? _parsePercent(String s) {
    final cleaned = s.replaceAll('%', '').trim();
    return double.tryParse(cleaned);
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
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => onRetry(),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            )
          ],
        ),
      ),
    );
  }
}
