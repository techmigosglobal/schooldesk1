import 'package:flutter/widgets.dart';
import 'package:schooldesk1/core/services/mobile_loading_trace.dart';

/// Marks the first usable role landing frame and exposes a stable test finder.
class RoleHomeReady extends StatefulWidget {
  const RoleHomeReady({required this.role, required this.child, super.key});

  static ValueKey<String> keyForRole(String role) {
    return ValueKey('role-home-ready-$role');
  }

  final String role;
  final Widget child;

  @override
  State<RoleHomeReady> createState() => _RoleHomeReadyState();
}

class _RoleHomeReadyState extends State<RoleHomeReady> {
  @override
  void initState() {
    super.initState();
    if (MobileLoadingTrace.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          MobileLoadingTrace.mark(
            'schooldesk.role_home_ready',
            arguments: {'role': widget.role},
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: RoleHomeReady.keyForRole(widget.role),
      child: widget.child,
    );
  }
}
