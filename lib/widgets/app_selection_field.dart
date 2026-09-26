import 'package:flutter/material.dart';

import '../core/app_interactions.dart';

/// A bounded picker keeps the form in place and leaves room for large text.
Future<String?> showAppSelectionSheet({
  required BuildContext context,
  required String title,
  required List<String> options,
  String? selectedValue,
}) {
  FocusScope.of(context).unfocus();
  return showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : const AnimationStyle(
            duration: Duration(milliseconds: 240),
            reverseDuration: Duration(milliseconds: 180),
          ),
    builder: (context) => SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(title,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                  fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close choices',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                itemCount: options.length,
                separatorBuilder: (_, index) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final option = options[index];
                  final selected = option == selectedValue;
                  return Material(
                    color:
                        selected ? const Color(0xFFEAF3FF) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      selected: selected,
                      minVerticalPadding: 16,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      title: Text(option),
                      trailing: selected
                          ? const Icon(Icons.check_circle_rounded)
                          : null,
                      onTap: () => Navigator.pop(context, option),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class AppSelectionField extends StatefulWidget {
  const AppSelectionField({
    super.key,
    required this.label,
    required this.options,
    required this.onSelected,
    this.value,
    this.leading,
    this.errorText,
  });

  final String label;
  final List<String> options;
  final ValueChanged<String> onSelected;
  final String? value;
  final Widget? leading;
  final String? errorText;

  @override
  State<AppSelectionField> createState() => _AppSelectionFieldState();
}

class _AppSelectionFieldState extends State<AppSelectionField> {
  bool _isOpen = false;

  Future<void> _open() async {
    if (_isOpen) return;
    setState(() => _isOpen = true);
    final value = await showAppSelectionSheet(
      context: context,
      title: widget.label,
      options: widget.options,
      selectedValue: widget.value,
    );
    if (!mounted) return;
    setState(() => _isOpen = false);
    if (value != null) widget.onSelected(value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasError = widget.errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          label: widget.label,
          value: widget.value ?? 'Not selected',
          child: Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: hasError
                    ? colors.error
                    : _isOpen
                        ? colors.primary
                        : const Color(0xFFE6E8ED),
                width: 1.6,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _open,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                child: Row(
                  children: [
                    if (widget.leading != null) ...[
                      ExcludeSemantics(child: widget.leading!),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: ExcludeSemantics(
                        child: Text(
                          widget.value ?? widget.label,
                          style: TextStyle(
                              fontSize: 16,
                              color: hasError
                                  ? colors.error
                                  : widget.value == null
                                      ? const Color(0xFF667085)
                                      : const Color(0xFF484D51)),
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _isOpen ? 0.5 : 0,
                      duration: appMotionDuration(context),
                      child: const Icon(Icons.keyboard_arrow_down_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: Semantics(
              liveRegion: true,
              child: Text(widget.errorText!,
                  style: TextStyle(color: colors.error, fontSize: 12)),
            ),
          ),
      ],
    );
  }
}
