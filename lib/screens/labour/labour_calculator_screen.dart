// lib/screens/labour/labour_salary_calculator_screen.dart
//
// Labour Salary Calculator — monthly wage calculation for a single labour,
// mirroring the Staff Salary Calculator's two-panel layout (inputs left,
// salary slip right) but built around the Labour formula:
//
//   Base Salary   = Days Worked × Per Day Salary
//   Basic + DA    = 60% of Base Salary
//   HRA           = 40% of Base Salary
//   OT Amount     = (Per Day Salary / 8) × OT Hours
//   Gross Wages   = Base Salary + Production Allowance + OT Amount
//   PF            = 12% of (Basic + DA)     [only if labour.pfEnabled]
//   ESI           = 0.75% of HRA            [only if labour.esiEnabled]
//   Insurance     = flat ₹ (from labour profile)
//   Welfare       = flat ₹ (from labour profile)
//   Net Salary    = Gross Wages − (PF + ESI + Insurance + Welfare)
//
// Flow: type a Labour ID -> live suggestions from `labours` -> pick one ->
// enter Days Worked + OT Hours for the selected month -> Calculate Salary ->
// slip renders on the right -> Save History writes one doc to
// `labour_salary_history` (blocked if that labour already has a saved
// record for the selected month/year).

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'labour_management_screen.dart'
    show LabourModel, LabourColors, ShiftX;

const int kStandardWorkingDays = 26;
const List<String> kMonthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];

class LabourSalaryCalculatorScreen extends StatefulWidget {
  const LabourSalaryCalculatorScreen({super.key});

  @override
  State<LabourSalaryCalculatorScreen> createState() =>
      _LabourSalaryCalculatorScreenState();
}

