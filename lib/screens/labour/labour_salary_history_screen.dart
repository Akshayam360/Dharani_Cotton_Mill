// lib/screens/labour/labour_salary_history_screen.dart
//
// Labour Salary History — immutable-log view of every saved
// labour_salary_history record, grouped by month with PDF export and
// delete, mirroring the Staff Salary History screen's layout and
// interaction pattern.

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../models/labour_salary_history_model.dart';
import '../../services/labour_salary_history_service.dart';
import '../../services/pdf/labour_payroll_pdf_service.dart';
import 'labour_management_screen.dart' show LabourColors;

class LabourSalaryHistoryScreen extends StatefulWidget {
  const LabourSalaryHistoryScreen({super.key});

  @override
  State<LabourSalaryHistoryScreen> createState() =>
      _LabourSalaryHistoryScreenState();
}

class _LabourSalaryHistoryScreenState
    extends State<LabourSalaryHistoryScreen> {
  final LabourSalaryHistoryService _historyService =
  LabourSalaryHistoryService();
  final LabourPayrollPdfService _pdfService = LabourPayrollPdfService();

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _horizontalController = ScrollController();

  String _searchText = '';
  String _selectedMonthFilter = 'All';
  String _selectedYearFilter = 'All';

  final List<String> _monthFilters = ['All', ...kLabourHistoryMonthNames];

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
      color: LabourColors.background,
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
                color: LabourColors.primaryDark,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Immutable log of every labour salary run.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search Labour ID / Name / Account Number',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: LabourColors.cardBorder),
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
                    backgroundColor: LabourColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 18),
                  ),
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<List<LabourSalaryHistoryModel>>(
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
                    final searchMatch = s.labourId
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

                  final Map<String, List<LabourSalaryHistoryModel>> grouped =
                  {};
                  for (final h in filtered) {
                    grouped.putIfAbsent(h.monthLabel, () => []).add(h);
                  }
                  for (final list in grouped.values) {
                    list.sort((a, b) => a.labourId.compareTo(b.labourId));
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
                          border: Border.all(color: LabourColors.cardBorder),
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
                                    color: LabourColors.primaryDark,
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
                                      '$monthLabel Labour Salary Register.pdf',
                                    );
                                  },
                                  icon: const Icon(Icons.picture_as_pdf,
                                      size: 18),
                                  label: const Text('PDF'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: LabourColors.primaryDark,
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
                                    backgroundColor: LabourColors.primaryDark,
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
                                        LabourColors.primaryDark),
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
                                      DataColumn(label: Text('Labour ID')),
                                      DataColumn(label: Text('Name')),
                                      DataColumn(label: Text('Account No')),
                                      DataColumn(label: Text('Working')),
                                      DataColumn(label: Text('Worked')),
                                      DataColumn(label: Text('OT Hrs')),
                                      DataColumn(label: Text('Gross')),
                                      DataColumn(label: Text('PF')),
                                      DataColumn(label: Text('ESI')),
                                      DataColumn(label: Text('Insurance')),
                                      DataColumn(label: Text('Welfare')),
                                      DataColumn(label: Text('Deduction')),
                                      DataColumn(label: Text('Net Salary')),
                                      DataColumn(label: Text('Action')),
                                    ],
                                    rows: records.map((r) {
                                      return DataRow(cells: [
                                        DataCell(Text(r.labourId)),
                                        DataCell(Text(r.name)),
                                        DataCell(Text(r.bankAccount.isEmpty
                                            ? '-'
                                            : r.bankAccount)),
                                        DataCell(Text('${r.workingDays}')),
                                        DataCell(Text(_fmtDays(r.daysWorked))),
                                        DataCell(
                                            Text(r.otHours.toStringAsFixed(1))),
                                        DataCell(Text(
                                            '₹${r.grossWages.toStringAsFixed(0)}')),
                                        DataCell(Text(
                                            '₹${r.pfAmount.toStringAsFixed(0)}')),
                                        DataCell(Text(
                                            '₹${r.esiAmount.toStringAsFixed(2)}')),
                                        DataCell(Text(
                                            '₹${r.insurance.toStringAsFixed(0)}')),
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

  Future<void> _showDeleteDialog(LabourSalaryHistoryModel record) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Salary Record'),
        content: Text(
          'Are you sure you want to delete the salary record of\n\n'
              '${record.name}\n(${record.labourId})\n\n'
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

  Future<void> _deleteRecord(LabourSalaryHistoryModel record) async {
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
}