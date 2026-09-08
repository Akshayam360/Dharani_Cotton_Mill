// lib/screens/exempted/exempted_management_screen.dart
//
// Exempted Management (Master Data) screen — search + Add button +
// table, same pattern as MD Management, but with no Shift and no
// PF/ESI/TDS (Exempted staff are exempt from those statutory
// deductions — only Insurance and Welfare apply).

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ── Local theme constants (deep teal, distinct from MD's teal) ──
class _C {
  static const primary = Color(0xFF00838F);
  static const gradientLight = Color(0xFF00828E); // matches the login button's gradient
  static const background = Color(0xFFF5F6F7);
  static const cardWhite = Color(0xFFFFFFFF);
  static const cardBorder = Color(0xFFE3E6E8);
  static const textPrimary = Color(0xFF00838F);
  static const textSecondary = Color(0xFF6B7280);
  static const accentBg = Color(0xFFE0F2F1);
  static const danger = Color(0xFFD9534F);

  /// The same diagonal light→dark teal gradient used on the login
  /// screen's Login button, reused on every primary filled button here.
  static const buttonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradientLight, Color(0xFF00838F)],
  );
}

/// Master data record managed for the Exempted role.
/// Firestore collection: 'exempted_management'.
class ExemptedRecord {
  final String? docId;
  final String empId;
  final String name;
  final double monthlySalary;
  final double insurance;
  final double welfare;
  final String bankAccount;

  const ExemptedRecord({
    this.docId,
    required this.empId,
    required this.name,
    required this.monthlySalary,
    required this.insurance,
    required this.welfare,
    required this.bankAccount,
  });

