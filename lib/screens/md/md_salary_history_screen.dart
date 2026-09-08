// lib/screens/md/md_salary_history_screen.dart
//
// MD Salary History — immutable-log view of every saved
// md_salary_history record, grouped by month with PDF export and
// delete, mirroring the Labour Salary History screen's layout and
// interaction pattern.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

import '../../models/md_salary_history_model.dart';
import '../../services/md_salary_history_service.dart';
import '../../services/pdf/md_payroll_pdf_service.dart';

// ── Local theme constants (teal, matches MDColors in md_shell_screen.dart) ──
class _MDHistoryColors {
  static const primary = Color(0xFF00695C);
  static const primaryDark = Color(0xFF004D40);
  static const background = Color(0xFFF5F6F7);
  static const cardBorder = Color(0xFFE3E6E8);
}

class MDSalaryHistoryScreen extends StatefulWidget {
  const MDSalaryHistoryScreen({super.key});

  @override
  State<MDSalaryHistoryScreen> createState() => _MDSalaryHistoryScreenState();
}

class _MDSalaryHistoryScreenState extends State<MDSalaryHistoryScreen> {
  final MDSalaryHistoryService _historyService = MDSalaryHistoryService();
  final MDPayrollPdfService _pdfService = MDPayrollPdfService();

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _horizontalController = ScrollController();

  String _searchText = '';
  String _selectedMonthFilter = 'All';
  String _selectedYearFilter = 'All';

  final List<String> _monthFilters = ['All', ...kMDHistoryMonthNames];

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
                                    child: Text(kMDHistoryMonthNames[i]),
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
      'all records for ${kMDHistoryMonthNames[month - 1]} $year',
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
          SnackBar(content: Text('Failed to clear history: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Saves PDF bytes to disk via a native "Save As" dialog. Used instead
  /// of Printing.sharePdf, which silently no-ops on Windows desktop
  /// (there's no OS share sheet for it to hand off to there), and
  /// without file_picker's save dialog (which kept hitting version
  /// resolution issues) — this writes straight to the Downloads folder
  /// (falling back to the app's documents folder if that's unavailable).
  /// Opens a saved file with the OS's default handler (PDF viewer) — no
  /// extra package needed, just the platform's own file-open command.
  Future<void> _openFile(String path) async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer', [path]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [path]);
      }
    } catch (_) {
      // If the OS can't open it, the file's still safely on disk —
      // nothing more useful to do here.
    }
  }

  /// Saves the PDF to the Downloads folder and opens it immediately —
  /// no extra confirmation step, matching the friend's Labour version.
  Future<void> _savePdfToDisk(List<int> bytes, String suggestedName) async {
    try {
      Directory? dir = await getDownloadsDirectory();
      dir ??= await getApplicationDocumentsDirectory();

      // Strip characters that aren't valid in a Windows/macOS/Linux filename.
      final safeName = suggestedName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      var file = File('${dir.path}${Platform.pathSeparator}$safeName');

      // Don't silently overwrite an earlier export of the same month —
      // append (1), (2), ... instead.
      var counter = 1;
      final base = safeName.endsWith('.pdf')
          ? safeName.substring(0, safeName.length - 4)
          : safeName;
      while (await file.exists()) {
        file = File(
            '${dir.path}${Platform.pathSeparator}$base ($counter).pdf');
        counter++;
      }

      await file.writeAsBytes(bytes);
      await _openFile(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _MDHistoryColors.background,
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
                color: _MDHistoryColors.primaryDark,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Immutable log of every MD salary run.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search MD ID / Name / Account Number',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _MDHistoryColors.cardBorder),
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
                    backgroundColor: _MDHistoryColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 18),
                  ),
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear Filters'),
                ),
                const SizedBox(width: 12),
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
              child: StreamBuilder<List<MDSalaryHistoryModel>>(
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
                    final searchMatch =
                        s.MDId.toLowerCase().contains(_searchText) ||
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

                  final Map<String, List<MDSalaryHistoryModel>> grouped = {};
                  for (final h in filtered) {
                    grouped.putIfAbsent(h.monthLabel, () => []).add(h);
                  }
                  for (final list in grouped.values) {
                    list.sort((a, b) => a.MDId.compareTo(b.MDId));
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
                          border: Border.all(color: _MDHistoryColors.cardBorder),
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
                                    color: _MDHistoryColors.primaryDark,
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
                                    await _savePdfToDisk(
                                      pdf,
                                      '$monthLabel MD Salary Register.pdf',
                                    );
                                  },
                                  icon: const Icon(Icons.picture_as_pdf,
                                      size: 18),
                                  label: const Text('PDF'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _MDHistoryColors.primaryDark,
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
                                    try {
                                      await Printing.layoutPdf(
                                          onLayout: (_) async => pdf);
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Printing not available here — saving PDF instead ($e)'),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                      }
                                      await _savePdfToDisk(
                                        pdf,
                                        '$monthLabel MD Salary Register.pdf',
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.print, size: 18),
                                  label: const Text('Print'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _MDHistoryColors.primaryDark,
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
                                  const BoxConstraints(minWidth: 1550),
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(
                                        _MDHistoryColors.primaryDark),
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
                                      DataColumn(label: Text('MD ID')),
                                      DataColumn(label: Text('Name')),
                                      DataColumn(label: Text('Account No')),
                                      DataColumn(label: Text('Working')),
                                      DataColumn(label: Text('Present')),
                                      DataColumn(label: Text('Gross')),
                                      DataColumn(label: Text('PF')),
                                      DataColumn(label: Text('Insurance')),
                                      DataColumn(label: Text('Welfare')),
                                      DataColumn(label: Text('TDS')),
                                      DataColumn(label: Text('Deduction')),
                                      DataColumn(label: Text('Net Salary')),
                                      DataColumn(label: Text('Action')),
                                    ],
                                    rows: records.map((r) {
                                      return DataRow(cells: [
                                        DataCell(Text(r.MDId)),
                                        DataCell(Text(r.name)),
                                        DataCell(Text(r.bankAccount.isEmpty
                                            ? '-'
                                            : r.bankAccount)),
                                        DataCell(Text('${r.workingDays}')),
                                        DataCell(Text(_fmtDays(r.presentDays))),
                                        DataCell(Text(
                                            '₹${r.grossWages.toStringAsFixed(0)}')),
                                        DataCell(Text(
                                            '₹${r.pfAmount.toStringAsFixed(0)}')),
                                        DataCell(Text(
                                            '₹${r.insurance.toStringAsFixed(0)}')),
                                        DataCell(Text(
                                            '₹${r.welfare.toStringAsFixed(0)}')),
                                        DataCell(Text(
                                            '₹${r.tds.toStringAsFixed(0)}')),
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
                                                color: Colors.red, size: 20),
                                            tooltip: 'Delete record',
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

  Future<void> _showDeleteDialog(MDSalaryHistoryModel record) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Salary Record'),
        content: Text(
          'Are you sure you want to delete the salary record of\n\n'
              '${record.name}\n(${record.MDId})\n\n'
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

  Future<void> _deleteRecord(MDSalaryHistoryModel record) async {
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

enum _ClearHistoryScope { all, year, month }