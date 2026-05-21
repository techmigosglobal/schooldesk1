import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../routes/schooldesk_screen_registry.dart';
import '../theme/design_tokens.dart';

class SchoolDeskRouteFrame extends StatefulWidget {
  final SchoolDeskScreenMetadata metadata;
  final Widget child;

  const SchoolDeskRouteFrame({
    super.key,
    required this.metadata,
    required this.child,
  });

  @override
  State<SchoolDeskRouteFrame> createState() => _SchoolDeskRouteFrameState();
}

class _SchoolDeskRouteFrameState extends State<SchoolDeskRouteFrame> {
  DateTime? _lastBackPressedAt;

  bool get _canExitOnBack {
    if (widget.metadata.isPublic) return true;
    return Navigator.of(context).canPop();
  }

  void _handleBackWithoutPop() {
    if (widget.metadata.isPublic) return;
    final now = DateTime.now();
    final last = _lastBackPressedAt;
    if (last != null && now.difference(last) <= const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }

    _lastBackPressedAt = now;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit SchoolDesk'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).schoolDesk;
    return PopScope(
      canPop: _canExitOnBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBackWithoutPop();
      },
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: Semantics(
          label: widget.metadata.semanticLabel,
          container: true,
          explicitChildNodes: true,
          child: DecoratedBox(
            decoration: BoxDecoration(color: tokens.pageBackground),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