  factory ExemptedRecord.fromDoc(QueryDocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return ExemptedRecord(
      docId: doc.id,
      empId: map['empId'] ?? '',
      name: map['name'] ?? '',
      monthlySalary: (map['monthlySalary'] ?? 0).toDouble(),
      insurance: (map['insurance'] ?? 0).toDouble(),
      welfare: (map['welfare'] ?? 0).toDouble(),
      bankAccount: map['bankAccount'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'empId': empId,
    'name': name,
    'monthlySalary': monthlySalary,
    'insurance': insurance,
    'welfare': welfare,
    'bankAccount': bankAccount,
  };
}

/// Salary formula helpers — reused by exempted_calculator_screen.dart.
/// Standard working days = 26/month. No PF/ESI/TDS for this role.
class ExemptedSalaryMath {
  static const int standardWorkingDays = 26;

  static Map<String, double> calculate({
    required ExemptedRecord record,
    required int presentDays,
    int standardDays = standardWorkingDays,
  }) {
    final clamped = presentDays.clamp(0, standardDays);
    final perDay = record.monthlySalary / standardDays;
    final gross = perDay * clamped;
    final totalDeductions = record.insurance + record.welfare;
    final net = gross - totalDeductions;

    return {
      'gross': gross,
      'insurance': record.insurance,
      'welfare': record.welfare,
      'totalDeductions': totalDeductions,
      'net': net,
    };
  }
}

class ExemptedManagementScreen extends StatefulWidget {
  const ExemptedManagementScreen({super.key});

  @override
  State<ExemptedManagementScreen> createState() =>
      _ExemptedManagementScreenState();
}

class _ExemptedManagementScreenState extends State<ExemptedManagementScreen> {
  final _collection =
  FirebaseFirestore.instance.collection('exempted_management');
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _horizontalScrollController = ScrollController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // SizedBox.expand forces this screen to fill the full height given by
    // the shell's Row/Expanded (Row's default crossAxisAlignment is
    // center, so without this the content would shrink to its own
    // height and end up vertically centered instead of pinned to top).
    return SizedBox.expand(
      child: Align(
        alignment: Alignment.topLeft,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Exempted Management',
                  style: TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w800, color: _C.textPrimary)),
              const SizedBox(height: 4),
              const Text('Add, edit and review every exempted master record used for payroll.',
                  style: TextStyle(fontSize: 12, color: _C.textSecondary)),
              const SizedBox(height: 20),
              _buildSearchAndAdd(),
              const SizedBox(height: 20),
              _buildTable(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndAdd() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: _C.cardWhite,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _C.cardBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, size: 18, color: _C.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(
                      hintText: 'Search by name or Emp ID...',
                      border: InputBorder.none,
                      isCollapsed: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Container(
          decoration: BoxDecoration(
            gradient: _C.buttonGradient,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ElevatedButton.icon(
            onPressed: () => _openForm(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Record'),
          ),
        ),
      ],
    );
  }

  Widget _buildTable() {
    return StreamBuilder<QuerySnapshot>(
      stream: _collection.orderBy('empId').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        var records = snapshot.data!.docs.map(ExemptedRecord.fromDoc).toList();
        if (_query.trim().isNotEmpty) {
          final q = _query.toLowerCase();
          records = records
              .where((r) =>
          r.name.toLowerCase().contains(q) ||
              r.empId.toLowerCase().contains(q))
              .toList();
        }

        if (records.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 48),
            decoration: BoxDecoration(
              color: _C.cardWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _C.cardBorder),
            ),
            alignment: Alignment.center,
            child: const Text('No records yet — tap "Add Record" to create the first one.',
                style: TextStyle(color: _C.textSecondary)),
          );
        }

        return Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _C.cardWhite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.cardBorder),
          ),
          child: ScrollbarTheme(
            data: ScrollbarThemeData(
              thickness: WidgetStateProperty.all(6),
              radius: const Radius.circular(8),
              thumbColor: WidgetStateProperty.all(_C.primary.withValues(alpha: 0.55)),
              trackColor: WidgetStateProperty.all(_C.background),
              trackBorderColor: WidgetStateProperty.all(Colors.transparent),
              crossAxisMargin: 4,
              mainAxisMargin: 4,
            ),
            child: Scrollbar(
              controller: _horizontalScrollController,
              thumbVisibility: true,
              trackVisibility: true,
              child: SingleChildScrollView(
                controller: _horizontalScrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: MediaQuery.of(context).size.width - 240 - 64,
                  ),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(_C.accentBg),
                    headingRowHeight: 52,
                    dataRowMinHeight: 64,
                    dataRowMaxHeight: 68,
                    columnSpacing: 40,
                    horizontalMargin: 24,
                    dividerThickness: 1,
                    columns: const [
                      DataColumn(label: _Header('EMP ID')),
                      DataColumn(label: _Header('NAME')),
                      DataColumn(label: _Header('BANK ACCOUNT')),
                      DataColumn(label: _Header('MONTHLY SALARY')),
                      DataColumn(label: _Header('INSURANCE')),
                      DataColumn(label: _Header('WELFARE')),
                      DataColumn(label: _Header('ACTIONS')),
                    ],
                    rows: records.map((r) {
                      return DataRow(cells: [
                        DataCell(Text(r.empId)),
                        DataCell(Text(r.name)),
                        DataCell(Text(r.bankAccount,
                            style: const TextStyle(color: _C.textSecondary))),
                        DataCell(Text('₹${r.monthlySalary.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.w600))),
                        DataCell(Text('₹${r.insurance.toStringAsFixed(0)}')),
                        DataCell(Text('₹${r.welfare.toStringAsFixed(0)}')),
                        DataCell(Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.visibility_outlined,
                                  size: 18, color: _C.textSecondary),
                              onPressed: () => _viewRecord(r),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined,
                                  size: 18, color: _C.textSecondary),
                              onPressed: () => _openForm(existing: r),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded,
                                  size: 18, color: _C.danger),
                              onPressed: () => _confirmDelete(r),
                            ),
                          ],
                        )),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _viewRecord(ExemptedRecord record) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(record.name,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _viewRow('Emp ID', record.empId),
              _viewRow('Bank Account', record.bankAccount),
              _viewRow('Monthly Salary', '₹${record.monthlySalary.toStringAsFixed(0)}'),
              _viewRow('Insurance', '₹${record.insurance.toStringAsFixed(0)}'),
              _viewRow('Welfare', '₹${record.welfare.toStringAsFixed(0)}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _openForm(existing: record);
            },
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  Widget _viewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: _C.textSecondary, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  void _confirmDelete(ExemptedRecord record) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete record?'),
        content: Text(
            'Remove ${record.name} (${record.empId})? This does not delete past salary history.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (record.docId != null) {
                await _collection.doc(record.docId).delete();
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: _C.danger)),
          ),
        ],
      ),
    );
  }

  void _openForm({ExemptedRecord? existing}) {
    showDialog(
      context: context,
      builder: (ctx) => _ExemptedRecordFormDialog(
        existing: existing,
        collection: _collection,
        onSave: (record) async {
          if (existing?.docId != null) {
            await _collection.doc(existing!.docId).update(record.toMap());
          } else {
            await _collection.add(record.toMap());
          }
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: _C.textPrimary,
            letterSpacing: 0.4));
  }
}

