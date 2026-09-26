import 'dart:async';

import 'package:flutter/material.dart';
import '../core/app_interactions.dart';

class TopToast {
  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(
    BuildContext context,
    String message, {
    Color backgroundColor = const Color(0xFF0B4F94),
    Duration duration = const Duration(milliseconds: 2400),
  }) {
    dismiss();

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _entry = OverlayEntry(
      builder: (overlayContext) {
        final topInset = MediaQuery.of(overlayContext).padding.top + 12;
        return Positioned(
          top: topInset,
          left: 16,
          right: 16,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: appMotionDuration(overlayContext),
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                  offset: Offset(0, -8 * (1 - value)), child: child),
            ),
            child: Semantics(
              liveRegion: true,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(children: [
                    Expanded(
                        child: Text(message,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                height: 1.4))),
                    const SizedBox(width: 8),
                    IconButton(
                        tooltip: 'Dismiss message',
                        onPressed: dismiss,
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 20)),
                  ]),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_entry!);
    if (!MediaQuery.accessibleNavigationOf(context)) {
      final readingTime = Duration(milliseconds: 3000 + message.length * 35);
      _timer = Timer(readingTime > duration ? readingTime : duration, dismiss);
    }
  }

  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
  }
}
