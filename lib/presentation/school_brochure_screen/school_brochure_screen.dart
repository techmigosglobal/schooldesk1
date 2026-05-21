import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

class SchoolBrochureScreen extends StatefulWidget {
  const SchoolBrochureScreen({super.key});

  @override
  State<SchoolBrochureScreen> createState() => _SchoolBrochureScreenState();
}

class _SchoolBrochureScreenState extends State<SchoolBrochureScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Panel expansion state: page -> panel index -> expanded
  final Map<int, int?> _expandedPanel = {0: null, 1: null};

  late AnimationController _shimmerController;
  late AnimationController _floatController;
  late AnimationController _pulseController;
  late Animation<double> _shimmerAnim;
  late Animation<double> _floatAnim;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _shimmerAnim = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
    _floatAnim = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _floatController.dispose();
    _pulseController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _togglePanel(int page, int panelIndex) {
    setState(() {
      if (_expandedPanel[page] == panelIndex) {
        _expandedPanel[page] = null;
      } else {
        _expandedPanel[page] = panelIndex;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Stack(
        children: [
          // Animated background
          _AnimatedBackground(shimmerAnim: _shimmerAnim),
          // Main content
          Column(
            children: [
              _BrochureAppBar(
                currentPage: _currentPage,
                onBack: () => Navigator.pop(context),
                onPageTap: (p) {
                  _pageController.animateToPage(
                    p,
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeInOutCubic,
                  );
                },
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (p) => setState(() => _currentPage = p),
                  children: [
                    _BrochurePage1(
                      expandedPanel: _expandedPanel[0],
                      onTogglePanel: (i) => _togglePanel(0, i),
                      floatAnim: _floatAnim,
                      pulseAnim: _pulseAnim,
                      shimmerAnim: _shimmerAnim,
                    ),
                    _BrochurePage2(
                      expandedPanel: _expandedPanel[1],
                      onTogglePanel: (i) => _togglePanel(1, i),
                      floatAnim: _floatAnim,
                      pulseAnim: _pulseAnim,
                      shimmerAnim: _shimmerAnim,
                    ),
                  ],
                ),
              ),
              _PageIndicator(currentPage: _currentPage),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Animated Background ───────────────────────────────────────────────────

class _AnimatedBackground extends StatelessWidget {
  final Animation<double> shimmerAnim;
  const _AnimatedBackground({required this.shimmerAnim});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shimmerAnim,
      builder: (_, __) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A0E1A),
              Color(0xFF0D1B2A),
              Color(0xFF0A1628),
              Color(0xFF0E0A1A),
            ],
            stops: [0.0, 0.35, 0.65, 1.0],
          ),
        ),
        child: CustomPaint(
          painter: _StarfieldPainter(shimmerAnim.value),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _StarfieldPainter extends CustomPainter {
  final double shimmer;
  _StarfieldPainter(this.shimmer);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);
    final paint = Paint();
    for (int i = 0; i < 80; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = rng.nextDouble() * 1.5 + 0.3;
      final opacity = (math.sin(shimmer * math.pi + i * 0.3) * 0.3 + 0.5).clamp(
        0.1,
        0.9,
      );
      paint.color = Colors.white.withOpacity(opacity * 0.6);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
    // Glowing orbs
    final orbPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);
    orbPaint.color = const Color(0xFF1B4F72).withAlpha(64);
    canvas.drawCircle(
      Offset(size.width * 0.15, size.height * 0.2),
      120,
      orbPaint,
    );
    orbPaint.color = const Color(0xFFD4850A).withAlpha(38);
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.75),
      100,
      orbPaint,
    );
    orbPaint.color = const Color(0xFF1E8449).withAlpha(31);
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.5),
      80,
      orbPaint,
    );
  }

  @override
  bool shouldRepaint(_StarfieldPainter old) => old.shimmer != shimmer;
}

// ─── AppBar ────────────────────────────────────────────────────────────────

class _BrochureAppBar extends StatelessWidget {
  final int currentPage;
  final VoidCallback onBack;
  final ValueChanged<int> onPageTap;