class _ExemptedRecordFormDialog extends StatefulWidget {
  final ExemptedRecord? existing;
  final ValueChanged<ExemptedRecord> onSave;
  final CollectionReference<Map<String, dynamic>> collection;

  const _ExemptedRecordFormDialog({
    this.existing,
    required this.onSave,
    required this.collection,
  });

  @override
  State<_ExemptedRecordFormDialog> createState() =>
      _ExemptedRecordFormDialogState();
}

class _ExemptedRecordFormDialogState extends State<_ExemptedRecordFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _empIdCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _bankCtrl;
  late final TextEditingController _salaryCtrl;
  late final TextEditingController _insuranceCtrl;
  late final TextEditingController _welfareCtrl;
  bool _isSaving = false;
  String? _empIdError;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _empIdCtrl = TextEditingController(text: e?.empId ?? '');
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _bankCtrl = TextEditingController(text: e?.bankAccount ?? '');
    _salaryCtrl = TextEditingController(text: e?.monthlySalary.toString() ?? '');
    _insuranceCtrl = TextEditingController(text: e?.insurance.toString() ?? '0');
    _welfareCtrl = TextEditingController(text: e?.welfare.toString() ?? '0');
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isEdit ? 'Edit Record' : 'Add Record',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                _field(_empIdCtrl, 'Emp ID', hint: 'e.g. EMP001', errorText: _empIdError),
                if (isEdit)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14, top: 2),
                    child: Text(
                      'Changing the Emp ID moves this record to a new ID — past salary history stays linked to the old ID.',
                      style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                _field(_nameCtrl, 'Name'),
                _field(_bankCtrl, 'Bank Account'),
                _field(_salaryCtrl, 'Monthly Salary',
                    keyboardType: TextInputType.number, isCurrency: true),
                Row(
                  children: [
                    Expanded(
                        child: _field(_insuranceCtrl, 'Insurance (flat)',
                            keyboardType: TextInputType.number, isCurrency: true)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _field(_welfareCtrl, 'Welfare (flat)',
                            keyboardType: TextInputType.number, isCurrency: true)),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                        onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        gradient: _C.buttonGradient,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _submit,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            elevation: 0),
                        child: _isSaving
                            ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                            : const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label,
      {String? hint, TextInputType? keyboardType, bool isCurrency = false, String? errorText}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixText: isCurrency ? '₹ ' : null,
          border: const OutlineInputBorder(),
          isDense: true,
          errorText: errorText,
        ),
        onChanged: (_) {
          if (errorText != null) setState(() => _empIdError = null);
        },
        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final enteredId = _empIdCtrl.text.trim();
    setState(() {
      _isSaving = true;
      _empIdError = null;
    });

    final existingDocs =
    await widget.collection.where('empId', isEqualTo: enteredId).get();
    final isDuplicate =
    existingDocs.docs.any((doc) => doc.id != widget.existing?.docId);

    if (isDuplicate) {
      setState(() {
        _isSaving = false;
        _empIdError = 'Emp ID "$enteredId" already exists — use a different one.';
      });
      return;
    }

    widget.onSave(ExemptedRecord(
      docId: widget.existing?.docId,
      empId: enteredId,
      name: _nameCtrl.text.trim(),
      monthlySalary: double.tryParse(_salaryCtrl.text) ?? 0,
      insurance: double.tryParse(_insuranceCtrl.text) ?? 0,
      welfare: double.tryParse(_welfareCtrl.text) ?? 0,
      bankAccount: _bankCtrl.text.trim(),
    ));
    if (mounted) Navigator.pop(context);
  }
}