// lib/services/role_router.dart
//
// Central place that maps a UserRole to its dashboard screen.
//
// WHY THIS FILE EXISTS
// ---------------------
// Without this, every dev would edit the same lines inside
// login_screen.dart's _handleLogin() to wire up their own role's
// dashboard — guaranteed merge conflicts every time someone adds one.
//
// With this file, each dev only ADDS a new `case` line here (a line
// the other person never touches), so Git merges both additions
// automatically. login_screen.dart itself never changes again.
//
// HOW TO ADD YOUR DASHBOARD
// --------------------------
// 1. Import your dashboard screen at the top of this file.
// 2. Add a `case UserRole.<yourRole>:` returning it, replacing the
//    matching placeholder line below.
// 3. Don't touch any other case — that avoids conflicts with your
//    teammate's changes.

import 'package:flutter/material.dart';
import 'auth_service.dart';
import '../screens/auth/role_selection_screen.dart'; // for UserRole enum
import '../screens/labour/labour_shell_screen.dart';
import '../screens/staff/staff_shell_screen.dart';

/// Returns the correct dashboard/shell screen for the given role.
/// Add your own case here — see instructions above.
Widget resolveDashboard(UserRole role) {
  switch (role) {
    case UserRole.labour:
      return const LabourShellScreen();

    case UserRole.staff:
      return const StaffShellScreen();

  // TODO(md owner): replace with MdShellScreen()
    case UserRole.md:
      return _PendingDashboard(role: role);

  // TODO(exempted owner): replace with ExemptedShellScreen()
    case UserRole.exempted:
      return _PendingDashboard(role: role);
  }
}

/// Temporary placeholder shown for any role whose real dashboard
/// hasn't been wired into resolveDashboard() yet.
class _PendingDashboard extends StatelessWidget {
  final UserRole role;
  const _PendingDashboard({required this.role});

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
                  MaterialPageRoute(
                      builder: (_) => const RoleSelectionScreen()),
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