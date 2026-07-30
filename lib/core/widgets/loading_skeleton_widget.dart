import 'package:flutter/material.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';

class LoadingSkeletonWidget extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final int itemCount;

  const LoadingSkeletonWidget({
    super.key,
    this.width = double.infinity,
    this.height = 14,
    this.borderRadius = 8,
    this.itemCount = 1,
  });

  @override
  State<LoadingSkeletonWidget> createState() => _LoadingSkeletonWidgetState();
}

class _LoadingSkeletonWidgetState extends State<LoadingSkeletonWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _animation = Tween<double>(
      begin: -1.5,
      end: 1.5,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).schoolDesk;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                tokens.panelMuted,
                tokens.panelBorder.withAlpha(204),
                tokens.panelMuted,
              ],
              stops: [
                (_animation.value - 0.3).clamp(0.0, 1.0),
                (_animation.value).clamp(0.0, 1.0),
                (_animation.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SkeletonCardWidget extends StatelessWidget {
  const SkeletonCardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).schoolDesk;
    return Container(
      padding: EdgeInsets.all(tokens.spacing.md),
      decoration: BoxDecoration(
        color: tokens.panel,
        borderRadius: BorderRadius.circular(tokens.radius.card),
        border: Border.all(color: tokens.panelBorder, width: 1),
        boxShadow: tokens.elevation.card,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LoadingSkeletonWidget(width: 40, height: 40, borderRadius: 20),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LoadingSkeletonWidget(
                      width: double.infinity,
                      height: 14,
                      borderRadius: 7,
                    ),
                    SizedBox(height: 8),
                    LoadingSkeletonWidget(
                      width: 120,
                      height: 12,
                      borderRadius: 6,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          LoadingSkeletonWidget(
            width: double.infinity,
            height: 12,
            borderRadius: 6,
          ),
          SizedBox(height: 8),
          LoadingSkeletonWidget(width: 180, height: 12, borderRadius: 6),
        ],
      ),
    );
  }
}

class SchoolDeskPageSkeleton extends StatelessWidget {
  final int cardCount;
  final EdgeInsetsGeometry padding;

  const SchoolDeskPageSkeleton({
    super.key,
    this.cardCount = 4,
    this.padding = const EdgeInsets.fromLTRB(22, 18, 22, 28),
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).schoolDesk;
    return Semantics(
      label: 'Loading page content',
      liveRegion: true,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        children: [
          Row(
            children: [
              const LoadingSkeletonWidget(
                width: 52,
                height: 52,
                borderRadius: 16,
              ),
              SizedBox(width: tokens.spacing.compact),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LoadingSkeletonWidget(height: 18, borderRadius: 9),
                    SizedBox(height: 8),
                    LoadingSkeletonWidget(
                      width: 180,
                      height: 12,
                      borderRadius: 6,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900 ? 4 : 2;
              final gap = tokens.spacing.compact;
              final width =
                  (constraints.maxWidth - (gap * (columns - 1))) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: List.generate(
                  cardCount,
                  (_) => SizedBox(
                    width: width,
                    height: 132,
                    child: const SkeletonCardWidget(),
                  ),
                ),
              );
            },
          ),
          SizedBox(height: tokens.spacing.md),
          const LoadingSkeletonWidget(height: 220, borderRadius: 12),
          SizedBox(height: tokens.spacing.md),
          const LoadingSkeletonWidget(height: 148, borderRadius: 12),
        ],
      ),
    );
  }
}
