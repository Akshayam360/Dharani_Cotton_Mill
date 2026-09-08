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
//
// NOTE ON `main`: this copy of the file (on the `main` branch) keeps
// EVERY case as a placeholder, on purpose — `main` should always
// compile standalone, even before any one person's screen files have
// been merged in. Each dev wires up their real screen only inside
// their OWN feature branch (see feature/staff-labour for the fully
// wired Labour case, as an example). The final merge combines
// everyone's real wiring into one file automatically, since each
// person only ever touches their own `case` line.
//
// THIS COPY: on branch feature/md-exempted — only the MD case is
// wired here. The Labour/Staff cases stay as placeholders on this
// branch (your friend owns those lines on feature/staff-labour) so
// merging doesn't conflict. Once Exempted is ready, wire that case
// here too, on this same branch.

import 'package:flutter/material.dart';
import 'auth_service.dart';
import '../screens/auth/role_selection_screen.dart'; // for UserRole enum
import '../screens/md/md_shell_screen.dart';
import '../screens/exempted/exempted_shell_screen.dart';

/// Returns the correct dashboard/shell screen for the given role.
/// Add your own case here — see instructions above.
Widget resolveDashboard(UserRole role) {
  switch (role) {
  // TODO(labour owner): replace with LabourShellScreen()
    case UserRole.labour:
      return _PendingDashboard(role: role);

  // TODO(staff owner): replace with StaffShellScreen()
    case UserRole.staff:
      return _PendingDashboard(role: role);

    case UserRole.md:
      return const MDShellScreen();

    case UserRole.exempted:
      return const ExemptedShellScreen();
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