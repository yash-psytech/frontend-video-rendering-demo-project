import 'package:flutter/material.dart';

/// Dialog showing export progress with cancel option
class ExportProgressDialog extends StatefulWidget {
  final Stream<double>? progressStream;
  final VoidCallback? onCancel;

  const ExportProgressDialog({super.key, this.progressStream, this.onCancel});

  @override
  State<ExportProgressDialog> createState() => _ExportProgressDialogState();
}

class _ExportProgressDialogState extends State<ExportProgressDialog> {
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    widget.progressStream?.listen((progress) {
      if (mounted) {
        setState(() {
          _progress = progress;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Exporting Video'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            value: _progress,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${(_progress * 100).toStringAsFixed(0)}%',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(_getStatusText(), style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      actions: [
        TextButton(onPressed: widget.onCancel, child: const Text('Cancel')),
      ],
    );
  }

  String _getStatusText() {
    if (_progress < 0.3) {
      return 'Preparing overlays...';
    } else if (_progress < 0.9) {
      return 'Processing video...';
    } else {
      return 'Finalizing...';
    }
  }
}

/// Show export progress dialog
Future<void> showExportProgressDialog(
  BuildContext context, {
  required Stream<double> progressStream,
  VoidCallback? onCancel,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => ExportProgressDialog(
      progressStream: progressStream,
      onCancel: () {
        onCancel?.call();
        Navigator.pop(context);
      },
    ),
  );
}

/// Show export result dialog
Future<void> showExportResultDialog(
  BuildContext context, {
  required bool success,
  String? message,
  Duration? processingTime,
  VoidCallback? onRetry,
}) {
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(
            success ? Icons.check_circle : Icons.error,
            color: success ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(success ? 'Export Complete!' : 'Export Failed'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (success) ...[
            const Text('Video has been saved to your gallery.'),
            if (processingTime != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Processed in ${processingTime.inSeconds}.${(processingTime.inMilliseconds % 1000) ~/ 100}s',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ] else ...[
            Text(message ?? 'An error occurred during export.'),
          ],
        ],
      ),
      actions: [
        if (!success && onRetry != null)
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onRetry();
            },
            child: const Text('Retry'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(success ? 'OK' : 'Close'),
        ),
      ],
    ),
  );
}
