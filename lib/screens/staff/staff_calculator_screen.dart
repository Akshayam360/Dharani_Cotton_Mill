// lib/screens/staff/staff_salary_calculator_screen.dart
//
// Staff Salary Calculator — monthly salary calculation for a single staff
// member, mirroring the Labour Salary Calculator's two-panel layout
// (inputs left, salary slip right) but built around the Staff formula:
//
//   Per Day Salary   = Monthly Salary / Working Days
//   Effective Salary = Days Worked × Per Day Salary   (LOP-style prorate)
//   Base Salary      = 60% of Effective Salary
//   HRA              = 40% of Effective Salary
//   Gross Salary     = Effective Salary + Production Allowance (entered per month)
//   PF               = 12% of Base Salary     [only if staff.pfEnabled]
//   ESI              = 0.75% of Effective Salary (Base + HRA)  [only if staff.esiEnabled]
//   LIC              = flat ₹ (from staff profile, 0 if not applicable)
//   Mess             = same amount as PF
//   Welfare          = flat ₹ (from staff profile)
//   Net Salary       = Gross Salary − (PF + ESI + LIC + Mess + Welfare)
//
// Flow: type a Staff ID -> live suggestions from `staff` -> pick one ->
// enter Days Worked for the selected month -> Calculate Salary -> slip
// renders on the right -> Save History writes one doc to
// `staff_salary_history` (blocked if that staff already has a saved
// record for the selected month/year).

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'staff_management_screen.dart' show StaffModel, StaffColors;

const int kStandardWorkingDays = 26;
const List<String> kMonthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];

class StaffSalaryCalculatorScreen extends StatefulWidget {
  const StaffSalaryCalculatorScreen({super.key});

  @override
  State<StaffSalaryCalculatorScreen> createState() =>
      _StaffSalaryCalculatorScreenState();
}

