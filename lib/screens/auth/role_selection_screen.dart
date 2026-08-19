import 'package:flutter/material.dart';
import 'login_screen.dart';


enum UserRole {
  staff,
  labour,
  md,
  exempted,
}

extension UserRoleX on UserRole {
  String get label {
    switch (this) {
      case UserRole.staff:
        return 'Staff';
      case UserRole.labour:
        return 'Labour';
      case UserRole.md:
        return 'MD';
      case UserRole.exempted:
        return 'Exempted';
    }
  }

  String get subtitle {
    switch (this) {
      case UserRole.staff:
        return 'Salary & attendance';
      case UserRole.labour:
        return 'Wages & work log';
      case UserRole.md:
        return 'Manage & approve';
      case UserRole.exempted:
        return 'Special access';
    }
  }

  IconData get icon {
    switch (this) {
      case UserRole.staff:
        return Icons.badge_outlined;
      case UserRole.labour:
        return Icons.engineering_outlined;
      case UserRole.md:
        return Icons.admin_panel_settings_outlined;
      case UserRole.exempted:
        return Icons.verified_user_outlined;
    }
  }

  Color get color {
    switch (this) {
      case UserRole.staff:
        return const Color(0xFF4E342E);
      case UserRole.labour:
        return const Color(0xFF37474F);
      case UserRole.md:
        return const Color(0xFF00695C);
      case UserRole.exempted:
        return const Color(0xFF00838F);
    }
  }


  String get backgroundAsset {
    switch (this) {
      case UserRole.staff:
        return 'assets/images/staff_bg.png';
      case UserRole.labour:
        return 'assets/images/labour_bg.png';
      case UserRole.md:
        return 'assets/images/md_bg.png';
      case UserRole.exempted:
        return 'assets/images/exempted_bg.jpeg';
    }
  }
}

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;

          if (isDesktop) {
            return const _DesktopRoleSelection();
          }

          return const _MobileRoleSelection();
        },
      ),
    );
  }
}

// ============================================================
// DESKTOP VERSION
// ============================================================

class _DesktopRoleSelection extends StatelessWidget {
  const _DesktopRoleSelection();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // LEFT BRAND PANEL
        Expanded(
          flex: 42,
          child: _BrandPanel(),
        ),