  const _BrochureAppBar({
    required this.currentPage,
    required this.onBack,
    required this.onPageTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
        child: Row(
          children: [
            GestureDetector(
              onTap: onBack,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(26),
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(color: Colors.white.withAlpha(51)),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PUBLIC HIGH SCHOOL',
                    style: GoogleFonts.dmSans(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'School Brochure 2025–26',
                    style: GoogleFonts.dmSans(
                      fontSize: 9.sp,
                      color: const Color(0xFFD4850A),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Page tabs
            Row(
              children: [
                _PageTab(
                  label: 'Page 1',
                  isActive: currentPage == 0,
                  onTap: () => onPageTap(0),
                ),
                SizedBox(width: 2.w),
                _PageTab(
                  label: 'Page 2',
                  isActive: currentPage == 1,
                  onTap: () => onPageTap(1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PageTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _PageTab({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
        decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(
                  colors: [Color(0xFF1B4F72), Color(0xFF2E86C1)],
                )
              : null,
          color: isActive ? null : Colors.white.withAlpha(20),
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: isActive
                ? const Color(0xFF2E86C1)
                : Colors.white.withAlpha(38),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 9.sp,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : Colors.white60,
          ),
        ),
      ),
    );
  }
}

// ─── Page Indicator ────────────────────────────────────────────────────────

class _PageIndicator extends StatelessWidget {
  final int currentPage;
  const _PageIndicator({required this.currentPage});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 2.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Swipe to navigate  ',
            style: GoogleFonts.dmSans(fontSize: 9.sp, color: Colors.white38),
          ),
          ...List.generate(
            2,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: currentPage == i ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4.0),
                gradient: currentPage == i
                    ? const LinearGradient(
                        colors: [Color(0xFF1B4F72), Color(0xFFD4850A)],
                      )
                    : null,
                color: currentPage == i ? null : Colors.white24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── PAGE 1: Identity · Academics · Facilities ────────────────────────────

class _BrochurePage1 extends StatelessWidget {
  final int? expandedPanel;
  final ValueChanged<int> onTogglePanel;
  final Animation<double> floatAnim;
  final Animation<double> pulseAnim;
  final Animation<double> shimmerAnim;

  const _BrochurePage1({
    required this.expandedPanel,
    required this.onTogglePanel,
    required this.floatAnim,
    required this.pulseAnim,
    required this.shimmerAnim,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
      child: Column(
        children: [
          // Page label
          _PageLabel(
            label: 'PAGE 1 OF 2',
            subtitle: 'Identity · Academics · Facilities',
          ),
          SizedBox(height: 1.5.h),
          // Panel 1: School Identity
          _TrisectionalPanel(
            index: 0,
            isExpanded: expandedPanel == 0,
            onToggle: () => onTogglePanel(0),
            accentColor: const Color(0xFF1B4F72),
            accentGradient: const LinearGradient(
              colors: [Color(0xFF0D2137), Color(0xFF1B4F72), Color(0xFF2E86C1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            icon: Icons.school_rounded,
            panelNumber: '01',
            title: 'School Identity',
            subtitle: 'Our Legacy & Vision',
            collapsedContent: _IdentityCollapsed(
              floatAnim: floatAnim,
              pulseAnim: pulseAnim,
              shimmerAnim: shimmerAnim,
            ),
            expandedContent: const _IdentityExpanded(),
          ),
          SizedBox(height: 2.h),
          // Panel 2: Academics
          _TrisectionalPanel(
            index: 1,
            isExpanded: expandedPanel == 1,
            onToggle: () => onTogglePanel(1),
            accentColor: const Color(0xFFD4850A),
            accentGradient: const LinearGradient(
              colors: [Color(0xFF2D1A00), Color(0xFFD4850A), Color(0xFFF5A623)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            icon: Icons.menu_book_rounded,
            panelNumber: '02',
            title: 'Academics',
            subtitle: 'Curriculum & Excellence',
            collapsedContent: const _AcademicsCollapsed(),
            expandedContent: const _AcademicsExpanded(),
          ),
          SizedBox(height: 2.h),
          // Panel 3: Facilities
          _TrisectionalPanel(
            index: 2,
            isExpanded: expandedPanel == 2,
            onToggle: () => onTogglePanel(2),
            accentColor: const Color(0xFF1E8449),
            accentGradient: const LinearGradient(
              colors: [Color(0xFF0A1F12), Color(0xFF1E8449), Color(0xFF27AE60)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            icon: Icons.apartment_rounded,
            panelNumber: '03',
            title: 'Facilities',
            subtitle: 'World-Class Infrastructure',
            collapsedContent: const _FacilitiesCollapsed(),
            expandedContent: const _FacilitiesExpanded(),
          ),
          SizedBox(height: 2.h),
        ],
      ),
    );
  }
}

// ─── PAGE 2: Achievements · Admissions · Contact ──────────────────────────

class _BrochurePage2 extends StatelessWidget {
  final int? expandedPanel;
  final ValueChanged<int> onTogglePanel;
  final Animation<double> floatAnim;
  final Animation<double> pulseAnim;
  final Animation<double> shimmerAnim;

  const _BrochurePage2({
    required this.expandedPanel,
    required this.onTogglePanel,
    required this.floatAnim,
    required this.pulseAnim,
    required this.shimmerAnim,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
      child: Column(
        children: [
          _PageLabel(
            label: 'PAGE 2 OF 2',
            subtitle: 'Achievements · Admissions · Contact',
          ),
          SizedBox(height: 1.5.h),
          // Panel 4: Achievements
          _TrisectionalPanel(
            index: 0,
            isExpanded: expandedPanel == 0,
            onToggle: () => onTogglePanel(0),
            accentColor: const Color(0xFF7D3C98),
            accentGradient: const LinearGradient(
              colors: [Color(0xFF1A0A2E), Color(0xFF7D3C98), Color(0xFFAF7AC5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            icon: Icons.emoji_events_rounded,
            panelNumber: '04',
            title: 'Achievements',
            subtitle: 'Awards & Recognition',
            collapsedContent: _AchievementsCollapsed(pulseAnim: pulseAnim),
            expandedContent: const _AchievementsExpanded(),
          ),
          SizedBox(height: 2.h),
          // Panel 5: Admissions
          _TrisectionalPanel(
            index: 1,
            isExpanded: expandedPanel == 1,
            onToggle: () => onTogglePanel(1),
            accentColor: const Color(0xFFC0392B),
            accentGradient: const LinearGradient(
              colors: [Color(0xFF2D0A08), Color(0xFFC0392B), Color(0xFFE74C3C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            icon: Icons.how_to_reg_rounded,
            panelNumber: '05',
            title: 'Admissions',
            subtitle: 'Join Our Family',
            collapsedContent: const _AdmissionsCollapsed(),
            expandedContent: const _AdmissionsExpanded(),
          ),
          SizedBox(height: 2.h),
          // Panel 6: Contact
          _TrisectionalPanel(
            index: 2,
            isExpanded: expandedPanel == 2,
            onToggle: () => onTogglePanel(2),
            accentColor: const Color(0xFF0E6655),
            accentGradient: const LinearGradient(
              colors: [Color(0xFF041A16), Color(0xFF0E6655), Color(0xFF1ABC9C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            icon: Icons.contact_phone_rounded,
            panelNumber: '06',
            title: 'Contact Us',
            subtitle: 'Reach Out Anytime',
            collapsedContent: const _ContactCollapsed(),
            expandedContent: const _ContactExpanded(),
          ),
          SizedBox(height: 2.h),
          // Footer seal
          _BrochureFooterSeal(shimmerAnim: shimmerAnim),
          SizedBox(height: 2.h),
        ],
      ),
    );
  }
}

// ─── Trisectional Panel (Core Component) ──────────────────────────────────

class _TrisectionalPanel extends StatefulWidget {
  final int index;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Color accentColor;
  final LinearGradient accentGradient;
  final IconData icon;
  final String panelNumber;
  final String title;
  final String subtitle;
  final Widget collapsedContent;
  final Widget expandedContent;

  const _TrisectionalPanel({
    required this.index,
    required this.isExpanded,
    required this.onToggle,
    required this.accentColor,
    required this.accentGradient,
    required this.icon,
    required this.panelNumber,
    required this.title,
    required this.subtitle,
    required this.collapsedContent,
    required this.expandedContent,
  });

  @override
  State<_TrisectionalPanel> createState() => _TrisectionalPanelState();
}

class _TrisectionalPanelState extends State<_TrisectionalPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _expandController;
  late Animation<double> _expandAnim;
  late Animation<double> _rotateAnim;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _expandAnim = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOutCubic,
    );
    _rotateAnim = Tween<double>(begin: 0, end: 0.5).animate(_expandAnim);
  }

  @override
  void didUpdateWidget(_TrisectionalPanel old) {
    super.didUpdateWidget(old);
    if (widget.isExpanded != old.isExpanded) {
      if (widget.isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: widget.isExpanded
                ? widget.accentColor.withAlpha(179)
                : Colors.white.withAlpha(26),
            width: widget.isExpanded ? 1.5 : 1,
          ),
          boxShadow: widget.isExpanded
              ? [
                  BoxShadow(
                    color: widget.accentColor.withAlpha(77),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20.0),
          child: Column(
            children: [
              // Panel header
              Container(
                decoration: BoxDecoration(gradient: widget.accentGradient),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                  child: Row(
                    children: [
                      // Number badge
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(38),
                          borderRadius: BorderRadius.circular(10.0),
                          border: Border.all(color: Colors.white.withAlpha(77)),
                        ),
                        child: Center(
                          child: Text(
                            widget.panelNumber,
                            style: GoogleFonts.dmSans(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 3.w),
                      // Icon
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(38),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(widget.icon, color: Colors.white, size: 18),
                      ),
                      SizedBox(width: 3.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: GoogleFonts.dmSans(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              widget.subtitle,
                              style: GoogleFonts.dmSans(
                                fontSize: 9.sp,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Expand chevron
                      RotationTransition(
                        turns: _rotateAnim,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(38),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Collapsed preview (always visible)
              Container(
                color: const Color(0xFF0D1520),
                child: widget.collapsedContent,
              ),
              // Expanded content
              SizeTransition(
                sizeFactor: _expandAnim,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF0D1520),
                        widget.accentColor.withAlpha(20),
                      ],
                    ),
                  ),
                  child: widget.expandedContent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Page Label ───────────────────────────────────────────────────────────

class _PageLabel extends StatelessWidget {
  final String label;
  final String subtitle;
  const _PageLabel({required this.label, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.6.h),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1B4F72), Color(0xFFD4850A)],
            ),
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 8.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
        ),
        SizedBox(width: 2.w),
        Text(
          subtitle,
          style: GoogleFonts.dmSans(
            fontSize: 9.sp,
            color: Colors.white54,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ─── Panel 1: Identity ────────────────────────────────────────────────────

class _IdentityCollapsed extends StatelessWidget {
  final Animation<double> floatAnim;
  final Animation<double> pulseAnim;
  final Animation<double> shimmerAnim;

  const _IdentityCollapsed({
    required this.floatAnim,
    required this.pulseAnim,
    required this.shimmerAnim,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(3.w),
      child: Row(
        children: [
          // School crest / logo area
          AnimatedBuilder(
            animation: floatAnim,
            builder: (_, __) => Transform.translate(
              offset: Offset(0, floatAnim.value * 0.4),
              child: AnimatedBuilder(
                animation: pulseAnim,
                builder: (_, __) => Transform.scale(
                  scale: pulseAnim.value,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [Color(0xFF2E86C1), Color(0xFF1B4F72)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2E86C1).withAlpha(128),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedBuilder(
                  animation: shimmerAnim,
                  builder: (_, child) => ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: const [
                        Colors.white,
                        Color(0xFFD4850A),
                        Colors.white,
                      ],
                      stops: [
                        (shimmerAnim.value - 0.5).clamp(0.0, 1.0),
                        shimmerAnim.value.clamp(0.0, 1.0),
                        (shimmerAnim.value + 0.5).clamp(0.0, 1.0),
                      ],
                    ).createShader(bounds),
                    child: child!,
                  ),
                  child: Text(
                    'PUBLIC HIGH SCHOOL',
                    style: GoogleFonts.dmSans(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(height: 0.4.h),
                Text(
                  'Est. 2008 · Affiliated to CBSE',
                  style: GoogleFonts.dmSans(
                    fontSize: 9.sp,
                    color: const Color(0xFFD4850A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 0.6.h),
                Text(
                  '"Wisdom, Integrity, Excellence"',
                  style: GoogleFonts.dmSans(
                    fontSize: 9.sp,
                    color: Colors.white60,
                    fontStyle: FontStyle.italic,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentityExpanded extends StatelessWidget {
  const _IdentityExpanded();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(3.w, 0, 3.w, 3.w),
      child: Column(
        children: [
          const Divider(color: Colors.white12, height: 1),
          SizedBox(height: 2.h),
          // Hero image
          ClipRRect(
            borderRadius: BorderRadius.circular(14.0),
            child: Image.network(
              'https://images.pexels.com/photos/1580466/pexels-photo-1580466.jpeg?auto=compress&cs=tinysrgb&w=800',
              height: 18.h,
              width: double.infinity,
              fit: BoxFit.cover,
              semanticLabel:
                  'Grand school building with lush green campus and blue sky',
            ),
          ),
          SizedBox(height: 2.h),
          // Stats row
          Row(
            children: [
              _StatChip(
                value: '640+',
                label: 'Students',
                icon: Icons.people_rounded,
                color: const Color(0xFF2E86C1),
              ),
              SizedBox(width: 2.w),
              _StatChip(
                value: '35',
                label: 'Teachers',
                icon: Icons.person_rounded,
                color: const Color(0xFFD4850A),
              ),
              SizedBox(width: 2.w),
              _StatChip(
                value: '40',
                label: 'Years',
                icon: Icons.history_edu_rounded,
                color: const Color(0xFF1E8449),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          // Vision & Mission
          _InfoCard(
            icon: Icons.visibility_rounded,
            title: 'Our Vision',
            body:
                'To nurture future leaders with academic brilliance, moral integrity, and a spirit of innovation — shaping citizens who contribute meaningfully to society.',
            accentColor: const Color(0xFF2E86C1),
          ),
          SizedBox(height: 1.5.h),
          _InfoCard(
            icon: Icons.flag_rounded,
            title: 'Our Mission',
            body:
                'Deliver holistic education through experienced faculty, modern infrastructure, and a value-based curriculum aligned with CBSE standards.',
            accentColor: const Color(0xFFD4850A),
          ),
          SizedBox(height: 1.5.h),
          // Principal quote
          Container(
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1B4F72).withAlpha(77),
                  const Color(0xFF2E86C1).withAlpha(26),
                ],
              ),
              borderRadius: BorderRadius.circular(14.0),
              border: Border.all(color: const Color(0xFF2E86C1).withAlpha(77)),
            ),
            child: Row(
              children: [
                ClipOval(
                  child: Image.network(
                    'https://images.pexels.com/photos/3184405/pexels-photo-3184405.jpeg?auto=compress&cs=tinysrgb&w=200',
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    semanticLabel: 'School principal portrait in formal attire',
                  ),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '"Education is the most powerful weapon to change the world."',
                        style: GoogleFonts.dmSans(
                          fontSize: 9.sp,
                          color: Colors.white70,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 0.4.h),
                      Text(
                        '— Principal',
                        style: GoogleFonts.dmSans(
                          fontSize: 8.sp,
                          color: const Color(0xFFD4850A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Panel 2: Academics ───────────────────────────────────────────────────

class _AcademicsCollapsed extends StatelessWidget {
  const _AcademicsCollapsed();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(3.w),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CBSE Curriculum',
                  style: GoogleFonts.dmSans(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 0.5.h),
                Text(
                  'Classes I–XII · Science, Commerce & Arts',
                  style: GoogleFonts.dmSans(
                    fontSize: 9.sp,
                    color: Colors.white60,
                  ),
                ),
                SizedBox(height: 1.h),
                Wrap(
                  spacing: 1.5.w,
                  runSpacing: 0.5.h,
                  children: ['Science', 'Commerce', 'Arts', 'Vocational']
                      .map(
                        (s) =>
                            _MiniChip(label: s, color: const Color(0xFFD4850A)),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFD4850A), Color(0xFFF5A623)],
              ),
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Column(
              children: [
                Text(
                  'A+',
                  style: GoogleFonts.dmSans(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'NAAC Grade',
                  style: GoogleFonts.dmSans(
                    fontSize: 7.sp,
                    color: Colors.white.withAlpha(204),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AcademicsExpanded extends StatelessWidget {
  const _AcademicsExpanded();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(3.w, 0, 3.w, 3.w),
      child: Column(
        children: [
          const Divider(color: Colors.white12, height: 1),
          SizedBox(height: 2.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(14.0),
            child: Image.network(
              'https://images.pexels.com/photos/256395/pexels-photo-256395.jpeg?auto=compress&cs=tinysrgb&w=800',
              height: 15.h,
              width: double.infinity,
              fit: BoxFit.cover,
              semanticLabel:
                  'Students studying in a bright modern classroom with books and laptops',
            ),
          ),
          SizedBox(height: 2.h),
          // Streams
          Row(
            children: [
              Expanded(
                child: _StreamCard(
                  stream: 'Science',
                  subjects: 'Physics · Chemistry · Biology · Maths',
                  color: const Color(0xFF2E86C1),
                  icon: Icons.science_rounded,
                ),
              ),
              SizedBox(width: 2.w),
              Expanded(
                child: _StreamCard(
                  stream: 'Commerce',
                  subjects: 'Accounts · Economics · Business Studies',
                  color: const Color(0xFFD4850A),
                  icon: Icons.bar_chart_rounded,
                ),
              ),
            ],
          ),
          SizedBox(height: 1.5.h),
          Row(
            children: [
              Expanded(
                child: _StreamCard(
                  stream: 'Arts',
                  subjects: 'History · Geography · Political Science',
                  color: const Color(0xFF7D3C98),
                  icon: Icons.palette_rounded,
                ),
              ),
              SizedBox(width: 2.w),
              Expanded(
                child: _StreamCard(
                  stream: 'Vocational',
                  subjects: 'IT · Retail · Healthcare · Tourism',
                  color: const Color(0xFF1E8449),
                  icon: Icons.work_rounded,
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          _InfoCard(
            icon: Icons.trending_up_rounded,
            title: 'Board Results 2024–25',
            body:
                '98.4% pass rate in Class XII · 12 students scored above 95% · Top performer: 99.2% aggregate in Science stream.',
            accentColor: const Color(0xFFD4850A),
          ),
          SizedBox(height: 1.5.h),
          // Extra-curricular
          _InfoCard(
            icon: Icons.extension_rounded,
            title: 'Beyond Academics',
            body:
                'Robotics Club · Debate Society · Music & Dance · NCC · NSS · Sports Academy · Art Studio · STEM Lab',
            accentColor: const Color(0xFF1E8449),
          ),
        ],
      ),
    );
  }
}

// ─── Panel 3: Facilities ──────────────────────────────────────────────────

class _FacilitiesCollapsed extends StatelessWidget {
  const _FacilitiesCollapsed();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(3.w),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'World-Class Campus',
                  style: GoogleFonts.dmSans(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 0.5.h),
                Text(
                  '5-acre campus with modern amenities',
                  style: GoogleFonts.dmSans(
                    fontSize: 9.sp,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 2.w),
          // Facility icons row
          Row(
            children: [
              _FacilityIcon(icon: Icons.computer_rounded, label: 'Lab'),
              SizedBox(width: 1.5.w),
              _FacilityIcon(
                icon: Icons.sports_basketball_rounded,
                label: 'Sports',
              ),
              SizedBox(width: 1.5.w),
              _FacilityIcon(
                icon: Icons.local_library_rounded,
                label: 'Library',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FacilitiesExpanded extends StatelessWidget {
  const _FacilitiesExpanded();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(3.w, 0, 3.w, 3.w),
      child: Column(
        children: [
          const Divider(color: Colors.white12, height: 1),
          SizedBox(height: 2.h),
          // Facility image grid
          Row(
            children: [
              Expanded(
                flex: 2,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12.0),
                  child: Image.network(
                    'https://images.pexels.com/photos/1181406/pexels-photo-1181406.jpeg?auto=compress&cs=tinysrgb&w=600',
                    height: 16.h,
                    fit: BoxFit.cover,
                    semanticLabel:
                        'Modern computer lab with rows of desktop computers and students working',
                  ),
                ),
              ),
              SizedBox(width: 2.w),
              Expanded(
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12.0),
                      child: Image.network(
                        'https://images.pexels.com/photos/863988/pexels-photo-863988.jpeg?auto=compress&cs=tinysrgb&w=400',
                        height: 7.h,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        semanticLabel:
                            'School library with shelves full of colorful books',
                      ),
                    ),
                    SizedBox(height: 1.h),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12.0),
                      child: Image.network(
                        'https://images.pexels.com/photos/863988/pexels-photo-863988.jpeg?auto=compress&cs=tinysrgb&w=400',
                        height: 7.h,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        semanticLabel:
                            'School sports ground with running track and green field',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          // Facility list
          Wrap(
            spacing: 2.w,
            runSpacing: 1.h,
            children: [
              _FacilityBadge(
                icon: Icons.computer_rounded,
                label: 'Smart Classrooms',
                color: const Color(0xFF1E8449),
              ),
              _FacilityBadge(
                icon: Icons.science_rounded,
                label: 'Science Labs',
                color: const Color(0xFF2E86C1),
              ),
              _FacilityBadge(
                icon: Icons.local_library_rounded,
                label: 'Digital Library',
                color: const Color(0xFFD4850A),
              ),
              _FacilityBadge(
                icon: Icons.sports_soccer_rounded,
                label: 'Sports Complex',
                color: const Color(0xFF7D3C98),
              ),
              _FacilityBadge(
                icon: Icons.restaurant_rounded,
                label: 'Cafeteria',
                color: const Color(0xFFC0392B),
              ),
              _FacilityBadge(
                icon: Icons.directions_bus_rounded,
                label: 'School Bus',
                color: const Color(0xFF0E6655),
              ),
              _FacilityBadge(
                icon: Icons.medical_services_rounded,
                label: 'Medical Room',
                color: const Color(0xFF1B4F72),
              ),
              _FacilityBadge(
                icon: Icons.wifi_rounded,
                label: 'Campus Wi-Fi',
                color: const Color(0xFF1E8449),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Panel 4: Achievements ────────────────────────────────────────────────

class _AchievementsCollapsed extends StatelessWidget {
  final Animation<double> pulseAnim;
  const _AchievementsCollapsed({required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(3.w),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: pulseAnim,
            builder: (_, __) => Transform.scale(
              scale: pulseAnim.value,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const RadialGradient(
                    colors: [Color(0xFFAF7AC5), Color(0xFF7D3C98)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7D3C98).withAlpha(128),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '150+ Awards',
                  style: GoogleFonts.dmSans(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'National · State · District level recognition',
                  style: GoogleFonts.dmSans(
                    fontSize: 9.sp,
                    color: Colors.white60,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementsExpanded extends StatelessWidget {
  const _AchievementsExpanded();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(3.w, 0, 3.w, 3.w),
      child: Column(
        children: [
          const Divider(color: Colors.white12, height: 1),
          SizedBox(height: 2.h),
          // Trophy showcase
          Row(
            children: [
              _TrophyCard(
                year: '2025',
                title: 'Best School Award',
                body: 'State Education Board',
                color: const Color(0xFFD4850A),
                icon: Icons.emoji_events_rounded,
              ),
              SizedBox(width: 2.w),
              _TrophyCard(
                year: '2024',
                title: 'CBSE Excellence',
                body: 'National Level',
                color: const Color(0xFF7D3C98),
                icon: Icons.star_rounded,
              ),
              SizedBox(width: 2.w),
              _TrophyCard(
                year: '2024',
                title: 'Green School',
                body: 'Eco-Friendly Campus',
                color: const Color(0xFF1E8449),
                icon: Icons.eco_rounded,
              ),
            ],
          ),
          SizedBox(height: 2.h),
          _InfoCard(
            icon: Icons.sports_rounded,
            title: 'Sports Achievements',
            body:
                'State Champions in Football & Basketball 2024 · 3 students selected for National Athletics · Inter-school Chess Champions 2025',
            accentColor: const Color(0xFF7D3C98),
          ),
          SizedBox(height: 1.5.h),
          _InfoCard(
            icon: Icons.science_rounded,
            title: 'Academic Olympiads',
            body:
                '8 Gold medals in Science Olympiad · 5 students in NTSE Stage II · 2 students in KVPY scholarship 2024–25',
            accentColor: const Color(0xFFD4850A),
          ),
          SizedBox(height: 1.5.h),
          // Notable alumni
          Container(
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: const Color(0xFF7D3C98).withAlpha(26),
              borderRadius: BorderRadius.circular(14.0),
              border: Border.all(color: const Color(0xFF7D3C98).withAlpha(77)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.people_alt_rounded,
                      color: Color(0xFFAF7AC5),
                      size: 16,
                    ),
                    SizedBox(width: 2.w),
                    Text(
                      'Notable Alumni',
                      style: GoogleFonts.dmSans(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 1.h),
                Wrap(
                  spacing: 2.w,
                  runSpacing: 0.8.h,
                  children: [
                    'Alumni record — Higher education',
                    'Alumni record — Civil services',
                    'Alumni record — Research',
                    'Alumni record — Sports',
                  ].map((a) => _AlumniChip(name: a)).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Panel 5: Admissions ──────────────────────────────────────────────────

class _AdmissionsCollapsed extends StatelessWidget {
  const _AdmissionsCollapsed();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(3.w),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admissions Open',
                  style: GoogleFonts.dmSans(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 0.4.h),
                Text(
                  'Academic Year 2025–26',
                  style: GoogleFonts.dmSans(
                    fontSize: 9.sp,
                    color: Colors.white60,
                  ),
                ),
                SizedBox(height: 0.8.h),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 2.w,
                    vertical: 0.4.h,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC0392B).withAlpha(51),
                    borderRadius: BorderRadius.circular(6.0),
                    border: Border.all(
                      color: const Color(0xFFC0392B).withAlpha(128),
                    ),
                  ),
                  child: Text(
                    '⏰ Last Date: 31 May 2025',
                    style: GoogleFonts.dmSans(
                      fontSize: 8.sp,
                      color: const Color(0xFFE74C3C),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(2.w),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFC0392B), Color(0xFFE74C3C)],
              ),
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.how_to_reg_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                SizedBox(height: 0.4.h),
                Text(
                  'Apply\nNow',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 8.sp,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdmissionsExpanded extends StatelessWidget {
  const _AdmissionsExpanded();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(3.w, 0, 3.w, 3.w),
      child: Column(
        children: [
          const Divider(color: Colors.white12, height: 1),
          SizedBox(height: 2.h),
          // Process steps
          _ProcessStep(
            step: '01',
            title: 'Download Prospectus',
            desc: 'Visit our website or collect from the school office',
            color: const Color(0xFFC0392B),
          ),
          _ProcessStep(
            step: '02',
            title: 'Fill Application Form',
            desc: 'Online or offline form with required documents',
            color: const Color(0xFFD4850A),
          ),
          _ProcessStep(
            step: '03',
            title: 'Entrance Assessment',
            desc: 'Class-specific aptitude test (Classes VI–XII)',
            color: const Color(0xFF7D3C98),
          ),
          _ProcessStep(
            step: '04',
            title: 'Interview & Admission',
            desc: 'Parent-student interaction with Principal',
            color: const Color(0xFF1E8449),
          ),
          SizedBox(height: 2.h),
          // Fee structure
          Container(
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFC0392B).withAlpha(38),
                  const Color(0xFFC0392B).withAlpha(13),
                ],
              ),
              borderRadius: BorderRadius.circular(14.0),
              border: Border.all(color: const Color(0xFFC0392B).withAlpha(77)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fee Structure 2025–26',
                  style: GoogleFonts.dmSans(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 1.h),
                _FeeRow(label: 'Classes I–V', amount: 'Backend configured'),
                _FeeRow(label: 'Classes VI–VIII', amount: 'Backend configured'),
                _FeeRow(label: 'Classes IX–X', amount: 'Backend configured'),
                _FeeRow(label: 'Classes XI–XII', amount: 'Backend configured'),
              ],
            ),
          ),
          SizedBox(height: 1.5.h),
          _InfoCard(
            icon: Icons.card_giftcard_rounded,
            title: 'Scholarships Available',
            body:
                'Merit scholarships for top 5% students · Need-based fee waiver up to 100% · Sports quota · Sibling discount 10%',
            accentColor: const Color(0xFFC0392B),
          ),
        ],
      ),
    );
  }
}

// ─── Panel 6: Contact ─────────────────────────────────────────────────────

class _ContactCollapsed extends StatelessWidget {
  const _ContactCollapsed();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(3.w),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Get In Touch',
                  style: GoogleFonts.dmSans(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 0.5.h),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: Color(0xFF1ABC9C),
                      size: 14,
                    ),
                    SizedBox(width: 1.w),
                    Expanded(
                      child: Text(
                        '14, School Road, Sector 5, New Delhi – 110001',
                        style: GoogleFonts.dmSans(
                          fontSize: 8.sp,
                          color: Colors.white60,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 0.4.h),
                Row(
                  children: [
                    const Icon(
                      Icons.phone_rounded,
                      color: Color(0xFF1ABC9C),
                      size: 14,
                    ),
                    SizedBox(width: 1.w),
                    Text(
                      '+91 11 2345 6789',
                      style: GoogleFonts.dmSans(
                        fontSize: 8.sp,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0E6655), Color(0xFF1ABC9C)],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.contact_phone_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactExpanded extends StatelessWidget {
  const _ContactExpanded();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(3.w, 0, 3.w, 3.w),
      child: Column(
        children: [
          const Divider(color: Colors.white12, height: 1),
          SizedBox(height: 2.h),
          // Map placeholder
          ClipRRect(
            borderRadius: BorderRadius.circular(14.0),
            child: Image.network(
              'https://images.pexels.com/photos/1036808/pexels-photo-1036808.jpeg?auto=compress&cs=tinysrgb&w=800',
              height: 14.h,
              width: double.infinity,
              fit: BoxFit.cover,
              semanticLabel:
                  'Aerial view of school campus surrounded by trees and roads',
            ),
          ),
          SizedBox(height: 2.h),
          // Contact details
          _ContactRow(
            icon: Icons.location_on_rounded,
            label: 'Address',
            value: '14, School Road, Sector 5, New Delhi – 110001',
            color: const Color(0xFF1ABC9C),
          ),
          SizedBox(height: 1.h),
          _ContactRow(
            icon: Icons.phone_rounded,
            label: 'Phone',
            value: '+91 11 2345 6789 · +91 98765 43210',
            color: const Color(0xFF1ABC9C),
          ),
          SizedBox(height: 1.h),
          _ContactRow(
            icon: Icons.email_rounded,
            label: 'Email',
            value: 'info@greenfieldhorizon.edu.in',
            color: const Color(0xFF1ABC9C),
          ),
          SizedBox(height: 1.h),
          _ContactRow(
            icon: Icons.language_rounded,
            label: 'Website',
            value: 'www.greenfieldhorizon.edu.in',
            color: const Color(0xFF1ABC9C),
          ),
          SizedBox(height: 1.h),
          _ContactRow(
            icon: Icons.access_time_rounded,
            label: 'Office Hours',
            value: 'Mon–Sat: 8:00 AM – 4:00 PM',
            color: const Color(0xFF1ABC9C),
          ),
          SizedBox(height: 2.h),
          // Social media
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SocialButton(
                icon: Icons.facebook_rounded,
                label: 'Facebook',
                color: const Color(0xFF1877F2),
              ),
              SizedBox(width: 3.w),
              _SocialButton(
                icon: Icons.camera_alt_rounded,
                label: 'Instagram',
                color: const Color(0xFFE1306C),
              ),
              SizedBox(width: 3.w),
              _SocialButton(
                icon: Icons.play_circle_rounded,
                label: 'YouTube',
                color: const Color(0xFFFF0000),
              ),
              SizedBox(width: 3.w),
              _SocialButton(
                icon: Icons.chat_rounded,
                label: 'WhatsApp',
                color: const Color(0xFF25D366),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Footer Seal ──────────────────────────────────────────────────────────

class _BrochureFooterSeal extends StatelessWidget {
  final Animation<double> shimmerAnim;
  const _BrochureFooterSeal({required this.shimmerAnim});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shimmerAnim,
      builder: (_, __) => Container(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF1B4F72).withAlpha(77),
              const Color(0xFFD4850A).withAlpha(51),
              const Color(0xFF1E8449).withAlpha(51),
            ],
          ),
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(color: Colors.white.withAlpha(26)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [Color(0xFF2E86C1), Color(0xFF1B4F72)],
                ),
              ),
              child: const Icon(
                Icons.school_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            SizedBox(width: 3.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      Color(0xFF2E86C1),
                      Color(0xFFD4850A),
                      Color(0xFF1E8449),
                    ],
                  ).createShader(bounds),
                  child: Text(
                    'PUBLIC HIGH SCHOOL',
                    style: GoogleFonts.dmSans(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Text(
                  'Shaping Curious Minds for Tomorrow',
                  style: GoogleFonts.dmSans(
                    fontSize: 8.sp,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Reusable Sub-Widgets ─────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatChip({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 1.2.h),
        decoration: BoxDecoration(
          color: color.withAlpha(31),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: color.withAlpha(77)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            SizedBox(height: 0.4.h),
            Text(
              value,
              style: GoogleFonts.dmSans(
                fontSize: 12.sp,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.dmSans(fontSize: 7.sp, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color accentColor;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: accentColor.withAlpha(20),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: accentColor.withAlpha(64)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accentColor.withAlpha(51),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Icon(icon, color: accentColor, size: 16),
          ),
          SizedBox(width: 2.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.dmSans(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 0.3.h),
                Text(
                  body,
                  style: GoogleFonts.dmSans(
                    fontSize: 8.5.sp,
                    color: Colors.white60,
                    height: 1.5,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.3.h),
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: color.withAlpha(102)),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 8.sp,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FacilityIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FacilityIcon({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E8449).withAlpha(51),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF1E8449).withAlpha(102)),
          ),
          child: Icon(icon, color: const Color(0xFF27AE60), size: 16),
        ),
        SizedBox(height: 0.3.h),
        Text(
          label,
          style: GoogleFonts.dmSans(fontSize: 7.sp, color: Colors.white54),
        ),
      ],
    );
  }
}

class _FacilityBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _FacilityBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 0.8.h),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          SizedBox(width: 1.w),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 8.sp,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StreamCard extends StatelessWidget {
  final String stream;
  final String subjects;
  final Color color;
  final IconData icon;
  const _StreamCard({
    required this.stream,
    required this.subjects,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(2.5.w),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              SizedBox(width: 1.5.w),
              Text(
                stream,
                style: GoogleFonts.dmSans(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 0.5.h),
          Text(
            subjects,
            style: GoogleFonts.dmSans(
              fontSize: 7.5.sp,
              color: Colors.white54,
              height: 1.4,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _TrophyCard extends StatelessWidget {
  final String year;
  final String title;
  final String body;
  final Color color;
  final IconData icon;
  const _TrophyCard({
    required this.year,
    required this.title,
    required this.body,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(2.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withAlpha(51), color.withAlpha(13)],
          ),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: color.withAlpha(102)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            SizedBox(height: 0.4.h),
            Text(
              year,
              style: GoogleFonts.dmSans(
                fontSize: 7.sp,
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 0.2.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 8.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 0.2.h),
            Text(
              body,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 7.sp, color: Colors.white54),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProcessStep extends StatelessWidget {
  final String step;
  final String title;
  final String desc;
  final Color color;
  const _ProcessStep({
    required this.step,
    required this.title,
    required this.desc,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 1.2.h),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, color.withAlpha(153)]),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step,
                style: GoogleFonts.dmSans(
                  fontSize: 8.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.dmSans(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  desc,
                  style: GoogleFonts.dmSans(
                    fontSize: 8.5.sp,
                    color: Colors.white54,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeeRow extends StatelessWidget {
  final String label;
  final String amount;
  const _FeeRow({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 0.6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(fontSize: 9.sp, color: Colors.white70),
          ),
          Text(
            amount,
            style: GoogleFonts.dmSans(
              fontSize: 9.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFE74C3C),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withAlpha(38),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        SizedBox(width: 2.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 8.sp,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.dmSans(
                  fontSize: 9.sp,
                  color: Colors.white70,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SocialButton({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withAlpha(38),
            shape: BoxShape.circle,
            border: Border.all(color: color.withAlpha(102)),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        SizedBox(height: 0.4.h),
        Text(
          label,
          style: GoogleFonts.dmSans(fontSize: 7.sp, color: Colors.white54),
        ),
      ],
    );
  }
}

class _AlumniChip extends StatelessWidget {
  final String name;
  const _AlumniChip({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.4.h),
      decoration: BoxDecoration(
        color: const Color(0xFF7D3C98).withAlpha(38),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: const Color(0xFF7D3C98).withAlpha(77)),
      ),
      child: Text(
        name,
        style: GoogleFonts.dmSans(fontSize: 8.sp, color: Colors.white70),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