class _LabourSalaryCalculatorScreenState
    extends State<LabourSalaryCalculatorScreen> {
  final _labourIdCtrl = TextEditingController();
  final _daysWorkedCtrl = TextEditingController(text: '26');
  final _otHoursCtrl = TextEditingController(text: '0');

  int _selectedMonthIndex = DateTime.now().month; // 1-12
  int _selectedYear = DateTime.now().year;
  int _workingDays = kStandardWorkingDays;

  LabourModel? _labour;
  bool _loadingLabour = false;
  String? _labourError;

  List<LabourModel> _suggestions = [];
  Timer? _debounce;

  _LabourSalaryResult? _result;
  bool _saving = false;
  bool _checkingDuplicate = false;

  final CollectionReference<Map<String, dynamic>> _labourRef =
  FirebaseFirestore.instance.collection('labours');
  final CollectionReference<Map<String, dynamic>> _historyRef =
  FirebaseFirestore.instance.collection('labour_salary_history');

  @override
  void initState() {
    super.initState();
    _labourIdCtrl.addListener(_onLabourIdChanged);
    _daysWorkedCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _labourIdCtrl.removeListener(_onLabourIdChanged);
    _labourIdCtrl.dispose();
    _daysWorkedCtrl.dispose();
    _otHoursCtrl.dispose();
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
  // LABOUR ID — live suggestions + selection
  // -------------------------------------------------------------------
  void _onLabourIdChanged() {
    final text = _labourIdCtrl.text.trim();

    // If the typed text no longer matches the currently loaded labour,
    // clear the stale profile + any calculated result.
    if (_labour != null && text != _labour!.labourId) {
      setState(() {
        _labour = null;
        _result = null;
      });
    }

    _debounce?.cancel();
    if (text.isEmpty) {
      setState(() {
        _suggestions = [];
        _labourError = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () => _searchLabours(text));
  }

  Future<void> _searchLabours(String text) async {
    try {
      final snap = await _labourRef
          .orderBy(FieldPath.documentId)
          .startAt([text])
          .endAt(['$text\uf8ff'])
          .limit(5)
          .get();
      if (!mounted) return;
      setState(() {
        _suggestions = snap.docs.map((d) => LabourModel.fromDoc(d)).toList();
      });
    } catch (_) {
      // Silently ignore search errors — the manual submit still works.
    }
  }

  void _selectLabour(LabourModel labour) {
    _labourIdCtrl.removeListener(_onLabourIdChanged);
    _labourIdCtrl.text = labour.labourId;
    _labourIdCtrl.addListener(_onLabourIdChanged);
    setState(() {
      _labour = labour;
      _labourError = null;
      _suggestions = [];
      _result = null;
    });
  }

  Future<void> _fetchLabour() async {
    final id = _labourIdCtrl.text.trim();
    if (id.isEmpty) {
      setState(() {
        _labourError = 'Enter a Labour ID';
        _labour = null;
        _result = null;
      });
      return;
    }
    setState(() {
      _loadingLabour = true;
      _labourError = null;
      _result = null;
      _suggestions = [];
    });
    try {
      final doc = await _labourRef.doc(id).get();
      if (!doc.exists) {
        setState(() {
          _labour = null;
          _labourError = 'No labour found for ID "$id"';
        });
      } else {
        setState(() {
          _labour = LabourModel.fromDoc(doc);
          _labourError = null;
        });
      }
    } catch (e) {
      setState(() => _labourError = 'Failed to fetch labour: $e');
    } finally {
      if (mounted) setState(() => _loadingLabour = false);
    }
  }

  // -------------------------------------------------------------------
  // CALCULATE
  // -------------------------------------------------------------------
  double get _daysWorkedValue => double.tryParse(_daysWorkedCtrl.text.trim()) ?? 0;
  double get _absentDays =>
      (_workingDays - _daysWorkedValue).clamp(0, _workingDays.toDouble());

  /// Formats a day count without a trailing ".0" for whole numbers,
  /// but keeps one decimal place for half-days (e.g. 27.5).
  String _fmtDays(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  void _calculate() {
    final labour = _labour;
    if (labour == null) {
      _showSnack('Select a valid Labour ID first', isError: true);
      return;
    }
    final daysWorked = _daysWorkedValue;
    if (daysWorked > _workingDays) {
      _showSnack(
        'Days Worked (${_fmtDays(daysWorked)}) cannot exceed Working Days ($_workingDays)',
        isError: true,
      );
      return;
    }
    final otHours = double.tryParse(_otHoursCtrl.text.trim()) ?? 0;

    final baseSalary = daysWorked * labour.perDaySalary;
    final basicDa = baseSalary * 0.60;
    final hra = baseSalary * 0.40;
    final otAmount = (labour.perDaySalary / 8) * otHours;
    final grossWages = baseSalary + labour.productionAllowance + otAmount;

    final pf = labour.pfEnabled ? basicDa * 0.12 : 0.0;
    final esi = labour.esiEnabled ? hra * 0.0075 : 0.0;
    final insurance = labour.insurance;
    final welfare = labour.welfare;
    final totalDeductions = pf + esi + insurance + welfare;
    final netSalary = grossWages - totalDeductions;

    setState(() {
      _result = _LabourSalaryResult(
        month: _selectedMonthIndex,
        year: _selectedYear,
        workingDays: _workingDays,
        daysWorked: daysWorked,
        otHours: otHours,
        baseSalary: baseSalary,
        basicDa: basicDa,
        hra: hra,
        otAmount: otAmount,
        productionAllowance: labour.productionAllowance,
        grossWages: grossWages,
        pf: pf,
        esi: esi,
        insurance: insurance,
        welfare: welfare,
        totalDeductions: totalDeductions,
        netSalary: netSalary,
      );
    });
  }

  // -------------------------------------------------------------------
  // SAVE HISTORY — blocked if this labour already has a record for the
  // selected month/year.
  // -------------------------------------------------------------------
  Future<void> _saveHistory() async {
    final labour = _labour;
    final result = _result;
    if (labour == null || result == null) return;

    setState(() => _checkingDuplicate = true);
    try {
      final existing = await _historyRef
          .where('labourId', isEqualTo: labour.labourId)
          .where('year', isEqualTo: result.year)
          .where('month', isEqualTo: result.month)
          .limit(1)
          .get();
      if (!mounted) return;
      if (existing.docs.isNotEmpty) {
        _showSnack(
          '${labour.name} already has a saved salary for ${_monthLabel(result.month, result.year)}',
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
        'labourId': labour.labourId,
        'name': labour.name,
        'month': result.month,
        'year': result.year,
        'workingDays': result.workingDays,
        'daysWorked': result.daysWorked,
        'otHours': result.otHours,
        'baseSalary': result.baseSalary,
        'otAmount': result.otAmount,
        'productionAllowance': result.productionAllowance,
        'grossWages': result.grossWages,
        'pfAmount': result.pf,
        'esiAmount': result.esi,
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

  String _monthLabel(int month, int year) => '${kMonthNames[month - 1]} $year';

  @override
  Widget build(BuildContext context) {
    return Container(
      color: LabourColors.background,
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
                    color: LabourColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Calculate labour wages with days worked, OT hours, PF and ESI deductions.',
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
        border: Border.all(color: LabourColors.cardBorder),
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
                          child: Text(kMonthNames[i],
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
            label: 'Labour ID',
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _labourIdCtrl,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Start typing e.g. LB001',
                    ),
                    onSubmitted: (_) => _fetchLabour(),
                  ),
                ),
                _loadingLabour
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : (_labour != null
                    ? Icon(Icons.check_circle,
                    size: 20, color: Colors.green.shade600)
                    : IconButton(
                  icon: const Icon(Icons.search, size: 20),
                  onPressed: _fetchLabour,
                )),
              ],
            ),
          ),
          // Suggestions render inline (not as a floating overlay) so they
          // push the rest of the form down instead of covering it.
          if (_suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: LabourColors.cardBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _suggestions
                    .map((l) => InkWell(
                  onTap: () => _selectLabour(l),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: l.shift.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(l.labourId,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(l.name,
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
          if (_labourError != null) ...[
            const SizedBox(height: 8),
            Text(_labourError!,
                style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
          ],
          if (_labour != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: LabourColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _labour!.shift.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_labour!.name} · ${_labour!.shift.label} · ₹${_labour!.perDaySalary.toStringAsFixed(0)}/day',
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _daysWorkedCtrl,
                      keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Days Worked',
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
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _otHoursCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'OT Hours'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: LabourColors.primaryDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
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
        border: Border.all(color: LabourColors.cardBorder),
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
                          letterSpacing: 1.5,
                          fontSize: 11,
                          color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(
                    _labour?.name ?? '-',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
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
                  foregroundColor: LabourColors.primaryDark,
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
                      'DAYS WORKED', r == null ? '-' : _fmtDays(r.daysWorked))),
              const SizedBox(width: 12),
              Expanded(
                  child: _statTile(
                      'OT HOURS', r == null ? '-' : r.otHours.toStringAsFixed(1))),
              const SizedBox(width: 12),
              Expanded(
                child: _statTile(
                    'ABSENT',
                    r == null
                        ? '-'
                        : _fmtDays((r.workingDays - r.daysWorked)
                        .clamp(0, r.workingDays.toDouble()))),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: LabourColors.cardBorder),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _slipRow('Base Salary', r?.baseSalary),
                _slipRow('Production Allowance', r?.productionAllowance),
                _slipRow('OT Amount', r?.otAmount),
                _slipRow('Gross Wages', r?.grossWages,
                    bold: true, noBorder: true),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: LabourColors.cardBorder),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _slipRow('PF (12%)', r?.pf),
                _slipRow('ESI (0.75%)', r?.esi),
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
              color: LabourColors.primaryDark,
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
        color: LabourColors.background,
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
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  /// A single row in the salary slip. Every row gets a thin bottom
  /// divider line (table-row look) unless [noBorder] is true, which is
  /// used for the last row of a section (e.g. "Total Deductions").
  Widget _slipRow(String label, double? value,
      {bool bold = false, bool noBorder = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: noBorder
          ? null
          : BoxDecoration(
        border: Border(
          bottom: BorderSide(color: LabourColors.cardBorder, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                  color: bold ? LabourColors.primaryDark : Colors.grey.shade700)),
          Text(
            value == null ? '₹0.00' : '₹${value.toStringAsFixed(2)}',
            style: TextStyle(
                fontSize: 14,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: bold ? LabourColors.primaryDark : Colors.black87),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// RESULT MODEL
// ---------------------------------------------------------------------------
class _LabourSalaryResult {
  final int month; // 1-12
  final int year;
  final int workingDays;
  final double daysWorked;
  final double otHours;
  final double baseSalary;
  final double basicDa;
  final double hra;
  final double otAmount;
  final double productionAllowance;
  final double grossWages;
  final double pf;
  final double esi;
  final double insurance;
  final double welfare;
  final double totalDeductions;
  final double netSalary;

  _LabourSalaryResult({
    required this.month,
    required this.year,
    required this.workingDays,
    required this.daysWorked,
    required this.otHours,
    required this.baseSalary,
    required this.basicDa,
    required this.hra,
    required this.otAmount,
    required this.productionAllowance,
    required this.grossWages,
    required this.pf,
    required this.esi,
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
        border: Border.all(color: LabourColors.cardBorder),
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