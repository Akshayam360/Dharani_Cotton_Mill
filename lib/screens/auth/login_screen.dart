import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'role_selection_screen.dart';

class LoginScreen extends StatefulWidget {
  final UserRole role;

  const LoginScreen({super.key, required this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final error = await _authService.signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }

    // TODO: Replace this with actual role dashboards once built:
    // UserRole.staff    -> StaffDashboard()      (Sowmi)
    // UserRole.labour   -> LabourDashboard()     (Sowmi)
    // UserRole.md       -> MdDashboard()         (Friend)
    // UserRole.exempted -> ExemptedDashboard()   (Friend)
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => _PlaceholderDashboard(role: widget.role),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.role.color;

    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;

          if (isDesktop) {
            return Row(
              children: [
                Expanded(flex: 45, child: _ColorPanel(role: widget.role)),
                Expanded(
                  flex: 55,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 56),
                      child: _LoginForm(
                        formKey: _formKey,
                        emailController: _emailController,
                        passwordController: _passwordController,
                        obscurePassword: _obscurePassword,
                        onToggleObscure: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                        isLoading: _isLoading,
                        errorMessage: _errorMessage,
                        onLogin: _handleLogin,
                        role: widget.role,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          // Mobile — stacked
          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    height: 260,
                    child: _ColorPanel(role: widget.role, compact: true),
                  ),
                  Padding(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
                    child: _LoginForm(
                      formKey: _formKey,
                      emailController: _emailController,
                      passwordController: _passwordController,
                      obscurePassword: _obscurePassword,
                      onToggleObscure: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                      isLoading: _isLoading,
                      errorMessage: _errorMessage,
                      onLogin: _handleLogin,
                      role: widget.role,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// LEFT — role-colored gradient panel with soft blobs & glass icon.
class _ColorPanel extends StatelessWidget {
  final UserRole role;
  final bool compact;

  const _ColorPanel({required this.role, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final color = role.color;
    final dark = Color.lerp(color, Colors.black, 0.35)!;
    final light = Color.lerp(color, Colors.white, 0.15)!;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [light, color, dark],
        ),
        boxShadow: compact
            ? null
            : [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 60,
            spreadRadius: -10,
            offset: const Offset(30, 0),
          ),
        ],
      ),
      child: Stack(
        children: [

          Positioned.fill(
            child: Image.asset(
              role.backgroundAsset,
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
                    light.withValues(alpha: 0.75),
                    color.withValues(alpha: 0.80),
                    dark.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
          ),

          // Soft blurred blobs
          Positioned(
            top: -60,
            left: -40,
            child: _Blob(size: 220, opacity: 0.14),
          ),
          Positioned(
            bottom: -80,
            right: -60,
            child: _Blob(size: 260, opacity: 0.12),
          ),
          Positioned(
            top: compact ? 40 : 160,
            right: compact ? -20 : 30,
            child: Transform.rotate(
              angle: -math.pi / 10,
              child: Icon(
                Icons.spa_outlined,
                size: compact ? 90 : 130,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 26 : 56,
              vertical: compact ? 24 : 50,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment:
              compact ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                if (!compact) ...[
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const Spacer(flex: 2),
                ],

                // Glass-style icon card
                Container(
                  width: compact ? 70 : 96,
                  height: compact ? 70 : 96,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(compact ? 22 : 28),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Icon(role.icon,
                      color: Colors.white, size: compact ? 32 : 42),
                ),

                SizedBox(height: compact ? 18 : 32),

                Text(
                  role.label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 26 : 40,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  role.subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: compact ? 13 : 16,
                  ),
                ),

                if (!compact) ...[
                  const Spacer(flex: 3),
                  Row(
                    children: [
                      const Icon(Icons.factory_outlined,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'Dharani Cotton Mill',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final double opacity;
  const _Blob({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}

/// RIGHT — clean login form with gradient button & subtle accents.
class _LoginForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onLogin;
  final UserRole role;
  final Color color;

  const _LoginForm({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.isLoading,
    required this.errorMessage,
    required this.onLogin,
    required this.role,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(role.icon, size: 13, color: color),
                  const SizedBox(width: 6),
                  Text(
                    '${role.label.toUpperCase()} ACCESS',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Welcome back',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Color(0xFF14233D),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in with your registered email to continue',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 34),

            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(fontSize: 14.5),
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined, color: color, size: 20),
                filled: true,
                fillColor: const Color(0xFFF7F8FB),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: color, width: 1.5),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter your email';
                }
                if (!value.contains('@')) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: passwordController,
              obscureText: obscurePassword,
              style: const TextStyle(fontSize: 14.5),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline, color: color, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 19,
                  ),
                  onPressed: onToggleObscure,
                ),
                filled: true,
                fillColor: const Color(0xFFF7F8FB),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: color, width: 1.5),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Enter your password';
                }
                return null;
              },
              onFieldSubmitted: (_) => onLogin(),
            ),

            if (errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        color: Colors.red.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        errorMessage!,
                        style:
                        TextStyle(color: Colors.red.shade700, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: [
                      color,
                      Color.lerp(color, Colors.black, 0.25)!,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: isLoading ? null : onLogin,
                    child: Center(
                      child: isLoading
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                          AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                          : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded,
                              color: Colors.white, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey.shade200)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.shield_outlined,
                      size: 14, color: Colors.grey.shade400),
                ),
                Expanded(child: Divider(color: Colors.grey.shade200)),
              ],
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(
                'Protected by role-based access control',
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Temporary placeholder shown after login until real dashboards are built.
class _PlaceholderDashboard extends StatelessWidget {
  final UserRole role;

  const _PlaceholderDashboard({required this.role});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${role.label} Dashboard'),
        backgroundColor: role.color,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
                      (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Text(
          '✅ Logged in as ${role.label}\nDashboard coming soon',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}