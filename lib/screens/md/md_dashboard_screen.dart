// lib/screens/md/md_dashboard_screen.dart
//
// MD Dashboard — mirrors the Labour Dashboard's structure (4 stat
// cards + two recent-activity panels) but themed to the MD module's
// teal palette and pointed at `md_management` / `md_salary_history`.
//
// Kept self-contained (no separate stat_card.dart) to match the pattern
// already used in md_shell_screen.dart, where _Sidebar / _NavTile are
// private widgets living in the same file rather than split out.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/md_salary_history_model.dart' show kMDHistoryMonthNames;

class MDDashboardColors {
  static const primaryDark = Color(0xFF00695C);
  static const background = Color(0xFFF5F6F7);
  static const cardBorder = Color(0xFFE3E6E8);
}

class MDDashboardScreen extends StatelessWidget {
  /// Lets the shell switch to the MD Management tab when "View All" is tapped.
  final VoidCallback? onViewMD;

  /// Lets the shell switch to the Salary History tab when "View History"
  /// is tapped.
  final VoidCallback? onViewHistory;

  const MDDashboardScreen({
    super.key,
    this.onViewMD,
    this.onViewHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MDDashboardColors.background,
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
              'MD Payroll Dashboard',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: MDDashboardColors.primaryDark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Snapshot of MD strength and salary runs for Dharani Cotton Mill.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 28),
            _buildStatCards(),
            const SizedBox(height: 28),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildRecentMDRecords()),
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
      // orderBy('MDId') matches the query used in md_management_screen.dart —
      // Firestore excludes docs missing that field from an orderBy query,
      // so this count stays in sync with what's actually visible there
      // (any stray doc without a valid MDId, e.g. from an old bug, won't
      // inflate the count).
      stream: FirebaseFirestore.instance
          .collection('md_management')
          .orderBy('MDId')
          .snapshots(),
      builder: (context, mdSnap) {
        final mdCount = mdSnap.hasData ? mdSnap.data!.docs.length : 0;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('md_salary_history')
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
                  child: _MDStatCard(
                    title: 'Total MD',
                    value: '$mdCount',
                    icon: Icons.groups_outlined,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _MDStatCard(
                    title: 'Salary Runs',
                    value: '$salaryRuns',
                    icon: Icons.receipt_long,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _MDStatCard(
                    title: 'Total Paid',
                    value: 'Rs.${totalPaid.toStringAsFixed(0)}',
                    icon: Icons.account_balance_wallet,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _MDStatCard(
                    title: 'Avg / Run',
                    value: 'Rs.${avgPerRun.toStringAsFixed(0)}',
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
  // RECENT MD RECORDS
  // -------------------------------------------------------------------
  Widget _buildRecentMDRecords() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MDDashboardColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Recent MD Records',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton(
                onPressed: onViewMD,
                child: const Text('View All'),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('md_management')
                  .orderBy('MDId')
                  .limit(5)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('No MD Records'));
                }
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      // Header row
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: MDDashboardColors.background,
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
                                flex: 2,
                                child: Text('SHIFT',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Colors.grey))),
                            Expanded(
                                flex: 2,
                                child: Text('SALARY',
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
                        final shiftRaw = data['shift']?.toString() ?? '';
                        final shiftLabel = shiftRaw.isEmpty ? '-' : shiftRaw;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                  color: MDDashboardColors.cardBorder, width: 1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                  flex: 2,
                                  child: Text(data['MDId']?.toString() ?? '')),
                              Expanded(
                                  flex: 3,
                                  child: Text(data['name']?.toString() ?? '',
                                      overflow: TextOverflow.ellipsis)),
                              Expanded(flex: 2, child: Text(shiftLabel)),
                              Expanded(
                                  flex: 2,
                                  child: Text(
                                      'Rs.${(data['monthlySalary'] ?? 0).toString()}')),
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
        border: Border.all(color: MDDashboardColors.cardBorder),
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
                  .collection('md_salary_history')
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
                        '${kMDHistoryMonthNames[month - 1]} $year';
                    final netSalary = (data['netSalary'] ?? 0).toDouble();

                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: MDDashboardColors.primaryDark,
                        child:
                        Icon(Icons.receipt_long, color: Colors.white),
                      ),
                      title: Text(
                        data['name']?.toString() ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle:
                      Text('${data['MDId'] ?? ''} • $monthLabel'),
                      trailing: Text(
                        'Rs.${netSalary.toStringAsFixed(0)}',
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
// STAT CARD — same hover-lift interaction as Labour's stat card,
// re-themed to MDDashboardColors (teal).
// ---------------------------------------------------------------------------
class _MDStatCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;

  const _MDStatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  State<_MDStatCard> createState() => _MDStatCardState();
}

class _MDStatCardState extends State<_MDStatCard> {
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
            color: isHover
                ? MDDashboardColors.primaryDark
                : Colors.grey.shade200,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isHover ? 0.10 : 0.03),
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
                    color: MDDashboardColors.primaryDark,
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