        // RIGHT ROLE PANEL
        Expanded(
          flex: 58,
          child: Container(
            color: const Color(0xFFF7F8FC),
            child: const _RoleContent(),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// BRAND PANEL
// ============================================================

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF061326),
            Color(0xFF0B1E37),
            Color(0xFF16385F),
          ],
        ),
      ),
      child: Stack(
        children: [

          Positioned.fill(
            child: Image.asset(
              'assets/images/mill_bg.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),

          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF061326).withValues(alpha: 0.88),
                    const Color(0xFF0B1E37).withValues(alpha: 0.85),
                    const Color(0xFF16385F).withValues(alpha: 0.82),
                  ],
                ),
              ),
            ),
          ),

          // LARGE BACKGROUND CIRCLE
          Positioned(
            top: -210,
            right: -170,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.045),
                  width: 1,
                ),
              ),
            ),
          ),

          Positioned(
            top: -150,
            right: -110,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFD9A441).withValues(alpha: 0.07),
                  width: 1,
                ),
              ),
            ),
          ),

          // BOTTOM DECORATIVE CIRCLE
          Positioned(
            bottom: -240,
            left: -180,
            child: Container(
              width: 520,
              height: 520,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.035),
                  width: 1,
                ),
              ),
            ),
          ),

          Positioned(
            bottom: -180,
            left: -120,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFD9A441).withValues(alpha: 0.06),
                  width: 1,
                ),
              ),
            ),
          ),

          // COTTON FIBER DECORATION
          Positioned(
            top: 105,
            right: 55,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.04),
                  width: 1,
                ),
              ),
              child: Center(
                child: Container(
                  width: 105,
                  height: 105,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFD9A441).withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.cloud_outlined,
                    color: Colors.white12,
                    size: 38,
                  ),
                ),
              ),
            ),
          ),

          // Decorative gold dots
          Positioned(
            top: 125,
            right: 42,
            child: Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: Color(0xFFD9A441),
                shape: BoxShape.circle,
              ),
            ),
          ),

          Positioned(
            top: 155,
            right: 70,
            child: Container(
              width: 3,
              height: 3,
              decoration: BoxDecoration(
                color: const Color(0xFFD9A441).withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
            ),
          ),

          Positioned(
            top: 180,
            right: 45,
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD9A441).withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // MAIN CONTENT
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 65,
              vertical: 55,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TOP BRAND
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.factory_outlined,
                        color: Colors.white,
                        size: 25,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'DHARANI',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 3.5,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'COTTON MILL',
                          style: TextStyle(
                            color: Color(0xFFD9A441),
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const Spacer(),

                // SMALL LABEL
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 2,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD9A441),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'WORKFORCE SOLUTIONS',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.2,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // MAIN TITLE
                const Text(
                  'Dharani',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 54,
                    height: 0.95,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -2,
                  ),
                ),

                const SizedBox(height: 4),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Cotton Mill',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 54,
                        height: 0.95,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -2,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: Color(0xFFD9A441),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 25),

                // GOLD ACCENT
                Container(
                  width: 70,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD9A441),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),

                const SizedBox(height: 24),

                // PRODUCT NAME
                const Text(
                  'SALARY MANAGEMENT',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),

                const SizedBox(height: 5),

                const Text(
                  'SYSTEM',
                  style: TextStyle(
                    color: Color(0xFFD9A441),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4,
                  ),
                ),

                const SizedBox(height: 18),

                // DESCRIPTION
                SizedBox(
                  width: 330,
                  child: Text(
                    'A smarter way to manage your workforce, '
                        'attendance and salary operations.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.42),
                      fontSize: 13,
                      height: 1.7,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),

                const Spacer(),

                // BOTTOM STATUS
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.045),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFD9A441),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'WORKFORCE MANAGEMENT',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  'Dharani Cotton Mill  •  2026',
                  style: TextStyle(
                    color: Colors.white24,
                    fontSize: 10,
                    letterSpacing: 0.5,
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

// ============================================================
// RIGHT CONTENT
// ============================================================

class _RoleContent extends StatelessWidget {
  const _RoleContent();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: 70,
          vertical: 45,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 700,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top mini brand
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1B2A4A),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 9),
                  const Text(
                    'SECURE WORKSPACE',
                    style: TextStyle(
                      color: Color(0xFF7B8494),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.2,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 38),

              // Heading
              const Text(
                'Welcome',
                style: TextStyle(
                  color: Color(0xFF14233D),
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),

              const SizedBox(height: 9),

              const Text(
                'Select your role to continue',
                style: TextStyle(
                  color: Color(0xFF7A8290),
                  fontSize: 15,
                ),
              ),

              const SizedBox(height: 38),

              // Role cards
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: UserRole.values.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 18,
                  mainAxisSpacing: 18,
                  childAspectRatio: 1.55,
                ),
                itemBuilder: (context, index) {
                  return _ModernRoleCard(
                    role: UserRole.values[index],
                  );
                },
              ),

              const SizedBox(height: 30),

              // Security message
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFE5E8EF),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B2A4A).withValues(alpha: 0.07),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_outline_rounded,
                        size: 16,
                        color: Color(0xFF1B2A4A),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Your access is protected by role-based security.',
                        style: TextStyle(
                          color: Color(0xFF747C89),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// MODERN ROLE CARD
// ============================================================

class _ModernRoleCard extends StatefulWidget {
  final UserRole role;

  const _ModernRoleCard({
    required this.role,
  });

  @override
  State<_ModernRoleCard> createState() => _ModernRoleCardState();
}

class _ModernRoleCardState extends State<_ModernRoleCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.role.color;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => _hovering = true);
      },
      onExit: (_) {
        setState(() => _hovering = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        transform: Matrix4.identity()..translate(0.0, _hovering ? -5.0 : 0.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _hovering
                ? color.withValues(alpha: 0.35)
                : const Color(0xFFE7EAF0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _hovering
                  ? color.withValues(alpha: 0.14)
                  : Colors.black.withValues(alpha: 0.035),
              blurRadius: _hovering ? 24 : 10,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LoginScreen(
                    role: widget.role,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Row(
                children: [
                  // Icon
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: color.withValues(
                        alpha: _hovering ? 0.16 : 0.10,
                      ),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Icon(
                      widget.role.icon,
                      color: color,
                      size: 27,
                    ),
                  ),
                  const SizedBox(width: 18),

                  // Text
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.role.label,
                          style: const TextStyle(
                            color: Color(0xFF182842),
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          widget.role.subtitle,
                          style: const TextStyle(
                            color: Color(0xFF858D99),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Arrow
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _hovering
                          ? color.withValues(alpha: 0.10)
                          : const Color(0xFFF4F5F8),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 15,
                      color: _hovering ? color : const Color(0xFF9AA1AD),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// MOBILE VERSION
// ============================================================

class _MobileRoleSelection extends StatelessWidget {
  const _MobileRoleSelection();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0B1A2D),
                Color(0xFFF5F6FA),
              ],
              stops: [0.30, 0.30],
            ),
          ),
        ),
        // Photo peeking through the top dark band only
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 260,
          child: ClipRect(
            child: Opacity(
              opacity: 0.35,
              child: Image.asset(
                'assets/images/mill_bg.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
        SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Mobile brand header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.factory_outlined,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Dharani Cotton Mill',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                // Main content
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 35),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF5F6FA),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Welcome',
                        style: TextStyle(
                          color: Color(0xFF14233D),
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Select your role to continue',
                        style: TextStyle(
                          color: Color(0xFF7A8290),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 28),
                      ...UserRole.values.map(
                            (role) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _MobileRoleCard(role: role),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Center(
                        child: Text(
                          'Dharani Cotton Mill • 2026',
                          style: TextStyle(
                            color: Color(0xFF9AA1AD),
                            fontSize: 10,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// MOBILE CARD
// ============================================================

class _MobileRoleCard extends StatelessWidget {
  final UserRole role;

  const _MobileRoleCard({
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final color = role.color;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LoginScreen(
                role: role,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFE6E9EF),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  role.icon,
                  color: color,
                  size: 25,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role.label,
                      style: const TextStyle(
                        color: Color(0xFF182842),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      role.subtitle,
                      style: const TextStyle(
                        color: Color(0xFF858D99),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: color,
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }
}