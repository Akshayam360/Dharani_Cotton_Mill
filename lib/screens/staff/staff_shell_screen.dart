// lib/screens/staff/staff_shell_screen.dart
//
// Persistent sidebar shell for the Staff module — mirrors the Labour
// module's layout (logo header, nav list, signed-in footer) so both
// modules feel like one consistent product.
//
// Dashboard, Salary Calculator and Salary History are placeholders for
// now — swap in StaffDashboardScreen / StaffSalaryCalculatorScreen /
// StaffSalaryHistoryScreen as each one gets built, same pattern as how
// LabourShellScreen was filled in one screen at a time.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../auth/role_selection_screen.dart';
import 'staff_management_screen.dart';
import 'staff_calculator_screen.dart';
import 'staff_salary_history_screen.dart';
import 'staff_dashboard_screen.dart';

class StaffColors {
  static const Color primary = Color(0xFF6D4C41); // brown (Staff role)
  static const Color primaryDark = Color(0xFF3E2723);
  static const Color background = Color(0xFFF5F6F7);
  static const Color sidebarBg = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFE3E6E8);
}

enum StaffNavItem { dashboard, staff, calculator, history }

class StaffShellScreen extends StatefulWidget {
  const StaffShellScreen({super.key});

  @override
  State<StaffShellScreen> createState() => _StaffShellScreenState();
}

class _StaffShellScreenState extends State<StaffShellScreen> {
  StaffNavItem _selected = StaffNavItem.dashboard;

  Widget _currentBody() {
    switch (_selected) {
      case StaffNavItem.dashboard:
        return StaffDashboardScreen(
          onViewStaff: () => setState(() => _selected = StaffNavItem.staff),
          onViewHistory: () =>
              setState(() => _selected = StaffNavItem.history),
        );
      case StaffNavItem.staff:
        return const StaffManagementScreen();
      case StaffNavItem.calculator:
        return const StaffSalaryCalculatorScreen();
      case StaffNavItem.history:
        return const StaffSalaryHistoryScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StaffColors.background,
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
  final StaffNavItem selected;
  final ValueChanged<StaffNavItem> onSelect;

  const _Sidebar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: StaffColors.sidebarBg,
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
                    color: StaffColors.primaryDark,
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
                          color: StaffColors.primaryDark,
                        ),
                      ),
                      Text(
                        'Staff Payroll',
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
            active: selected == StaffNavItem.dashboard,
            onTap: () => onSelect(StaffNavItem.dashboard),
          ),
          _NavTile(
            icon: Icons.badge_outlined,
            label: 'Staff',
            active: selected == StaffNavItem.staff,
            onTap: () => onSelect(StaffNavItem.staff),
          ),
          _NavTile(
            icon: Icons.calculate_outlined,
            label: 'Salary Calculator',
            active: selected == StaffNavItem.calculator,
            onTap: () => onSelect(StaffNavItem.calculator),
          ),
          _NavTile(
            icon: Icons.history_outlined,
            label: 'Salary History',
            active: selected == StaffNavItem.history,
            onTap: () => onSelect(StaffNavItem.history),
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
                    onPressed: () => _confirmLogout(context),
                    icon: const Icon(Icons.logout, size: 16),
                    label: const Text('Logout'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: StaffColors.primaryDark,
                      side: const BorderSide(color: StaffColors.cardBorder),
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

/// Shows a confirmation dialog before signing out, so an accidental tap
/// on Logout doesn't immediately kick the user back to the role screen.
Future<void> _confirmLogout(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Logout'),
      content: const Text('Are you sure you want to logout?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: StaffColors.primaryDark,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Logout'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    await AuthService().signOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
            (route) => false,
      );
    }
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
        color: active ? StaffColors.primaryDark : Colors.transparent,
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