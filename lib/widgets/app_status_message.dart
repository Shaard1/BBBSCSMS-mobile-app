import 'package:flutter/material.dart';

class AppStatusMessage extends StatelessWidget {
  const AppStatusMessage(
      {super.key,
      required this.message,
      this.onRetry,
      this.icon = Icons.inbox_outlined});

  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 30, color: const Color(0xFF64748B)),
          const SizedBox(height: 12),
          Semantics(
              liveRegion: onRetry != null,
              child: Text(message,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: Color(0xFF475569), height: 1.4))),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again')),
          ],
        ]),
      );
}
