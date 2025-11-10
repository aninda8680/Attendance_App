import 'package:flutter/material.dart';
import 'update_service.dart';

class UpdateChecker extends StatefulWidget {
  final Widget child;
  const UpdateChecker({super.key, required this.child});

  @override
  State<UpdateChecker> createState() => _UpdateCheckerState();
}

class _UpdateCheckerState extends State<UpdateChecker> {
  @override
  void initState() {
    super.initState();
    _checkUpdate();
  }

  Future<void> _checkUpdate() async {
    final update = await UpdateService.checkForUpdate();
    if (update != null && mounted) {
      _showUpdateDialog(update);
    }
  }

  void _showUpdateDialog(UpdateInfo update) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        double progress = 0.0;
        bool downloading = false;

        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: Text("Update Available (${update.version})"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(update.changelog),
                const SizedBox(height: 12),
                if (downloading) ...[
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 6),
                  Text("${(progress * 100).toStringAsFixed(0)}%"),
                ]
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
                        if (path != null) await UpdateService.installApk(path);
                        Navigator.pop(context);
                      },
                child: Text(downloading ? "Downloading..." : "Update"),
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
