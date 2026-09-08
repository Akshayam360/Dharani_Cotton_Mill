// lib/screens/staff/staff_dashboard_screen.dart
//
// Staff Dashboard — mirrors the Labour Dashboard's structure (4 stat
// cards + two recent-activity panels) but themed to the Staff module's
// brown palette and pointed at `staff` / `staff_salary_history`.
//
// Kept self-contained (no separate stat_card.dart) to match the pattern
// already used in staff_shell_screen.dart, where _Sidebar / _NavTile
// are private widgets living in the same file rather than split out.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/staff_salary_history_model.dart' show kStaffHistoryMonthNames;
import 'staff_management_screen.dart' show StaffColors;

class StaffDashboardScreen extends StatelessWidget {
  /// Lets the shell switch to the Staff tab when "View All" is tapped.
  final VoidCallback? onViewStaff;

  /// Lets the shell switch to the Salary History tab when "View History"
  /// is tapped.
  final VoidCallback? onViewHistory;

  const StaffDashboardScreen({
    super.key,
    this.onViewStaff,
    this.onViewHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: StaffColors.background,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CONSOLE',
              style: TextStyle(
                letterSpacing: 3,
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Staff Payroll Dashboard',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: StaffColors.primaryDark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Snapshot of staff strength and salary runs for Dharani Cotton Mill.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 28),
            _buildStatCards(),
            const SizedBox(height: 28),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildRecentStaffRecords()),
                  const SizedBox(width: 20),
                  Expanded(child: _buildRecentSalaryRuns()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------
  // STAT CARDS
  // -------------------------------------------------------------------
  Widget _buildStatCards() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('staff').snapshots(),
      builder: (context, staffSnap) {
        final staffCount =
        staffSnap.hasData ? staffSnap.data!.docs.length : 0;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('staff_salary_history')
              .snapshots(),
          builder: (context, historySnap) {
            final docs = historySnap.hasData ? historySnap.data!.docs : [];
            final salaryRuns = docs.length;

            double totalPaid = 0;
            for (final doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              totalPaid += (data['netSalary'] ?? 0).toDouble();
            }
            final avgPerRun = salaryRuns == 0 ? 0 : totalPaid / salaryRuns;

            return Row(
              children: [
                Expanded(
                  child: _StaffStatCard(
                    title: 'Total Staff',
                    value: '$staffCount',
                    icon: Icons.badge_outlined,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _StaffStatCard(
                    title: 'Salary Runs',
                    value: '$salaryRuns',
                    icon: Icons.receipt_long,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _StaffStatCard(
                    title: 'Total Paid',
                    value: '₹${totalPaid.toStringAsFixed(0)}',
                    icon: Icons.account_balance_wallet,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _StaffStatCard(
                    title: 'Avg / Run',
                    value: '₹${avgPerRun.toStringAsFixed(0)}',
                    icon: Icons.trending_up,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // -------------------------------------------------------------------
  // RECENT STAFF RECORDS
  // -------------------------------------------------------------------
  Widget _buildRecentStaffRecords() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StaffColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Recent Staff Records',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton(
                onPressed: onViewStaff,
                child: const Text('View All'),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('staff')
                  .orderBy('updatedAt', descending: true)
                  .limit(5)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('No Staff Records'));
                }
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      // Header row
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: StaffColors.background,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Expanded(
                                flex: 2,
                                child: Text('ID',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Colors.grey))),
                            Expanded(
                                flex: 3,
                                child: Text('NAME',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Colors.grey))),
                            Expanded(
                                flex: 3,
                                child: Text('MONTHLY SALARY',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Colors.grey))),
                          ],
                        ),
                      ),
                      // Data rows, each stretched to fill the card's width.
                      ...docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                  color: StaffColors.cardBorder, width: 1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(flex: 2, child: Text(doc.id)),
                              Expanded(
                                  flex: 3,
                                  child: Text(data['name']?.toString() ?? '',
                                      overflow: TextOverflow.ellipsis)),
                              Expanded(
                                  flex: 3,
                                  child: Text(
                                      '₹${(data['monthlySalary'] ?? 0).toString()}')),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------
  // RECENT SALARY RUNS
  // -------------------------------------------------------------------
  Widget _buildRecentSalaryRuns() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StaffColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Recent Salary Runs',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton(
                onPressed: onViewHistory,
                child: const Text('View History'),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 6),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('staff_salary_history')
                  .orderBy('generatedAt', descending: true)
                  .limit(5)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('No Salary Runs Yet'));
                }
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final month = (data['month'] is num)
                        ? (data['month'] as num).toInt()
                        : 1;
                    final year = (data['year'] is num)
                        ? (data['year'] as num).toInt()
                        : DateTime.now().year;
                    final monthLabel =
                        '${kStaffHistoryMonthNames[month - 1]} $year';
                    final netSalary =
                    (data['netSalary'] ?? 0).toDouble();

                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: StaffColors.primaryDark,
                        child:
                        Icon(Icons.receipt_long, color: Colors.white),
                      ),
                      title: Text(
                        data['name']?.toString() ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle:
                      Text('${data['staffId'] ?? ''} • $monthLabel'),
                      trailing: Text(
                        '₹${netSalary.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// STAT CARD — same hover-lift interaction as the Labour Dashboard's
// stat card, re-themed to StaffColors.
// ---------------------------------------------------------------------------
class _StaffStatCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StaffStatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  State<_StaffStatCard> createState() => _StaffStatCardState();
}

class _StaffStatCardState extends State<_StaffStatCard> {
  bool isHover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => isHover = true),
      onExit: (_) => setState(() => isHover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(0, isHover ? -4 : 0, 0),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: isHover ? StaffColors.primaryDark : Colors.grey.shade200,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isHover ? 0.10 : 0.03),
              blurRadius: isHover ? 16 : 6,
              offset: Offset(0, isHover ? 8 : 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: StaffColors.primaryDark,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(widget.icon, color: Colors.white, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 25),
            Text(
              widget.value,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}