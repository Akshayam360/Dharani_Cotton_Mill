// lib/screens/exempted/exempted_shell_screen.dart
//
// Persistent sidebar shell for the Exempted module — mirrors MD's
// shell exactly (logo header, nav list, signed-in footer) but themed
// to deep teal/cyan (0xFF00838F) to match the Exempted role card.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../auth/role_selection_screen.dart';
import 'exempted_management_screen.dart';
import 'exempted_calculator_screen.dart';
import 'exempted_salary_history_screen.dart';
import 'exempted_dashboard_screen.dart';

class ExemptedColors {
  static const Color primary = Color(0xFF00838F); // deep teal (Exempted role)
  static const Color primaryDark = Color(0xFF00838F);
  static const Color background = Color(0xFFF5F6F7);
  static const Color sidebarBg = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFE3E6E8);
}

enum ExemptedNavItem { dashboard, management, calculator, history }

class ExemptedShellScreen extends StatefulWidget {
  const ExemptedShellScreen({super.key});

  @override
  State<ExemptedShellScreen> createState() => _ExemptedShellScreenState();
}

class _ExemptedShellScreenState extends State<ExemptedShellScreen> {
  ExemptedNavItem _selected = ExemptedNavItem.dashboard;

  Widget _currentBody() {
    switch (_selected) {
      case ExemptedNavItem.dashboard:
        return ExemptedDashboardScreen(
          onViewExempted: () =>
              setState(() => _selected = ExemptedNavItem.management),
          onViewHistory: () =>
              setState(() => _selected = ExemptedNavItem.history),
        );
      case ExemptedNavItem.management:
        return const ExemptedManagementScreen();
      case ExemptedNavItem.calculator:
        return const ExemptedCalculatorScreen();
      case ExemptedNavItem.history:
        return const ExemptedSalaryHistoryScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExemptedColors.background,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch, // fill full height, don't center content
        children: [
          _Sidebar(
            selected: _selected,
            onSelect: (item) => setState(() => _selected = item),
          ),
          Expanded(child: _currentBody()),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SIDEBAR
// ---------------------------------------------------------------------------
class _Sidebar extends StatelessWidget {
  final ExemptedNavItem selected;
  final ValueChanged<ExemptedNavItem> onSelect;

  const _Sidebar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: ExemptedColors.sidebarBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / branding
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: ExemptedColors.primaryDark,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.verified_user_outlined,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dharani Cotton Mill',
                        maxLines: 2,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          height: 1.2,
                          color: ExemptedColors.primaryDark,
                        ),
                      ),
                      Text(
                        'Exempted Workspace',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 12),

          _NavTile(
            icon: Icons.dashboard_outlined,
            label: 'Dashboard',
            active: selected == ExemptedNavItem.dashboard,
            onTap: () => onSelect(ExemptedNavItem.dashboard),
          ),
          _NavTile(
            icon: Icons.groups_outlined,
            label: 'Exempted Management',
            active: selected == ExemptedNavItem.management,
            onTap: () => onSelect(ExemptedNavItem.management),
          ),
          _NavTile(
            icon: Icons.calculate_outlined,
            label: 'Salary Calculator',
            active: selected == ExemptedNavItem.calculator,
            onTap: () => onSelect(ExemptedNavItem.calculator),
          ),
          _NavTile(
            icon: Icons.history_outlined,
            label: 'Salary History',
            active: selected == ExemptedNavItem.history,
            onTap: () => onSelect(ExemptedNavItem.history),
          ),

          const Spacer(),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Signed in as',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
                Text(
                  FirebaseAuth.instance.currentUser?.email ?? '',
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await AuthService().signOut();
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                              builder: (_) => const RoleSelectionScreen()),
                              (route) => false,
                        );
                      }
                    },
                    icon: const Icon(Icons.logout, size: 16),
                    label: const Text('Logout'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ExemptedColors.primaryDark,
                      side: const BorderSide(color: ExemptedColors.cardBorder),
                    ),
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

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: active ? ExemptedColors.primaryDark : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon,
                    size: 20,
                    color: active ? Colors.white : Colors.grey.shade700),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: active ? Colors.white : Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}