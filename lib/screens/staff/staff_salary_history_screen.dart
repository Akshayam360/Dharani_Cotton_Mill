// lib/screens/staff/staff_salary_history_screen.dart
//
// Staff Salary History — immutable-log view of every saved
// staff_salary_history record, grouped by month with PDF export and
// delete, mirroring the Labour Salary History screen's layout and
// interaction pattern.

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../models/staff_salary_history_model.dart';
import '../../services/staff_salary_history_service.dart';
import '../../services/pdf/staff_payroll_pdf_service.dart';
import 'staff_management_screen.dart' show StaffColors;

class StaffSalaryHistoryScreen extends StatefulWidget {
  const StaffSalaryHistoryScreen({super.key});

  @override
  State<StaffSalaryHistoryScreen> createState() =>
      _StaffSalaryHistoryScreenState();
}

class _StaffSalaryHistoryScreenState extends State<StaffSalaryHistoryScreen> {
  final StaffSalaryHistoryService _historyService = StaffSalaryHistoryService();
  final StaffPayrollPdfService _pdfService = StaffPayrollPdfService();

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _horizontalController = ScrollController();

  String _searchText = '';
  String _selectedMonthFilter = 'All';
  String _selectedYearFilter = 'All';

  final List<String> _monthFilters = ['All', ...kStaffHistoryMonthNames];

