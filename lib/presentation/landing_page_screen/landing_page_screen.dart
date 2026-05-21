import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';

class LandingPageScreen extends StatefulWidget {
  const LandingPageScreen({super.key});

  @override
  State<LandingPageScreen> createState() => _LandingPageScreenState();
}

class _LandingPageScreenState extends State<LandingPageScreen> {
  static const String _schoolName = 'Public School';
  late final PageController _controller;
  late final List<_LandingSlide> _slides;
  Timer? _autoSlideTimer;
  int _activeSlide = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _slides = const [
      _LandingSlide(
        eyebrow: 'Admissions Open 2026-27',
        title: 'Public School',
        description:
            'A caring public school where academics, character, sports, arts, and digital learning grow together.',
        icon: Icons.school_rounded,
        color: Color(0xFF1B4F72),
        supportColor: Color(0xFF0E8A8A),
        actionLabel: 'Explore School',
        points: ['CBSE-aligned academics', 'Smart classrooms', 'Safe campus'],
        showcaseTitle: 'Admissions desk',
        showcaseSubtitle: 'Enquiry, visit, documents, and admission status.',
        showcaseIcons: [
          Icons.assignment_turned_in_rounded,
          Icons.tour_rounded,
          Icons.badge_rounded,
          Icons.verified_user_rounded,
        ],
        showcaseCards: [
          _ShowcaseCardData(
            icon: Icons.description_rounded,
            title: 'Applications',
            subtitle: 'Track every enquiry',
          ),
          _ShowcaseCardData(
            icon: Icons.event_available_rounded,
            title: 'Campus visits',
            subtitle: 'Plan follow-ups',
          ),
          _ShowcaseCardData(
            icon: Icons.fact_check_rounded,
            title: 'Documents',
            subtitle: 'Ready for review',
          ),
        ],
      ),
      _LandingSlide(
        eyebrow: 'Public School Parent Portal',
        title: 'Everything families need, in one place',
        description:
            'Attendance, fees, circulars, homework, results, notices, transport updates, and support tickets stay connected through one secure app.',
        icon: Icons.dashboard_customize_rounded,
        color: Color(0xFF1E8449),
        supportColor: Color(0xFF1565C0),
        actionLabel: 'View Features',
        points: ['Live attendance', 'Fee tracking', 'Instant notices'],
        showcaseTitle: 'Parent portal',
        showcaseSubtitle: 'Daily school updates connected to each child.',
        showcaseIcons: [
          Icons.how_to_reg_rounded,
          Icons.payments_rounded,
          Icons.campaign_rounded,
          Icons.chat_bubble_rounded,
        ],
        showcaseCards: [
          _ShowcaseCardData(
            icon: Icons.today_rounded,
            title: 'Attendance',
            subtitle: 'Daily visibility',
          ),
          _ShowcaseCardData(
            icon: Icons.receipt_long_rounded,
            title: 'Fees',
            subtitle: 'Dues and receipts',
          ),
          _ShowcaseCardData(
            icon: Icons.notifications_active_rounded,
            title: 'Notices',
            subtitle: 'School circulars',
          ),
        ],
      ),
      _LandingSlide(
        eyebrow: 'Curriculum',
        title: 'Strong foundation from primary to high school',
        description:
            'Balanced learning across Languages, Mathematics, Science, Social Studies, Computer Science, Arts, Physical Education, and value education.',
        icon: Icons.menu_book_rounded,
        color: Color(0xFFD4850A),
        supportColor: Color(0xFF6A5ACD),
        actionLabel: 'See Curriculum',
        points: ['Activity-based learning', 'Practical labs', 'Exam readiness'],
        showcaseTitle: 'Learning plan',
        showcaseSubtitle: 'Subjects, syllabus progress, and assessments.',
        showcaseIcons: [
          Icons.calculate_rounded,
          Icons.science_rounded,
          Icons.language_rounded,
          Icons.psychology_rounded,
        ],
        showcaseCards: [
          _ShowcaseCardData(
            icon: Icons.auto_stories_rounded,
            title: 'Subjects',
            subtitle: 'Balanced academics',
          ),
          _ShowcaseCardData(
            icon: Icons.biotech_rounded,
            title: 'Labs',
            subtitle: 'Practical learning',
          ),
          _ShowcaseCardData(
            icon: Icons.analytics_rounded,
            title: 'Progress',
            subtitle: 'Exam readiness',
          ),
        ],
      ),
      _LandingSlide(
        eyebrow: 'Campus Life',
        title: 'A safe campus built for curiosity',
        description:
            'Students learn through library hours, science labs, sports periods, clubs, assemblies, competitions, and guided mentoring.',
        icon: Icons.diversity_3_rounded,
        color: Color(0xFF1565C0),
        supportColor: Color(0xFF00897B),
        actionLabel: 'Discover Campus',
        points: ['Library & labs', 'Sports and clubs', 'Pastoral care'],
        showcaseTitle: 'Campus rhythm',
        showcaseSubtitle: 'Activities that help students grow beyond class.',
        showcaseIcons: [
          Icons.local_library_rounded,
          Icons.sports_cricket_rounded,
          Icons.palette_rounded,
          Icons.groups_rounded,
        ],
        showcaseCards: [
          _ShowcaseCardData(
            icon: Icons.local_library_rounded,
            title: 'Library',
            subtitle: 'Reading hours',
          ),
          _ShowcaseCardData(
            icon: Icons.sports_soccer_rounded,
            title: 'Sports',
            subtitle: 'Team practice',
          ),
          _ShowcaseCardData(
            icon: Icons.interests_rounded,
            title: 'Clubs',
            subtitle: 'Skills and arts',
          ),
        ],
      ),
      _LandingSlide(
        eyebrow: 'About Us',
        title: 'Education with discipline, care, and opportunity',
        description:
            'Our mission is to help every student become confident, respectful, responsible, and ready for the next stage of learning.',
        icon: Icons.volunteer_activism_rounded,
        color: Color(0xFFC0392B),
        supportColor: Color(0xFF2E7D32),
        actionLabel: 'Know More',
        points: [
          'Experienced teachers',
          'Parent partnership',
          'Transparent operations',
        ],
        showcaseTitle: 'School values',
        showcaseSubtitle: 'Care, discipline, and transparent communication.',
        showcaseIcons: [
          Icons.handshake_rounded,
          Icons.workspace_premium_rounded,
          Icons.family_restroom_rounded,
          Icons.shield_rounded,
        ],
        showcaseCards: [
          _ShowcaseCardData(
            icon: Icons.school_rounded,
            title: 'Mentors',
            subtitle: 'Experienced staff',
          ),
          _ShowcaseCardData(
            icon: Icons.favorite_rounded,
            title: 'Care',
            subtitle: 'Student wellbeing',
          ),
          _ShowcaseCardData(
            icon: Icons.diversity_1_rounded,
            title: 'Parents',
            subtitle: 'Shared progress',
          ),
        ],
      ),
    ];
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (!mounted) return;
      final next = (_activeSlide + 1) % _slides.length;
      _goToSlide(next);
    });
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _goToSlide(int index) {
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final wide = size.width >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(schoolName: _schoolName),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (index) => setState(() => _activeSlide = index),
                itemCount: _slides.length,
                itemBuilder: (context, index) {
                  return _SlideView(
                    slide: _slides[index],
                    schoolName: _schoolName,
                    wide: wide,
                    onLogin: () =>
                        Navigator.pushNamed(context, AppRoutes.principalLogin),
                  );
                },
              ),
            ),
            _BottomControls(
              activeIndex: _activeSlide,
              itemCount: _slides.length,
              onPrevious: () => _goToSlide(
                (_activeSlide - 1 + _slides.length) % _slides.length,
              ),
              onNext: () => _goToSlide((_activeSlide + 1) % _slides.length),
              onDotTap: _goToSlide,
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.schoolName});

  final String schoolName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
      child: Row(
        children: [
          const _LogoMark(size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              schoolName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.onSurface,
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.principalLogin),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.login_rounded, size: 18),
            label: Text(
              'Login',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({
    required this.slide,
    required this.schoolName,
    required this.wide,
    required this.onLogin,
  });

  final _LandingSlide slide;
  final String schoolName;
  final bool wide;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final content = wide
        ? Row(
            children: [
              Expanded(
                flex: 11,
                child: _SlideCopy(slide: slide, onLogin: onLogin),
              ),
              const SizedBox(width: 34),
              Expanded(flex: 9, child: _SchoolShowcase(slide: slide)),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SchoolShowcase(slide: slide),
              const SizedBox(height: 24),
              _SlideCopy(slide: slide, onLogin: onLogin),
            ],
          );

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(wide ? 48 : 18, 12, wide ? 48 : 18, 18),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: content,
        ),
      ),
    );
  }
}

