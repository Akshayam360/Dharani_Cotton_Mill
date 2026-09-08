// lib/screens/md/md_shell_screen.dart
//
// Persistent sidebar shell for the MD module — mirrors the Labour app's
// layout (logo header, nav list, signed-in footer) so both modules feel
// like one consistent product. Uses UserRole.md.color (teal, 0xFF00695C)
// from role_selection_screen.dart so the shell matches the role card.
//
// Dashboard and History screens are placeholders for now — swap in
// MDDashboardScreen / MDSalaryHistoryScreen as each one gets built,
// same pattern as how MDManagementScreen and MDCalculatorScreen were
// wired in.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../auth/role_selection_screen.dart';
import 'md_management_screen.dart';
import 'md_calculator_screen.dart';
import 'md_salary_history_screen.dart';
import 'md_dashboard_screen.dart';

class MDColors {
  static const Color primary = Color(0xFF00695C); // teal (MD role)
  static const Color primaryDark = Color(0xFF004D40);
  static const Color background = Color(0xFFF5F6F7);
  static const Color sidebarBg = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFE3E6E8);
}

enum MDNavItem { dashboard, management, calculator, history }

class MDShellScreen extends StatefulWidget {
  const MDShellScreen({super.key});

  @override
  State<MDShellScreen> createState() => _MDShellScreenState();
}

class _MDShellScreenState extends State<MDShellScreen> {
  MDNavItem _selected = MDNavItem.dashboard;

  Widget _currentBody() {
    switch (_selected) {
      case MDNavItem.dashboard:
        return MDDashboardScreen(
          onViewMD: () => setState(() => _selected = MDNavItem.management),
          onViewHistory: () => setState(() => _selected = MDNavItem.history),
        );
      case MDNavItem.management:
        return const MDManagementScreen();
      case MDNavItem.calculator:
        return const MDCalculatorScreen();
      case MDNavItem.history:
        return const MDSalaryHistoryScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MDColors.background,
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
  final MDNavItem selected;
  final ValueChanged<MDNavItem> onSelect;

  const _Sidebar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: MDColors.sidebarBg,
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
                    color: MDColors.primaryDark,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.admin_panel_settings_outlined,
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
                          color: MDColors.primaryDark,
                        ),
                      ),
                      Text(
                        'MD Workspace',
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
            active: selected == MDNavItem.dashboard,
            onTap: () => onSelect(MDNavItem.dashboard),
          ),
          _NavTile(
            icon: Icons.groups_outlined,
            label: 'MD Management',
            active: selected == MDNavItem.management,
            onTap: () => onSelect(MDNavItem.management),
          ),
          _NavTile(
            icon: Icons.calculate_outlined,
            label: 'Salary Calculator',
            active: selected == MDNavItem.calculator,
            onTap: () => onSelect(MDNavItem.calculator),
          ),
          _NavTile(
            icon: Icons.history_outlined,
            label: 'Salary History',
            active: selected == MDNavItem.history,
            onTap: () => onSelect(MDNavItem.history),
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
                      foregroundColor: MDColors.primaryDark,
                      side: const BorderSide(color: MDColors.cardBorder),
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
        color: active ? MDColors.primaryDark : Colors.transparent,
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

// ---------------------------------------------------------------------------
// GENERIC "COMING SOON" BODY for not-yet-built tabs
// ---------------------------------------------------------------------------
class _ComingSoonBody extends StatelessWidget {
  final String title;
  final String subtitle;

  const _ComingSoonBody({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: MDColors.primaryDark),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          const Expanded(
            child: Center(
              child: Text('Coming soon.', style: TextStyle(color: Colors.grey)),
            ),
          ),
        ],
      ),
    );
  }
}