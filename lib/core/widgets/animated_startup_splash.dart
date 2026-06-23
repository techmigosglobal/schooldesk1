import 'package:flutter/material.dart';

class AnimatedStartupSplash extends StatefulWidget {
  const AnimatedStartupSplash({
    super.key,
    required this.child,
    this.animationDuration = const Duration(milliseconds: 1550),
  });

  static const overlayKey = ValueKey('animated-startup-splash-overlay');
  static const logoKey = ValueKey('animated-startup-splash-logo');

  final Widget child;
  final Duration animationDuration;

  @override
  State<AnimatedStartupSplash> createState() => _AnimatedStartupSplashState();
}

class _AnimatedStartupSplashState extends State<AnimatedStartupSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.84,
          end: 1.14,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 42,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.14,
          end: 0.98,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 36,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.98,
          end: 1.02,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 22,
      ),
    ]).animate(_controller);
    _opacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 1).chain(
          CurveTween(curve: const Interval(0, 0.24, curve: Curves.easeOut)),
        ),
        weight: 42,
      ),
      TweenSequenceItem(tween: ConstantTween(1), weight: 28),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 0).chain(
          CurveTween(curve: const Interval(0.70, 1, curve: Curves.easeIn)),
        ),
        weight: 30,
      ),
    ]).animate(_controller);
    _controller.forward().whenComplete(() {
      if (mounted) {
        setState(() => _visible = false);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_visible)
          IgnorePointer(
            key: AnimatedStartupSplash.overlayKey,
            child: RepaintBoundary(
              child: DecoratedBox(
                decoration: const BoxDecoration(color: Colors.white),
                child: Center(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _opacity.value.clamp(0, 1),
                        child: Transform.scale(
                          scale: _scale.value,
                          child: child,
                        ),
                      );
                    },
                    child: Image.asset(
                      'assets/branding/ArishVilleLogo.png',
                      key: AnimatedStartupSplash.logoKey,
                      width: 168,
                      height: 168,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
