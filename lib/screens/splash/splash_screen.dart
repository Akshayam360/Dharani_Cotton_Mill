import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../auth/role_selection_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _dotController;

  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;
  late Animation<double> _subtitleFade;
  late Animation<Offset> _subtitleSlide;
  late Animation<double> _bottomFade;

  @override
  void initState() {
    super.initState();

    // Main animation controller
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    // Rotating ring
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    // Logo pulse
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    // Loading dots
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // Logo
    _logoFade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(
        0.0,
        0.30,
        curve: Curves.easeOut,
      ),
    );

    _logoScale = Tween<double>(
      begin: 0.65,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(
          0.0,
          0.35,
          curve: Curves.easeOutBack,
        ),
      ),
    );

    // Main title
    _titleFade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(
        0.25,
        0.55,
        curve: Curves.easeOut,
      ),
    );

    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(
          0.25,
          0.60,
          curve: Curves.easeOutCubic,
        ),
      ),
    );

    // Subtitle
    _subtitleFade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(
        0.45,
        0.75,
        curve: Curves.easeOut,
      ),
    );

    _subtitleSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(
          0.45,
          0.75,
          curve: Curves.easeOutCubic,
        ),
      ),
    );

    // Bottom section
    _bottomFade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(
        0.65,
        1.0,
        curve: Curves.easeOut,
      ),
    );

    _mainController.forward();

    // Navigate after splash
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (!mounted) return;

      Future.delayed(const Duration(milliseconds: 3500), () {
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const RoleSelectionScreen(),
          ),
        );
      });
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _rotationController.dispose();
    _pulseController.dispose();
    _dotController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;

          final isSmall = width < 700;

          return Stack(
            children: [
              // Background
              _buildBackground(width, height),

              // Decorative circles
              _buildDecorations(width, height),

              // Main content
              Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo
                        FadeTransition(
                          opacity: _logoFade,
                          child: ScaleTransition(
                            scale: _logoScale,
                            child: _buildLogo(
                              size: isSmall ? 125 : 155,
                            ),
                          ),
                        ),

                        SizedBox(
                          height: isSmall ? 35 : 42,
                        ),

                        // Company name
                        FadeTransition(
                          opacity: _titleFade,
                          child: SlideTransition(
                            position: _titleSlide,
                            child: _buildCompanyName(
                              isSmall: isSmall,
                            ),
                          ),
                        ),

                        SizedBox(
                          height: isSmall ? 16 : 20,
                        ),

                        // Divider
                        FadeTransition(
                          opacity: _subtitleFade,
                          child: _buildDivider(
                            isSmall: isSmall,
                          ),
                        ),

                        SizedBox(
                          height: isSmall ? 18 : 22,
                        ),

                        // Application name
                        FadeTransition(
                          opacity: _subtitleFade,
                          child: SlideTransition(
                            position: _subtitleSlide,
                            child: _buildApplicationName(
                              isSmall: isSmall,
                            ),
                          ),
                        ),

                        SizedBox(
                          height: isSmall ? 35 : 45,
                        ),

                        // Loading indicator
                        FadeTransition(
                          opacity: _bottomFade,
                          child: _buildLoadingIndicator(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom copyright
              Positioned(
                bottom: 28,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _bottomFade,
                  child: const Text(
                    'DHARANI COTTON MILL',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 2.5,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------
  // BACKGROUND
  // ------------------------------------------------------------

  Widget _buildBackground(double width, double height) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF07111F),
            Color(0xFF0B1628),
            Color(0xFF102746),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // DECORATIVE BACKGROUND
  // ------------------------------------------------------------

  Widget _buildDecorations(double width, double height) {
    return Stack(
      children: [
        // Top-right glow
        Positioned(
          top: -180,
          right: -160,
          child: Container(
            width: 420,
            height: 420,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF1B4D89).withValues(alpha: 0.28),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Bottom-left glow
        Positioned(
          bottom: -220,
          left: -180,
          child: Container(
            width: 480,
            height: 480,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFD9A441).withValues(alpha: 0.12),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Thin diagonal lines
        Positioned.fill(
          child: CustomPaint(
            painter: _BackgroundLinesPainter(),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // LOGO
  // ------------------------------------------------------------

  Widget _buildLogo({
    required double size,
  }) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = 1 + (_pulseController.value * 0.025);

        return Transform.scale(
          scale: pulse,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer rotating ring
                AnimatedBuilder(
                  animation: _rotationController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _rotationController.value * 2 * math.pi,
                      child: CustomPaint(
                        size: Size(size, size),
                        painter: _RotatingRingPainter(),
                      ),
                    );
                  },
                ),

                // Main logo container
                Container(
                  width: size * 0.68,
                  height: size * 0.68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF245FA5),
                        Color(0xFF12365F),
                      ],
                    ),
                    border: Border.all(
                      color: const Color(0xFFD9A441),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1B4D89).withValues(
                          alpha: 0.45,
                        ),
                        blurRadius: 30,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Center(
                    child: _buildCottonMark(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------
  // COTTON MARK
  // ------------------------------------------------------------

  Widget _buildCottonMark() {
    return CustomPaint(
      size: const Size(75, 75),
      painter: _CottonMarkPainter(),
    );
  }

  // ------------------------------------------------------------
  // COMPANY NAME
  // ------------------------------------------------------------

  Widget _buildCompanyName({
    required bool isSmall,
  }) {
    return Column(
      children: [
        Text(
          'DHARANI',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: isSmall ? 34 : 46,
            fontWeight: FontWeight.w800,
            letterSpacing: isSmall ? 8 : 12,
            height: 1,
          ),
        ),

        const SizedBox(height: 12),

        Text(
          'COTTON MILL',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFFD9A441),
            fontSize: isSmall ? 13 : 16,
            fontWeight: FontWeight.w600,
            letterSpacing: isSmall ? 4 : 6,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // DIVIDER
  // ------------------------------------------------------------

  Widget _buildDivider({
    required bool isSmall,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isSmall ? 40 : 65,
          height: 1,
          color: Colors.white24,
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            color: Color(0xFFD9A441),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: isSmall ? 40 : 65,
          height: 1,
          color: Colors.white24,
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // APPLICATION NAME
  // ------------------------------------------------------------

  Widget _buildApplicationName({
    required bool isSmall,
  }) {
    return Column(
      children: [
        Text(
          'SALARY MANAGEMENT SYSTEM',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            fontSize: isSmall ? 11 : 13,
            fontWeight: FontWeight.w500,
            letterSpacing: isSmall ? 2 : 3.5,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'Smart • Secure • Simple',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white38,
            fontSize: isSmall ? 10 : 11,
            fontWeight: FontWeight.w400,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // LOADING INDICATOR
  // ------------------------------------------------------------

  Widget _buildLoadingIndicator() {
    return AnimatedBuilder(
      animation: _dotController,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            3,
                (index) {
              final value = (_dotController.value + index * 0.2) % 1;

              final scale = 0.7 +
                  (math.sin(value * math.pi * 2).abs() * 0.3);

              return Transform.scale(
                scale: scale,
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 4,
                  ),
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD9A441),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ============================================================
// BACKGROUND LINES PAINTER
// ============================================================

class _BackgroundLinesPainter extends CustomPainter {
  @override
  void paint(
      Canvas canvas,
      Size size,
      ) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..strokeWidth = 1;

    const spacing = 80.0;

    for (double x = -size.height; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(
      covariant CustomPainter oldDelegate,
      ) {
    return false;
  }
}

// ============================================================
// ROTATING RING PAINTER
// ============================================================

class _RotatingRingPainter extends CustomPainter {
  @override
  void paint(
      Canvas canvas,
      Size size,
      ) {
    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    final radius = size.width / 2 - 8;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = const SweepGradient(
        colors: [
          Colors.transparent,
          Color(0xFFD9A441),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: center,
          radius: radius,
        ),
      );

    canvas.drawArc(
      Rect.fromCircle(
        center: center,
        radius: radius,
      ),
      0,
      math.pi * 1.25,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(
      covariant CustomPainter oldDelegate,
      ) {
    return false;
  }
}

// ============================================================
// COTTON MARK PAINTER
// ============================================================

class _CottonMarkPainter extends CustomPainter {
  @override
  void paint(
      Canvas canvas,
      Size size,
      ) {
    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Cotton petals
    const petalRadius = 14.0;

    final positions = [
      Offset(0, -13),
      Offset(13, 0),
      Offset(0, 13),
      Offset(-13, 0),
      Offset(9, -9),
      Offset(9, 9),
      Offset(-9, 9),
      Offset(-9, -9),
    ];

    for (final position in positions) {
      canvas.drawCircle(
        center + position,
        petalRadius,
        paint,
      );
    }

    // Center
    final centerPaint = Paint()
      ..color = const Color(0xFFD9A441);

    canvas.drawCircle(
      center,
      9,
      centerPaint,
    );

    // Small center dot
    final dotPaint = Paint()
      ..color = const Color(0xFF8B6421);

    canvas.drawCircle(
      center,
      3,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(
      covariant CustomPainter oldDelegate,
      ) {
    return false;
  }
}