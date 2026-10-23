import 'package:flutter/material.dart';
import '../core/app_interactions.dart';

/// Shared field errors and first-error navigation for resident and office forms.
mixin FormFeedback<T extends StatefulWidget> on State<T> {
  final Map<String, GlobalKey> _anchors = {};
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, String> _errors = {};
  final Map<TextEditingController, VoidCallback> _listeners = {};

  GlobalKey fieldAnchor(String id) =>
      _anchors.putIfAbsent(id, () => GlobalKey());
  FocusNode fieldFocus(String id, [TextEditingController? controller]) {
    if (controller != null) watchField(id, controller);
    return _focusNodes.putIfAbsent(id, () => FocusNode());
  }

  String? fieldError(String id) => _errors[id];
  void recordFieldError(String id, String? error) {
    if (error == null) {
      _errors.remove(id);
    } else {
      _errors[id] = error;
    }
  }

  void clearFieldError(String id) {
    if (_errors.containsKey(id) && mounted) setState(() => _errors.remove(id));
  }

  void watchField(String id, TextEditingController controller) {
    if (_listeners.containsKey(controller)) return;
    var previousText = controller.text;
    void changed() {
      if (controller.text == previousText) return;
      previousText = controller.text;
      clearFieldError(id);
    }

    _listeners[controller] = changed;
    controller.addListener(changed);
  }

  InputDecoration decorateField(String id, InputDecoration decoration) =>
      decoration.copyWith(errorText: fieldError(id), errorMaxLines: 3);

  bool validateFields(Map<String, String?> errors) {
    setState(() {
      _errors.clear();
      for (final entry in errors.entries) {
        if (entry.value != null) _errors[entry.key] = entry.value!;
      }
    });
    if (_errors.isNotEmpty) revealFirstError();
    return _errors.isEmpty;
  }

  void revealFirstError() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final keys = _errors.keys
          .where((id) => _anchors[id]?.currentContext != null)
          .toList();
      keys.sort((a, b) {
        double top(String id) {
          final box = _anchors[id]!.currentContext!.findRenderObject();
          return box is RenderBox && box.hasSize
              ? box.localToGlobal(Offset.zero).dy
              : double.infinity;
        }

        return top(a).compareTo(top(b));
      });
      if (keys.isNotEmpty) _revealField(keys.first);
    });
  }

  void revealField(String id) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealField(id));
  }

  void _revealField(String id) {
    if (!mounted) return;
    final target = _anchors[id]?.currentContext;
    if (target == null) return;
    final node = _focusNodes[id];
    if (node != null) {
      node.requestFocus();
    } else {
      FocusScope.of(context).unfocus();
    }
    Scrollable.ensureVisible(target,
        alignment: .15,
        duration: appMotionDuration(context),
        curve: Curves.easeOut);
  }

  Widget fieldWarning(String id) => fieldError(id) == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 8),
          child: Semantics(
              liveRegion: true,
              child: Text(fieldError(id)!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 14))));

  @override
  void dispose() {
    for (final entry in _listeners.entries) {
      entry.key.removeListener(entry.value);
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }
}
