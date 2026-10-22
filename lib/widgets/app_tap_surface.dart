import 'package:flutter/material.dart';
import '../core/app_interactions.dart';

/// Paint feedback above decorated cards and photos, where an ancestor's ink
/// would otherwise be hidden. InkWell supplies keyboard and focus support.
class AppTapSurface extends StatefulWidget {
  const AppTapSurface({
    super.key,
    required this.child,
    required this.onTap,
    this.label,
    this.selected,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? label;
  final bool? selected;
  final BorderRadius borderRadius;

  @override
  State<AppTapSurface> createState() => _AppTapSurfaceState();
}

class _AppTapSurfaceState extends State<AppTapSurface> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => AnimatedScale(
        scale: _pressed &&
                widget.onTap != null &&
                !MediaQuery.disableAnimationsOf(context)
            ? 0.988
            : 1,
        duration: appMotionDuration(context, 100),
        curve: Curves.easeOutCubic,
        child: Semantics(
          button: widget.onTap != null,
          onTap: widget.onTap,
          label: widget.label,
          selected: widget.selected,
          child: Stack(clipBehavior: Clip.none, children: [
            widget.child,
            Positioned.fill(
                child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      borderRadius: widget.borderRadius,
                      onTap: widget.onTap,
                      excludeFromSemantics: true,
                      onHighlightChanged: (value) {
                        if (mounted && _pressed != value) {
                          setState(() => _pressed = value);
                        }
                      },
                    ))),
          ]),
        ),
      );
}
