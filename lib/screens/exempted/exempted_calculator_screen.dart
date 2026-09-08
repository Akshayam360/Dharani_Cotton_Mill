// lib/screens/exempted/exempted_calculator_screen.dart
//
// Exempted Salary Calculator — much simpler than MD's, since Exempted
// staff have no PF/ESI/TDS. Just:
//
//   Standard Working Days = 26/month
//   Gross Wages = (Monthly Salary / 26) x Present Days
//   Net Salary  = Gross Wages - (Insurance + Welfare)
//
// Flow: type an Emp ID -> live suggestions from `exempted_management` ->
// pick one -> enter Present Days -> Calculate -> slip renders on the
// right -> Save History writes one doc to `exempted_salary_history`
// (blocked if that employee already has a saved record for the
// selected month/year).

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'exempted_management_screen.dart' show ExemptedRecord;

const int kExemptedStandardWorkingDays = 26;
const List<String> kExemptedMonthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];

// ── Local theme constants (deep teal, matches Exempted role theme) ──
class _ExemptedCalcColors {
  static const primaryDark = Color(0xFF00838F);
  static const gradientLight = Color(0xFF00828E);
  static const background = Color(0xFFF5F6F7);
  static const cardBorder = Color(0xFFE3E6E8);

  static const buttonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradientLight, Color(0xFF00838F)],
  );
}

class ExemptedCalculatorScreen extends StatefulWidget {
  const ExemptedCalculatorScreen({super.key});

  @override
  State<ExemptedCalculatorScreen> createState() =>
      _ExemptedCalculatorScreenState();
}

class _ExemptedCalculatorScreenState extends State<ExemptedCalculatorScreen> {
  final _empIdCtrl = TextEditingController();
  final _presentDaysCtrl = TextEditingController(text: '26');

  int _selectedMonthIndex = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  int _workingDays = kExemptedStandardWorkingDays;

  ExemptedRecord? _record;
  bool _loadingRecord = false;
  String? _recordError;

  List<ExemptedRecord> _suggestions = [];
  Timer? _debounce;

  _ExemptedSalaryResult? _result;
  bool _saving = false;
  bool _checkingDuplicate = false;

  final CollectionReference<Map<String, dynamic>> _empRef =
  FirebaseFirestore.instance.collection('exempted_management');
  final CollectionReference<Map<String, dynamic>> _historyRef =
  FirebaseFirestore.instance.collection('exempted_salary_history');