  // Dynamic range (not hardcoded) so the filter keeps working in future
  // years without needing a code change — same approach as the Calculator.
  late final List<String> _yearFilters = [
    'All',
    ...List.generate(11, (i) => '${DateTime.now().year - 5 + i}'),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _searchText = '';
      _selectedMonthFilter = 'All';
      _selectedYearFilter = 'All';
    });
  }

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
              'Salary History',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: StaffColors.primaryDark,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Immutable log of every staff salary run.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search Staff ID / Name / Account Number',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: StaffColors.cardBorder),
                ),
              ),
              onChanged: (value) =>
                  setState(() => _searchText = value.toLowerCase()),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedMonthFilter,
                    decoration: InputDecoration(
                      labelText: 'Month',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: _monthFilters
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedMonthFilter = v!),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedYearFilter,
                    decoration: InputDecoration(
                      labelText: 'Year',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: _yearFilters
                        .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedYearFilter = v!),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _clearFilters,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: StaffColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 18),
                  ),
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear'),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: _showClearHistoryDialog,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 18),
                  ),
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Clear History'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<List<StaffSalaryHistoryModel>>(
                stream: _historyService.getSalaryHistory(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text('No Salary History Found',
                          style: TextStyle(color: Colors.grey)),
                    );
                  }

                  final filtered = snapshot.data!.where((s) {
                    final searchMatch = s.staffId
                        .toLowerCase()
                        .contains(_searchText) ||
                        s.name.toLowerCase().contains(_searchText) ||
                        s.bankAccount.toLowerCase().contains(_searchText);
                    final monthMatch = _selectedMonthFilter == 'All' ||
                        s.monthLabel.contains(_selectedMonthFilter);
                    final yearMatch = _selectedYearFilter == 'All' ||
                        s.monthLabel.contains(_selectedYearFilter);
                    return searchMatch && monthMatch && yearMatch;
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text('No records match your filters',
                          style: TextStyle(color: Colors.grey)),
                    );
                  }

                  final Map<String, List<StaffSalaryHistoryModel>> grouped =
                  {};
                  for (final h in filtered) {
                    grouped.putIfAbsent(h.monthLabel, () => []).add(h);
                  }
                  for (final list in grouped.values) {
                    list.sort((a, b) => a.staffId.compareTo(b.staffId));
                  }

                  // Newest month first.
                  final sortedEntries = grouped.entries.toList()
                    ..sort((a, b) {
                      final ay = a.value.first.year;
                      final am = a.value.first.month;
                      final by = b.value.first.year;
                      final bm = b.value.first.month;
                      if (ay != by) return by.compareTo(ay);
                      return bm.compareTo(am);
                    });

                  return ListView(
                    children: sortedEntries.map((entry) {
                      final monthLabel = entry.key;
                      final records = entry.value;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: StaffColors.cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  monthLabel,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: StaffColors.primaryDark,
                                  ),
                                ),
                                const Spacer(),
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    final pdf = await _pdfService
                                        .generateMonthlyPayrollPdf(
                                      month: monthLabel,
                                      records: records,
                                    );
                                    await Printing.sharePdf(
                                      bytes: pdf,
                                      filename:
                                      '$monthLabel Staff Salary Register.pdf',
                                    );
                                  },
                                  icon: const Icon(Icons.picture_as_pdf,
                                      size: 18),
                                  label: const Text('PDF'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: StaffColors.primaryDark,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    final pdf = await _pdfService
                                        .generateMonthlyPayrollPdf(
                                      month: monthLabel,
                                      records: records,
                                    );
                                    await Printing.layoutPdf(
                                        onLayout: (_) async => pdf);
                                  },
                                  icon: const Icon(Icons.print, size: 18),
                                  label: const Text('Print'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: StaffColors.primaryDark,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Scrollbar(
                              controller: _horizontalController,
                              thumbVisibility: true,
                              child: SingleChildScrollView(
                                controller: _horizontalController,
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints:
                                  const BoxConstraints(minWidth: 1700),
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(
                                        StaffColors.primaryDark),
                                    headingTextStyle: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    dataTextStyle: const TextStyle(
                                      fontSize: 15,
                                      color: Colors.black87,
                                    ),
                                    dataRowMinHeight: 60,
                                    dataRowMaxHeight: 60,
                                    columnSpacing: 26,
                                    columns: const [
                                      DataColumn(label: Text('Staff ID')),
                                      DataColumn(label: Text('Name')),
                                      DataColumn(label: Text('Account No')),
                                      DataColumn(label: Text('Working')),
                                      DataColumn(label: Text('Worked')),
                                      DataColumn(label: Text('Effective')),
                                      DataColumn(label: Text('PF')),
                                      DataColumn(label: Text('ESI')),
                                      DataColumn(label: Text('LIC')),
                                      DataColumn(label: Text('Mess')),
                                      DataColumn(label: Text('Welfare')),
                                      DataColumn(label: Text('Deduction')),
                                      DataColumn(label: Text('Net Salary')),
                                      DataColumn(label: Text('Action')),
                                    ],
                                    rows: records.map((r) {
                                      return DataRow(cells: [
                                        DataCell(Text(r.staffId)),
                                        DataCell(Text(r.name)),
                                        DataCell(Text(r.bankAccount.isEmpty
                                            ? '-'
                                            : r.bankAccount)),
                                        DataCell(Text('${r.workingDays}')),
                                        DataCell(Text(_fmtDays(r.daysWorked))),
                                        DataCell(Text(
                                            '₹${r.effectiveSalary.toStringAsFixed(0)}')),
                                        DataCell(Text(
                                            '₹${r.pfAmount.toStringAsFixed(0)}')),
                                        DataCell(Text(
                                            '₹${r.esiAmount.toStringAsFixed(2)}')),
                                        DataCell(Text(
                                            '₹${r.lic.toStringAsFixed(0)}')),
                                        DataCell(Text(
                                            '₹${r.mess.toStringAsFixed(0)}')),
                                        DataCell(Text(
                                            '₹${r.welfare.toStringAsFixed(0)}')),
                                        DataCell(Text(
                                            '₹${r.totalDeductions.toStringAsFixed(0)}')),
                                        DataCell(Text(
                                          '₹${r.netSalary.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        )),
                                        DataCell(
                                          IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: Colors.red),
                                            onPressed: () =>
                                                _showDeleteDialog(r),
                                          ),
                                        ),
                                      ]);
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDays(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  Future<void> _showDeleteDialog(StaffSalaryHistoryModel record) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Salary Record'),
        content: Text(
          'Are you sure you want to delete the salary record of\n\n'
              '${record.name}\n(${record.staffId})\n\n'
              'for ${record.monthLabel}?\n\n'
              'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _deleteRecord(record);
            },
            child:
            const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRecord(StaffSalaryHistoryModel record) async {
    try {
      await _historyService.deleteSalaryHistory(record.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Salary record deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // -------------------------------------------------------------------
  // CLEAR HISTORY — pick a scope (all / a whole year / one month), then
  // confirm before the bulk delete runs.
  // -------------------------------------------------------------------
  Future<void> _showClearHistoryDialog() async {
    _ClearHistoryScope scope = _ClearHistoryScope.all;
    int selectedYear = DateTime.now().year;
    int selectedMonth = DateTime.now().month;
    final years = List.generate(11, (i) => DateTime.now().year - 5 + i);

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Clear Salary History'),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Choose what to permanently delete. This cannot be undone.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    RadioListTile<_ClearHistoryScope>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('All history'),
                      value: _ClearHistoryScope.all,
                      groupValue: scope,
                      onChanged: (v) => setDialogState(() => scope = v!),
                    ),
                    RadioListTile<_ClearHistoryScope>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('One year (all months)'),
                      value: _ClearHistoryScope.year,
                      groupValue: scope,
                      onChanged: (v) => setDialogState(() => scope = v!),
                    ),
                    if (scope == _ClearHistoryScope.year)
                      Padding(
                        padding: const EdgeInsets.only(left: 32, bottom: 8),
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: selectedYear,
                          items: years
                              .map((y) => DropdownMenuItem(
                              value: y, child: Text('$y')))
                              .toList(),
                          onChanged: (v) =>
                              setDialogState(() => selectedYear = v!),
                        ),
                      ),
                    RadioListTile<_ClearHistoryScope>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('One month'),
                      value: _ClearHistoryScope.month,
                      groupValue: scope,
                      onChanged: (v) => setDialogState(() => scope = v!),
                    ),
                    if (scope == _ClearHistoryScope.month)
                      Padding(
                        padding: const EdgeInsets.only(left: 32),
                        child: Row(
                          children: [
                            Expanded(
                              child: DropdownButton<int>(
                                isExpanded: true,
                                value: selectedMonth,
                                items: List.generate(
                                  12,
                                      (i) => DropdownMenuItem(
                                    value: i + 1,
                                    child: Text(kStaffHistoryMonthNames[i]),
                                  ),
                                ),
                                onChanged: (v) =>
                                    setDialogState(() => selectedMonth = v!),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButton<int>(
                                isExpanded: true,
                                value: selectedYear,
                                items: years
                                    .map((y) => DropdownMenuItem(
                                    value: y, child: Text('$y')))
                                    .toList(),
                                onChanged: (v) =>
                                    setDialogState(() => selectedYear = v!),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    _confirmAndClearHistory(scope, selectedMonth, selectedYear);
                  },
                  child: const Text('Clear'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// A second, explicit confirmation naming exactly what will be deleted —
  /// bulk deletes are hard to undo, so this is a deliberate extra step
  /// beyond the single-record delete's one dialog.
  Future<void> _confirmAndClearHistory(
      _ClearHistoryScope scope, int month, int year) async {
    final label = switch (scope) {
      _ClearHistoryScope.all => 'ALL salary history records',
      _ClearHistoryScope.year => 'all records for $year',
      _ClearHistoryScope.month =>
      'all records for ${kStaffHistoryMonthNames[month - 1]} $year',
    };

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Are you sure?'),
        content: Text(
          'This will permanently delete $label.\n\nThis cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      switch (scope) {
        case _ClearHistoryScope.all:
          await _historyService.deleteAll();
          break;
        case _ClearHistoryScope.year:
          await _historyService.deleteByYear(year);
          break;
        case _ClearHistoryScope.month:
          await _historyService.deleteByMonth(month, year);
          break;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cleared $label'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

enum _ClearHistoryScope { all, year, month }