class _StaffSalaryCalculatorScreenState
    extends State<StaffSalaryCalculatorScreen> {
  final _staffIdCtrl = TextEditingController();
  final _daysWorkedCtrl = TextEditingController(text: '26');
  final _productionAllowanceCtrl = TextEditingController(text: '0');

  int _selectedMonthIndex = DateTime.now().month; // 1-12
  int _selectedYear = DateTime.now().year;
  int _workingDays = kStandardWorkingDays;

  StaffModel? _staff;
  bool _loadingStaff = false;
  String? _staffError;

  List<StaffModel> _suggestions = [];
  Timer? _debounce;

  _StaffSalaryResult? _result;
  bool _saving = false;
  bool _checkingDuplicate = false;

  final CollectionReference<Map<String, dynamic>> _staffRef =
  FirebaseFirestore.instance.collection('staff');
  final CollectionReference<Map<String, dynamic>> _historyRef =
  FirebaseFirestore.instance.collection('staff_salary_history');

  @override
  void initState() {
    super.initState();
    _staffIdCtrl.addListener(_onStaffIdChanged);
    _daysWorkedCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _staffIdCtrl.removeListener(_onStaffIdChanged);
    _staffIdCtrl.dispose();
    _daysWorkedCtrl.dispose();
    _productionAllowanceCtrl.dispose();
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
  // STAFF ID — live suggestions + selection
  // -------------------------------------------------------------------
  void _onStaffIdChanged() {
    final text = _staffIdCtrl.text.trim();

    // If the typed text no longer matches the currently loaded staff,
    // clear the stale profile + any calculated result. Compared in
    // uppercase since Staff IDs are stored uppercase (ST001) but the
    // user may type lower/mixed case.
    if (_staff != null && text.toUpperCase() != _staff!.staffId) {
      setState(() {
        _staff = null;
        _result = null;
      });
    }

    _debounce?.cancel();
    if (text.isEmpty) {
      setState(() {
        _suggestions = [];
        _staffError = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () => _searchStaff(text));
  }

  Future<void> _searchStaff(String text) async {
    // Staff IDs are stored uppercase (ST001), so normalize whatever the
    // user typed — "st", "St001", "ST001" all search the same way.
    final query = text.toUpperCase();
    try {
      final snap = await _staffRef
          .orderBy(FieldPath.documentId)
          .startAt([query])
          .endAt(['$query\uf8ff'])
          .limit(5)
          .get();
      if (!mounted) return;
      setState(() {
        _suggestions = snap.docs.map((d) => StaffModel.fromDoc(d)).toList();
      });
    } catch (_) {
      // Silently ignore search errors — the manual submit still works.
    }
  }

  void _selectStaff(StaffModel staff) {
    _staffIdCtrl.removeListener(_onStaffIdChanged);
    _staffIdCtrl.text = staff.staffId;
    _staffIdCtrl.addListener(_onStaffIdChanged);
    _productionAllowanceCtrl.text = '0';
    setState(() {
      _staff = staff;
      _staffError = null;
      _suggestions = [];
      _result = null;
    });
  }

  Future<void> _fetchStaff() async {
    // Normalize to uppercase to match stored Staff IDs (ST001), so
    // "st001" or "St001" still finds the right record.
    final id = _staffIdCtrl.text.trim().toUpperCase();
    if (id.isEmpty) {
      setState(() {
        _staffError = 'Enter a Staff ID';
        _staff = null;
        _result = null;
      });
      return;
    }
    setState(() {
      _loadingStaff = true;
      _staffError = null;
      _result = null;
      _suggestions = [];
    });
    try {
      final doc = await _staffRef.doc(id).get();
      if (!doc.exists) {
        setState(() {
          _staff = null;
          _staffError = 'No staff found for ID "$id"';
        });
      } else {
        _productionAllowanceCtrl.text = '0';
        setState(() {
          _staff = StaffModel.fromDoc(doc);
          _staffError = null;
        });
      }
    } catch (e) {
      setState(() => _staffError = 'Failed to fetch staff: $e');
    } finally {
      if (mounted) setState(() => _loadingStaff = false);
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
    final staff = _staff;
    if (staff == null) {
      _showSnack('Select a valid Staff ID first', isError: true);
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

    // LOP-style prorate: Effective Salary is the Monthly Salary reduced
    // proportionally to days actually worked, same pattern as the
    // college Staff Salary app (salaryPerDay × daysWorked).
    final perDaySalary = staff.monthlySalary / _workingDays;
    final effectiveSalary = daysWorked * perDaySalary;

    final baseSalary = effectiveSalary * 0.60;
    final hra = effectiveSalary * 0.40;

    final productionAllowance =
        double.tryParse(_productionAllowanceCtrl.text.trim()) ?? 0;
    final grossSalary = effectiveSalary + productionAllowance;

    final pf = staff.pfEnabled ? baseSalary * 0.12 : 0.0;
    final esi = staff.esiEnabled ? effectiveSalary * 0.0075 : 0.0;
    final lic = staff.lic;
    final mess = pf; // Mess bill = same amount as that month's PF (client-confirmed)
    final welfare = staff.welfare;
    final totalDeductions = pf + esi + lic + mess + welfare;
    final netSalary = grossSalary - totalDeductions;

    setState(() {
      _result = _StaffSalaryResult(
        month: _selectedMonthIndex,
        year: _selectedYear,
        workingDays: _workingDays,
        daysWorked: daysWorked,
        perDaySalary: perDaySalary,
        effectiveSalary: effectiveSalary,
        baseSalary: baseSalary,
        hra: hra,
        productionAllowance: productionAllowance,
        grossSalary: grossSalary,
        pf: pf,
        esi: esi,
        lic: lic,
        mess: mess,
        welfare: welfare,
        totalDeductions: totalDeductions,
        netSalary: netSalary,
      );
    });
  }

  // -------------------------------------------------------------------
  // SAVE HISTORY — blocked if this staff already has a record for the
  // selected month/year.
  // -------------------------------------------------------------------
  Future<void> _saveHistory() async {
    final staff = _staff;
    final result = _result;
    if (staff == null || result == null) return;

    setState(() => _checkingDuplicate = true);
    try {
      final existing = await _historyRef
          .where('staffId', isEqualTo: staff.staffId)
          .where('year', isEqualTo: result.year)
          .where('month', isEqualTo: result.month)
          .limit(1)
          .get();
      if (!mounted) return;
      if (existing.docs.isNotEmpty) {
        _showSnack(
          '${staff.name} already has a saved salary for ${_monthLabel(result.month, result.year)}',
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
        'staffId': staff.staffId,
        'name': staff.name,
        'bankAccount': staff.bankAccount,
        'month': result.month,
        'year': result.year,
        'workingDays': result.workingDays,
        'daysWorked': result.daysWorked,
        'monthlySalary': staff.monthlySalary,
        'effectiveSalary': result.effectiveSalary,
        'baseSalary': result.baseSalary,
        'hra': result.hra,
        'productionAllowance': result.productionAllowance,
        'grossSalary': result.grossSalary,
        'pfAmount': result.pf,
        'esiAmount': result.esi,
        'lic': result.lic,
        'mess': result.mess,
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
      color: StaffColors.background,
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
                    color: StaffColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Calculate staff salary with prorated days worked, PF and ESI deductions.',
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
        border: Border.all(color: StaffColors.cardBorder),
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
            label: 'Staff ID',
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _staffIdCtrl,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Start typing e.g. ST001',
                    ),
                    onSubmitted: (_) => _fetchStaff(),
                  ),
                ),
                _loadingStaff
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : (_staff != null
                    ? Icon(Icons.check_circle,
                    size: 20, color: Colors.green.shade600)
                    : IconButton(
                  icon: const Icon(Icons.search, size: 20),
                  onPressed: _fetchStaff,
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
                border: Border.all(color: StaffColors.cardBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _suggestions
                    .map((s) => InkWell(
                  onTap: () => _selectStaff(s),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Text(s.staffId,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(s.name,
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
          if (_staffError != null) ...[
            const SizedBox(height: 8),
            Text(_staffError!,
                style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
          ],
          if (_staff != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: StaffColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_staff!.name} · ₹${_staff!.monthlySalary.toStringAsFixed(0)}/month',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _daysWorkedCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
          const SizedBox(height: 16),
          TextField(
            controller: _productionAllowanceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Production Allowance',
              prefixText: '₹ ',
              helperText: 'Changes every month — edit before calculating',
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: StaffColors.primaryDark,
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
        border: Border.all(color: StaffColors.cardBorder),
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
                    _staff?.name ?? '-',
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
                  foregroundColor: StaffColors.primaryDark,
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
              border: Border.all(color: StaffColors.cardBorder),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _slipRow('Base Salary (60%)', r?.baseSalary),
                _slipRow('HRA (40%)', r?.hra),
                _slipRow('Effective Salary', r?.effectiveSalary),
                _slipRow('Production Allowance', r?.productionAllowance),
                _slipRow('Gross Salary', r?.grossSalary,
                    bold: true, noBorder: true),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: StaffColors.cardBorder),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _slipRow('PF (12%)', r?.pf),
                _slipRow('ESI (0.75%)', r?.esi),
                _slipRow('LIC', r?.lic),
                _slipRow('Mess', r?.mess),
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
              color: StaffColors.primaryDark,
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
        color: StaffColors.background,
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
          bottom: BorderSide(color: StaffColors.cardBorder, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                  color: bold ? StaffColors.primaryDark : Colors.grey.shade700)),
          Text(
            value == null ? '₹0.00' : '₹${value.toStringAsFixed(2)}',
            style: TextStyle(
                fontSize: 14,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: bold ? StaffColors.primaryDark : Colors.black87),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// RESULT MODEL
// ---------------------------------------------------------------------------
class _StaffSalaryResult {
  final int month; // 1-12
  final int year;
  final int workingDays;
  final double daysWorked;
  final double perDaySalary;
  final double effectiveSalary;
  final double baseSalary;
  final double hra;
  final double productionAllowance;
  final double grossSalary;
  final double pf;
  final double esi;
  final double lic;
  final double mess;
  final double welfare;
  final double totalDeductions;
  final double netSalary;

  _StaffSalaryResult({
    required this.month,
    required this.year,
    required this.workingDays,
    required this.daysWorked,
    required this.perDaySalary,
    required this.effectiveSalary,
    required this.baseSalary,
    required this.hra,
    required this.productionAllowance,
    required this.grossSalary,
    required this.pf,
    required this.esi,
    required this.lic,
    required this.mess,
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
        border: Border.all(color: StaffColors.cardBorder),
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