class _SlideCopy extends StatelessWidget {
  const _SlideCopy({required this.slide, required this.onLogin});

  final _LandingSlide slide;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Eyebrow(text: slide.eyebrow, color: slide.color),
        const SizedBox(height: 18),
        Text(
          slide.title,
          style: GoogleFonts.dmSans(
            fontSize: wide ? 42 : 31,
            height: 1.08,
            fontWeight: FontWeight.w800,
            color: AppTheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          slide.description,
          style: GoogleFonts.dmSans(
            fontSize: wide ? 16 : 14,
            height: 1.55,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: slide.points
              .map((point) => _PointPill(text: point, color: slide.color))
              .toList(),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: onLogin,
              icon: const Icon(Icons.lock_open_rounded, size: 18),
              label: const Text('Secure Login'),
            ),
            OutlinedButton.icon(
              onPressed: () {},
              icon: Icon(slide.icon, size: 18),
              label: Text(slide.actionLabel),
            ),
          ],
        ),
      ],
    );
  }
}

class _SchoolShowcase extends StatelessWidget {
  const _SchoolShowcase({required this.slide});

  final _LandingSlide slide;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 430;
        final centerSize = compact ? 170.0 : 188.0;
        final centerPadding = compact ? 14.0 : 16.0;
        final logoSize = compact ? 52.0 : 58.0;
        final centerIconSize = compact ? 48.0 : 58.0;
        return AspectRatio(
          aspectRatio: compact ? 0.78 : 0.92,
          child: TweenAnimationBuilder<double>(
            key: ValueKey(slide.title),
            tween: Tween(begin: 0.92, end: 1),
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeOutBack,
            builder: (context, value, child) =>
                Transform.scale(scale: value, child: child),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    slide.color,
                    Color.lerp(slide.supportColor, Colors.black, 0.14)!,
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: slide.color.withAlpha(70),
                    blurRadius: 28,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _CampusPatternPainter(color: slide.supportColor),
                    ),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white.withAlpha(34)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  _FloatingIcon(
                    icon: slide.showcaseIcons[0],
                    alignment: const Alignment(-0.76, -0.1),
                  ),
                  _FloatingIcon(
                    icon: slide.showcaseIcons[1],
                    alignment: const Alignment(0.76, -0.1),
                  ),
                  _FloatingIcon(
                    icon: slide.showcaseIcons[2],
                    alignment: const Alignment(-0.64, 0.38),
                  ),
                  _FloatingIcon(
                    icon: slide.showcaseIcons[3],
                    alignment: const Alignment(0.64, 0.38),
                  ),
                  Positioned(
                    left: 24,
                    right: 24,
                    top: 24,
                    child: Row(
                      children: [
                        _LogoMark(size: logoSize),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            slide.showcaseTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Center(
                    child: Container(
                      width: centerSize,
                      height: centerSize,
                      padding: EdgeInsets.all(centerPadding),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(242),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(35),
                            blurRadius: 30,
                            offset: const Offset(0, 18),
                          ),
                        ],
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: SizedBox(
                          width: centerSize - (centerPadding * 2),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                slide.icon,
                                size: centerIconSize,
                                color: slide.color,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                slide.showcaseTitle,
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.dmSans(
                                  fontSize: 16,
                                  height: 1.15,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                slide.showcaseSubtitle,
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.dmSans(
                                  fontSize: 10,
                                  height: 1.25,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: compact ? 14 : 20,
                    right: compact ? 14 : 20,
                    bottom: compact ? 16 : 20,
                    child: Row(
                      children: List.generate(slide.showcaseCards.length, (
                        index,
                      ) {
                        final card = slide.showcaseCards[index];
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: index == slide.showcaseCards.length - 1
                                  ? 0
                                  : 10,
                            ),
                            child: _ShowcaseFeatureTile(card: card),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FloatingIcon extends StatelessWidget {
  const _FloatingIcon({required this.icon, required this.alignment});

  final IconData icon;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(42),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withAlpha(72)),
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}

class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.activeIndex,
    required this.itemCount,
    required this.onPrevious,
    required this.onNext,
    required this.onDotTap,
  });

  final int activeIndex;
  final int itemCount;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<int> onDotTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
      child: Row(
        children: [
          IconButton.outlined(
            tooltip: 'Previous',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(itemCount, (index) {
                final selected = activeIndex == index;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => onDotTap(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      width: selected ? 28 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: selected ? AppTheme.primary : AppTheme.outline,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            tooltip: 'Next',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          text,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _PointPill extends StatelessWidget {
  const _PointPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: color.withAlpha(80)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Text(
          text,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _ShowcaseFeatureTile extends StatelessWidget {
  const _ShowcaseFeatureTile({required this.card});

  final _ShowcaseCardData card;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(234),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(card.icon, size: 18, color: AppTheme.primary),
            const SizedBox(height: 5),
            Text(
              card.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppTheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              card.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppTheme.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: SvgPicture.asset(
        'assets/images/img_app_logo.svg',
        fit: BoxFit.contain,
      ),
    );
  }
}

class _CampusPatternPainter extends CustomPainter {
  const _CampusPatternPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    for (var i = 0; i < 7; i++) {
      final top = size.height * (0.12 + i * 0.12);
      canvas.drawLine(Offset(0, top), Offset(size.width, top + 42), paint);
    }
    for (var i = 0; i < 5; i++) {
      final left = size.width * (0.08 + i * 0.2);
      canvas.drawCircle(Offset(left, size.height * 0.5), 44 + i * 12, paint);
    }

    final accentPaint = Paint()
      ..color = color.withAlpha(42)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.08,
          size.height * 0.72,
          size.width * 0.84,
          6,
        ),
        const Radius.circular(8),
      ),
      accentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CampusPatternPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _LandingSlide {
  const _LandingSlide({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.supportColor,
    required this.actionLabel,
    required this.points,
    required this.showcaseTitle,
    required this.showcaseSubtitle,
    required this.showcaseIcons,
    required this.showcaseCards,
  });

  final String eyebrow;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final Color supportColor;
  final String actionLabel;
  final List<String> points;
  final String showcaseTitle;
  final String showcaseSubtitle;
  final List<IconData> showcaseIcons;
  final List<_ShowcaseCardData> showcaseCards;
}

class _ShowcaseCardData {
  const _ShowcaseCardData({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}
