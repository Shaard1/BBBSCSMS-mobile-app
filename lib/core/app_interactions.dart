import 'package:flutter/material.dart';

/// Keep Android stretch and iOS bounce physics supplied by Flutter.
/// All forms dismiss the keyboard naturally when the user scrolls.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  ScrollViewKeyboardDismissBehavior getKeyboardDismissBehavior(
    BuildContext context,
  ) =>
      ScrollViewKeyboardDismissBehavior.onDrag;
}

Duration appMotionDuration(BuildContext context, [int milliseconds = 180]) =>
    MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : Duration(milliseconds: milliseconds);

/// Keeps Flutter's platform transitions and back gestures, with a motion-free
/// alternative when requested in the device accessibility settings.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder(this.delegate);

  final PageTransitionsBuilder delegate;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return delegate.buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}

/// Shared one-shot motion; no controllers or timers remain running at rest.
AnimationStyle appMotionStyle(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : const AnimationStyle(
            duration: Duration(milliseconds: 180),
            reverseDuration: Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic);