  @override
  void initState() {
    super.initState();
    _empIdCtrl.addListener(_onEmpIdChanged);
    _presentDaysCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _empIdCtrl.removeListener(_onEmpIdChanged);
    _empIdCtrl.dispose();
    _presentDaysCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // -------------------------------------------------------------------
  // Emp ID — live suggestions + selection (case-insensitive, matching
  // MD Calculator's fix — Firestore range queries are case-sensitive,
  // so this filters client-side instead).
  // -------------------------------------------------------------------
  void _onEmpIdChanged() {
    final text = _empIdCtrl.text.trim();

    if (_record != null && text != _record!.empId) {
      setState(() {
        _record = null;
        _result = null;
      });
    }

    _debounce?.cancel();
    if (text.isEmpty) {
      setState(() {
        _suggestions = [];
        _recordError = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () => _searchRecords(text));
  }

  Future<void> _searchRecords(String text) async {
    try {
      final snap = await _empRef.get();
      if (!mounted) return;
      final query = text.toLowerCase();
      final matches = snap.docs
          .map((d) => ExemptedRecord.fromDoc(d))
          .where((r) => r.empId.toLowerCase().startsWith(query))
          .take(5)
          .toList();
      setState(() => _suggestions = matches);
    } catch (_) {
      // Silently ignore search errors — the manual submit still works.
    }
  }

  void _selectRecord(ExemptedRecord record) {
    _empIdCtrl.removeListener(_onEmpIdChanged);
    _empIdCtrl.text = record.empId;
    _empIdCtrl.addListener(_onEmpIdChanged);
    setState(() {
      _record = record;
      _recordError = null;
      _suggestions = [];
      _result = null;
    });
  }

  Future<void> _fetchRecord() async {
    final id = _empIdCtrl.text.trim();
    if (id.isEmpty) {
      setState(() {
        _recordError = 'Enter an Emp ID';
        _record = null;
        _result = null;
      });
      return;
    }
    setState(() {
      _loadingRecord = true;
      _recordError = null;
      _result = null;
      _suggestions = [];
    });
    try {
      final snap = await _empRef.get();
      final lowerId = id.toLowerCase();
      ExemptedRecord? match;
      for (final doc in snap.docs) {
        final record = ExemptedRecord.fromDoc(doc);
        if (record.empId.toLowerCase() == lowerId) {
          match = record;
          break;
        }
      }
      if (match == null) {
        setState(() {
          _record = null;
          _recordError = 'No Exempted record found for ID "$id"';
        });
      } else {
        setState(() {
          _record = match;
          _recordError = null;
        });
      }
    } catch (e) {
      setState(() => _recordError = 'Failed to fetch record: $e');
    } finally {
      if (mounted) setState(() => _loadingRecord = false);
    }
  }

  // -------------------------------------------------------------------
  // CALCULATE
  // -------------------------------------------------------------------
  double get _presentDaysValue =>
      double.tryParse(_presentDaysCtrl.text.trim()) ?? 0;
  double get _absentDays =>
      (_workingDays - _presentDaysValue).clamp(0, _workingDays.toDouble());

  String _fmtDays(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  void _calculate() {
    final record = _record;
    if (record == null) {
      _showSnack('Select a valid Emp ID first', isError: true);
      return;
    }
    final presentDays = _presentDaysValue;
    if (presentDays > _workingDays) {
      _showSnack(
        'Present Days (${_fmtDays(presentDays)}) cannot exceed Working Days ($_workingDays)',
        isError: true,
      );
      return;
    }

    final perDay = record.monthlySalary / _workingDays;
    final grossWages = perDay * presentDays;
    final insurance = record.insurance;
    final welfare = record.welfare;
    final totalDeductions = insurance + welfare;
    final netSalary = grossWages - totalDeductions;

    setState(() {
      _result = _ExemptedSalaryResult(
        month: _selectedMonthIndex,
        year: _selectedYear,
        workingDays: _workingDays,
        presentDays: presentDays,
        grossWages: grossWages,
        insurance: insurance,
        welfare: welfare,
        totalDeductions: totalDeductions,
        netSalary: netSalary,
      );
    });
  }

  // -------------------------------------------------------------------
  // SAVE HISTORY — blocked if this employee already has a record for
  // the selected month/year.
  // -------------------------------------------------------------------
  Future<void> _saveHistory() async {
    final record = _record;
    final result = _result;
    if (record == null || result == null) return;

    setState(() => _checkingDuplicate = true);
    try {
      final existing = await _historyRef
          .where('empId', isEqualTo: record.empId)
          .where('year', isEqualTo: result.year)
          .where('month', isEqualTo: result.month)
          .limit(1)
          .get();
      if (!mounted) return;
      if (existing.docs.isNotEmpty) {
        _showSnack(
          '${record.name} already has a saved salary for ${_monthLabel(result.month, result.year)}',
          isError: true,
        );
        setState(() => _checkingDuplicate = false);
        return;
      }
    } catch (e) {
      setState(() => _checkingDuplicate = false);
      _showSnack('Failed to check existing records: $e', isError: true);
      return;
    }
    setState(() {
      _checkingDuplicate = false;
      _saving = true;
    });

    try {
      await _historyRef.add({
        'empId': record.empId,
        'name': record.name,
        'bankAccount': record.bankAccount,
        'month': result.month,
        'year': result.year,
        'workingDays': result.workingDays,
        'presentDays': result.presentDays,
        'grossWages': result.grossWages,
        'insurance': result.insurance,
        'welfare': result.welfare,
        'totalDeductions': result.totalDeductions,
        'netSalary': result.netSalary,
        'generatedAt': FieldValue.serverTimestamp(),
      });
      _showSnack('Salary history saved successfully');
    } catch (e) {
      _showSnack('Failed to save history: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _monthLabel(int month, int year) =>
      '${kExemptedMonthNames[month - 1]} $year';

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _ExemptedCalcColors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 1000;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Salary Calculator',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: _ExemptedCalcColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Calculate Exempted salary with present days and flat deductions.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                isNarrow
                    ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputCard(),
                    const SizedBox(height: 20),
                    _buildSlipCard(),
                  ],
                )
                    : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: _buildInputCard()),
                    const SizedBox(width: 20),
                    Expanded(flex: 6, child: _buildSlipCard()),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------------
  // INPUT CARD
  // -------------------------------------------------------------------
  Widget _buildInputCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _ExemptedCalcColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _FieldShell(
                  label: 'Month',
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: _selectedMonthIndex,
                      items: List.generate(
                        12,
                            (i) => DropdownMenuItem(
                          value: i + 1,
                          child: Text(kExemptedMonthNames[i],
                              style: const TextStyle(fontSize: 15)),
                        ),
                      ),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedMonthIndex = v);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _FieldShell(
                  label: 'Year',
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: _selectedYear,
                      items: List.generate(
                        11,
                            (i) => DateTime.now().year - 5 + i,
                      ).map((y) => DropdownMenuItem(
                        value: y,
                        child: Text('$y', style: const TextStyle(fontSize: 15)),
                      )).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedYear = v);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: _NumberField(
                  label: 'Working Days',
                  value: _workingDays,
                  max: 31,
                  onChanged: (v) => setState(() => _workingDays = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FieldShell(
            label: 'Emp ID',
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _empIdCtrl,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Start typing e.g. EMP001',
                    ),
                    onSubmitted: (_) => _fetchRecord(),
                  ),
                ),
                _loadingRecord
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : (_record != null
                    ? Icon(Icons.check_circle,
                    size: 20, color: Colors.green.shade600)
                    : IconButton(
                  icon: const Icon(Icons.search, size: 20),
                  onPressed: _fetchRecord,
                )),
              ],
            ),
          ),
          if (_suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _ExemptedCalcColors.cardBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _suggestions
                    .map((rec) => InkWell(
                  onTap: () => _selectRecord(rec),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Text(rec.empId,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(rec.name,
                              style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 13),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                ))
                    .toList(),
              ),
            ),
          if (_recordError != null) ...[
            const SizedBox(height: 8),
            Text(_recordError!,
                style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
          ],
          if (_record != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _ExemptedCalcColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 16, color: Colors.green.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_record!.name} · ₹${_record!.monthlySalary.toStringAsFixed(0)}/mo',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _presentDaysCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Present Days',
                  helperText: 'Use .5 for a half day',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Absent Days : ${_fmtDays(_absentDays)}',
                style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: _ExemptedCalcColors.buttonGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: _calculate,
              child: const Text('Calculate Salary',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------
  // SALARY SLIP CARD
  // -------------------------------------------------------------------
  Widget _buildSlipCard() {
    final r = _result;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _ExemptedCalcColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('SALARY SLIP',
                      style: TextStyle(
                          letterSpacing: 1.5, fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(
                    _record?.name ?? '-',
                    style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(_monthLabel(_selectedMonthIndex, _selectedYear),
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
              OutlinedButton.icon(
                onPressed: (r == null || _saving || _checkingDuplicate)
                    ? null
                    : _saveHistory,
                icon: (_saving || _checkingDuplicate)
                    ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_outlined, size: 16),
                label: const Text('Save History'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _ExemptedCalcColors.primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                  child: _statTile('WORKING', r == null ? '-' : '${r.workingDays}')),
              const SizedBox(width: 12),
              Expanded(
                  child: _statTile(
                      'PRESENT', r == null ? '-' : _fmtDays(r.presentDays))),
              const SizedBox(width: 12),
              Expanded(
                child: _statTile(
                    'ABSENT',
                    r == null
                        ? '-'
                        : _fmtDays((r.workingDays - r.presentDays)
                        .clamp(0, r.workingDays.toDouble()))),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: _ExemptedCalcColors.cardBorder),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _slipRow('Gross Wages', r?.grossWages, bold: true, noBorder: true),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: _ExemptedCalcColors.cardBorder),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _slipRow('Insurance', r?.insurance),
                _slipRow('Welfare', r?.welfare),
                _slipRow('Total Deductions', r?.totalDeductions,
                    bold: true, noBorder: true),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: _ExemptedCalcColors.primaryDark,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Net Salary',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
                Text(
                  r == null ? '₹0.00' : '₹${r.netSalary.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: _ExemptedCalcColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: Colors.grey, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _slipRow(String label, double? value,
      {bool bold = false, bool noBorder = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: noBorder
          ? null
          : BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _ExemptedCalcColors.cardBorder, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                  color: bold ? _ExemptedCalcColors.primaryDark : Colors.grey.shade700)),
          Text(
            value == null ? '₹0.00' : '₹${value.toStringAsFixed(2)}',
            style: TextStyle(
                fontSize: 14,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: bold ? _ExemptedCalcColors.primaryDark : Colors.black87),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// RESULT MODEL
// ---------------------------------------------------------------------------
class _ExemptedSalaryResult {
  final int month;
  final int year;
  final int workingDays;
  final double presentDays;
  final double grossWages;
  final double insurance;
  final double welfare;
  final double totalDeductions;
  final double netSalary;

  _ExemptedSalaryResult({
    required this.month,
    required this.year,
    required this.workingDays,
    required this.presentDays,
    required this.grossWages,
    required this.insurance,
    required this.welfare,
    required this.totalDeductions,
    required this.netSalary,
  });
}

// ---------------------------------------------------------------------------
// SMALL SHARED WIDGETS
// ---------------------------------------------------------------------------
class _FieldShell extends StatelessWidget {
  final String label;
  final Widget child;
  const _FieldShell({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: _ExemptedCalcColors.cardBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 2),
          child,
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final String label;
  final int value;
  final int? max;
  final int min;
  final ValueChanged<int> onChanged;
  const _NumberField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.max,
    this.min = 0,
  });

  @override
  Widget build(BuildContext context) {
    return _FieldShell(
      label: label,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$value', style: const TextStyle(fontSize: 15)),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () {
                  if (max == null || value < max!) onChanged(value + 1);
                },
                child: const Icon(Icons.keyboard_arrow_up, size: 18),
              ),
              InkWell(
                onTap: () {
                  if (value > min) onChanged(value - 1);
                },
                child: const Icon(Icons.keyboard_arrow_down, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}