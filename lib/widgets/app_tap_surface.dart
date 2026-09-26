import 'package:flutter/material.dart';

/// Paint feedback above decorated cards and photos, where an ancestor's ink
/// would otherwise be hidden. InkWell supplies keyboard and focus support.
class AppTapSurface extends StatelessWidget {
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
  Widget build(BuildContext context) => Semantics(
        button: onTap != null,
        onTap: onTap,
        label: label,
        selected: selected,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                    borderRadius: borderRadius,
                    onTap: onTap,
                    excludeFromSemantics: true),
              ),
            ),
          ],
        ),
      );
}
