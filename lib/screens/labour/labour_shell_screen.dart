// lib/screens/labour/labour_shell_screen.dart
//
// Persistent sidebar shell for the Labour module — mirrors the Staff app's
// layout (logo header, nav list, signed-in footer) so both modules feel
// like one consistent product.
//
// Dashboard and Calculator/History screens are placeholders for now —
// swap in LabourDashboardScreen / LabourSalaryCalculatorScreen /
// LabourSalaryHistoryScreen as each one gets built, same pattern as
// how LabourManagementScreen was wired in.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../auth/role_selection_screen.dart';
import 'labour_management_screen.dart';

class LabourColors {
  static const Color primary = Color(0xFF37474F); // blue-grey (Labour role)
  static const Color primaryDark = Color(0xFF102027);
  static const Color background = Color(0xFFF5F6F7);
  static const Color sidebarBg = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFE3E6E8);
}

enum LabourNavItem { dashboard, labour, calculator, history }

class LabourShellScreen extends StatefulWidget {
  const LabourShellScreen({super.key});

  @override
  State<LabourShellScreen> createState() => _LabourShellScreenState();
}

class _LabourShellScreenState extends State<LabourShellScreen> {
  LabourNavItem _selected = LabourNavItem.dashboard;

  Widget _currentBody() {
    switch (_selected) {
      case LabourNavItem.dashboard:
        return const _LabourDashboardPlaceholder();
      case LabourNavItem.labour:
        return const LabourManagementScreen();
      case LabourNavItem.calculator:
        return const _ComingSoonBody(
          title: 'Salary Calculator',
          subtitle:
          'Calculate labour wages with days worked, OT hours, PF and ESI deductions.',
        );
      case LabourNavItem.history:
        return const _ComingSoonBody(
          title: 'Salary History',
          subtitle: 'Immutable log of every labour salary run.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LabourColors.background,
      body: Row(
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
  final LabourNavItem selected;
  final ValueChanged<LabourNavItem> onSelect;

  const _Sidebar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: LabourColors.sidebarBg,
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
                    color: LabourColors.primaryDark,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.factory_outlined,
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
                          color: LabourColors.primaryDark,
                        ),
                      ),
                      Text(
                        'Labour Payroll',
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
            active: selected == LabourNavItem.dashboard,
            onTap: () => onSelect(LabourNavItem.dashboard),
          ),
          _NavTile(
            icon: Icons.groups_outlined,
            label: 'Labour',
            active: selected == LabourNavItem.labour,
            onTap: () => onSelect(LabourNavItem.labour),
          ),
          _NavTile(
            icon: Icons.calculate_outlined,
            label: 'Salary Calculator',
            active: selected == LabourNavItem.calculator,
            onTap: () => onSelect(LabourNavItem.calculator),
          ),
          _NavTile(
            icon: Icons.history_outlined,
            label: 'Salary History',
            active: selected == LabourNavItem.history,
            onTap: () => onSelect(LabourNavItem.history),
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
                      foregroundColor: LabourColors.primaryDark,
                      side: const BorderSide(color: LabourColors.cardBorder),
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
        color: active ? LabourColors.primaryDark : Colors.transparent,
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
// PLACEHOLDER DASHBOARD (swap for real LabourDashboardScreen later)
// ---------------------------------------------------------------------------
class _LabourDashboardPlaceholder extends StatelessWidget {
  const _LabourDashboardPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CONSOLE',
              style: TextStyle(
                  letterSpacing: 2, color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          const Text(
            'Labour Payroll Dashboard',
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: LabourColors.primaryDark),
          ),
          const SizedBox(height: 4),
          const Text(
            'Snapshot of labour strength and salary runs for Dharani Cotton Mill.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          const Expanded(
            child: Center(
              child: Text(
                'Dashboard cards (Total Labour, Salary Runs, Total Paid, Avg/Run)\ncoming next.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ],
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
                color: LabourColors.primaryDark),
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