import 'package:flutter/material.dart';

import 'package:schooldesk1/core/desktop/desktop_responsive_breakpoints.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';

/// Resizable side-by-side content panels for desktop workflows.
class DesktopSplitView extends StatefulWidget {
  final Widget left;
  final Widget right;
  final double initialSplit;
  final double minLeftWidth;
  final double minRightWidth;
  final Axis axis;

  const DesktopSplitView({
    super.key,
    required this.left,
    required this.right,
    this.initialSplit = 0.42,
    this.minLeftWidth = 280,
    this.minRightWidth = 320,
    this.axis = Axis.horizontal,
  });

  @override
  State<DesktopSplitView> createState() => _DesktopSplitViewState();
}

class _DesktopSplitViewState extends State<DesktopSplitView> {
  late double _split;

  @override
  void initState() {
    super.initState();
    _split = widget.initialSplit.clamp(0.2, 0.8);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = widget.axis == Axis.horizontal
            ? DesktopBreakpoints.isDesktopWidth(constraints.maxWidth)
            : DesktopBreakpoints.isDesktopWidth(
                MediaQuery.sizeOf(context).width,
              );

        if (!isDesktop) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [widget.left, widget.right],
          );
        }

        final tokens = Theme.of(context).schoolDesk;
        final total = widget.axis == Axis.horizontal
            ? constraints.maxWidth
            : constraints.maxHeight;
        final firstSize = (total * _split)
            .clamp(widget.minLeftWidth, total - widget.minRightWidth);

        if (widget.axis == Axis.vertical) {
          return Column(
            children: [
              SizedBox(height: firstSize, child: widget.left),
              _SplitHandle(
                axis: widget.axis,
                color: tokens.panelBorder,
                onDrag: (delta) => setState(() {
                  _split = ((_split * total + delta) / total).clamp(0.2, 0.8);
                }),
              ),
              Expanded(child: widget.right),
            ],
          );
        }

        return Row(
          children: [
            SizedBox(width: firstSize, child: widget.left),
            _SplitHandle(
              axis: widget.axis,
              color: tokens.panelBorder,
              onDrag: (delta) => setState(() {
                _split = ((_split * total + delta) / total).clamp(0.2, 0.8);
              }),
            ),
            Expanded(child: widget.right),
          ],
        );
      },
    );
  }
}

class _SplitHandle extends StatefulWidget {
  final Axis axis;
  final Color color;
  final ValueChanged<double> onDrag;

  const _SplitHandle({
    required this.axis,
    required this.color,
    required this.onDrag,
  });

  @override
  State<_SplitHandle> createState() => _SplitHandleState();
}

class _SplitHandleState extends State<_SplitHandle> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final isHorizontal = widget.axis == Axis.horizontal;
    final size = isHorizontal ? 6.0 : double.infinity;
    final cross = isHorizontal ? double.infinity : 6.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: isHorizontal
          ? SystemMouseCursors.resizeColumn
          : SystemMouseCursors.resizeRow,
      child: GestureDetector(
        onHorizontalDragUpdate: isHorizontal
            ? (d) => widget.onDrag(d.delta.dx)
            : null,
        onVerticalDragUpdate: !isHorizontal
            ? (d) => widget.onDrag(d.delta.dy)
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: isHorizontal ? size : cross,
          height: isHorizontal ? cross : size,
          color: _hovering
              ? Theme.of(context).colorScheme.primary.withAlpha(80)
              : widget.color,
        ),
      ),
    );
  }
}
