import 'package:flutter/material.dart';
import '../core/app_interactions.dart';

class AppContentSwitcher extends StatelessWidget {
  const AppContentSwitcher({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: appMotionDuration(context),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (current, previous) => Stack(
          fit: StackFit.expand,
          children: [
            for (final outgoing in previous)
              ExcludeSemantics(child: IgnorePointer(child: outgoing)),
            if (current != null) current,
          ],
        ),
        child: child,
      );
}
