import 'package:flutter/material.dart';
import '../services/update_service.dart';

class UpdateButton extends StatefulWidget {
  const UpdateButton({super.key});

  @override
  State<UpdateButton> createState() => _UpdateButtonState();
}

class _UpdateButtonState extends State<UpdateButton> {
  UpdateInfo? _update;
  bool _downloading = false;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    final info = await UpdateService.checkForUpdate();
    setState(() => _update = info);
  }

  Future<void> _performUpdate() async {
    if (_update == null) return;
    setState(() {
      _downloading = true;
      _progress = 0;
    });

    final path = await UpdateService.downloadApk(_update!.url, (p) {
      setState(() => _progress = p);
    });

    if (path != null) await UpdateService.installApk(path);

    setState(() => _downloading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_update == null) return const SizedBox();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!_downloading)
          ElevatedButton(
            onPressed: _performUpdate,
            child: Text("Update available (${_update!.version})"),
          ),
        if (_downloading) ...[
          LinearProgressIndicator(value: _progress),
          const SizedBox(height: 8),
          Text("${(_progress * 100).toStringAsFixed(0)}%"),
        ],
      ],
    );
  }
}
