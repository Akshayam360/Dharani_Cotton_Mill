import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ── Local theme constants (kept in sync with md_shell_screen.dart) ──
class _C {
  // Matches UserRole.md.color (teal) from role_selection_screen.dart
  static const navyDark = Color(0xFF00695C); // primary (was navy, now teal)
  static const gold = Color(0xFF00897B); // accent (teal, lighter shade)
  static const background = Color(0xFFF5F6F7);
  static const cardWhite = Color(0xFFFFFFFF);
  static const cardBorder = Color(0xFFE3E6E8);
  static const textPrimary = Color(0xFF004D40);
  static const textSecondary = Color(0xFF6B7280);
  static const mdAccent = Color(0xFF00695C);
  static const mdAccentBg = Color(0xFFE0F2F1);
  static const danger = Color(0xFFD9534F);
}

enum Shift { morning, evening, night }

extension ShiftX on Shift {
  String get label => switch (this) {
    Shift.morning => 'Morning',
    Shift.evening => 'Evening',
    Shift.night => 'Night',
  };

  static Shift fromLabel(String label) => switch (label.toLowerCase()) {
    'evening' => Shift.evening,
    'night' => Shift.night,
    _ => Shift.morning,
  };
}

/// Master data record managed by the MD role. Firestore collection: 'md_management'.
class MDRecord {
  final String? docId; // Firestore doc id, null for a not-yet-saved record
  final String MDId;
  final String name;
  final Shift shift;
  final double monthlySalary;
  final double insurance;
  final double welfare;
  final String bankAccount;
  final bool pfEnabled;
  final bool esiEnabled;
  final double tds;

  const MDRecord({
    this.docId,
    required this.MDId,
    required this.name,
    required this.shift,
    required this.monthlySalary,
    required this.insurance,
    required this.welfare,
    required this.bankAccount,
    required this.pfEnabled,
    required this.esiEnabled,
    required this.tds,
  });

  factory MDRecord.fromDoc(QueryDocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return MDRecord(
      docId: doc.id,
      MDId: map['MDId'] ?? '',
      name: map['name'] ?? '',
      shift: ShiftX.fromLabel(map['shift'] ?? 'Morning'),
      monthlySalary: (map['monthlySalary'] ?? 0).toDouble(),
      insurance: (map['insurance'] ?? 0).toDouble(),
      welfare: (map['welfare'] ?? 0).toDouble(),
      bankAccount: map['bankAccount'] ?? '',
      pfEnabled: map['pfEnabled'] ?? true,
      esiEnabled: map['esiEnabled'] ?? true,
      tds: (map['tds'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
    'MDId': MDId,
    'name': name,
    'shift': shift.label,
    'monthlySalary': monthlySalary,
    'insurance': insurance,
    'welfare': welfare,
    'bankAccount': bankAccount,
    'pfEnabled': pfEnabled,
    'esiEnabled': esiEnabled,
    'tds': tds,
  };
}

/// Salary formula helpers — reused by md_calculator_screen.dart too.
/// Standard working days = 26/month (4 days monthly leave).
class SalaryMath {
  static const int standardWorkingDays = 26;
  static const double basicDAPercent = 0.60;
  static const double hraPercent = 0.40;
  static const double pfPercent = 0.12;
  static const double esiPercent = 0.0075;

  static Map<String, double> calculate({
    required MDRecord record,
    required int presentDays,
    int standardDays = standardWorkingDays,
  }) {
    final clamped = presentDays.clamp(0, standardDays);
    final perDay = record.monthlySalary / standardDays;
    final gross = perDay * clamped;
    final basicDA = gross * basicDAPercent;
    final hra = gross * hraPercent;
    final pf = record.pfEnabled ? basicDA * pfPercent : 0.0;
    final esi = record.esiEnabled ? hra * esiPercent : 0.0;
    final totalDeductions = pf + esi + record.insurance + record.welfare + record.tds;
    final net = gross - totalDeductions;

    return {
      'gross': gross,
      'basicDA': basicDA,
      'hra': hra,
      'pf': pf,
      'esi': esi,
      'insurance': record.insurance,
      'welfare': record.welfare,
      'tds': record.tds,
      'totalDeductions': totalDeductions,
      'net': net,
    };
  }
}

/// MD Management (Master Data) screen — search + Add button + table,
/// same pattern as the Staff Management reference screen.
class MDManagementScreen extends StatefulWidget {
  const MDManagementScreen({super.key});

  @override
  State<MDManagementScreen> createState() => _MDManagementScreenState();
}

class _MDManagementScreenState extends State<MDManagementScreen> {
  final _collection = FirebaseFirestore.instance.collection('md_management');
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
    // the shell's Row/Expanded (Row's default crossAxisAlignment is center,
    // so without this the content would shrink to its own height and end
    // up vertically centered instead of pinned to the top).
    return SizedBox.expand(
      child: Align(
        alignment: Alignment.topLeft,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('MD Management',
                  style: TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w800, color: _C.textPrimary)),
              const SizedBox(height: 4),
              const Text('Add, edit and review every md master record used for payroll.',
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
                      hintText: 'Search by name or md ID...',
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
        ElevatedButton.icon(
          onPressed: () => _openForm(),
          style: ElevatedButton.styleFrom(
            backgroundColor: _C.navyDark,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add Record'),
        ),
      ],
    );
  }

  Widget _buildTable() {
    return StreamBuilder<QuerySnapshot>(
      stream: _collection.orderBy('MDId').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        var records = snapshot.data!.docs.map(MDRecord.fromDoc).toList();
        if (_query.trim().isNotEmpty) {
          final q = _query.toLowerCase();
          records = records
              .where((r) =>
          r.name.toLowerCase().contains(q) ||
              r.MDId.toLowerCase().contains(q))
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
              thumbColor: WidgetStateProperty.all(_C.mdAccent.withValues(alpha: 0.55)),
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
                padding: const EdgeInsets.only(bottom: 16), // room for the slim scrollbar
                child: ConstrainedBox(
                  // Force the table to be at least as wide as the visible area
                  // so short tables still stretch edge-to-edge like the
                  // reference Labour Management screen, instead of hugging
                  // the left side with dead space on the right.
                  constraints: BoxConstraints(
                    minWidth: MediaQuery.of(context).size.width - 240 - 64,
                  ),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(_C.background),
                    headingRowHeight: 52,
                    dataRowMinHeight: 64,
                    dataRowMaxHeight: 68,
                    columnSpacing: 40,
                    horizontalMargin: 24,
                    dividerThickness: 1, // horizontal line under every row
                    columns: const [
                      DataColumn(label: _Header('MD ID')),
                      DataColumn(label: _Header('NAME')),
                      DataColumn(label: _Header('SHIFT')),
                      DataColumn(label: _Header('BANK ACCOUNT')),
                      DataColumn(label: _Header('MONTHLY SALARY')),
                      DataColumn(label: _Header('PF')),
                      DataColumn(label: _Header('ESI')),
                      DataColumn(label: _Header('INSURANCE')),
                      DataColumn(label: _Header('WELFARE')),
                      DataColumn(label: _Header('TDS')),
                      DataColumn(label: _Header('ACTIONS')),
                    ],
                    rows: records.map((r) {
                      return DataRow(cells: [
                        DataCell(Text(r.MDId,
                            style: const TextStyle(fontWeight: FontWeight.w600))),
                        DataCell(Text(r.name)),
                        DataCell(_shiftChip(r.shift.label)),
                        DataCell(Text(r.bankAccount,
                            style: const TextStyle(color: _C.textSecondary))),
                        DataCell(Text('₹${r.monthlySalary.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.w600))),
                        DataCell(_boolChip(r.pfEnabled)),
                        DataCell(_boolChip(r.esiEnabled)),
                        DataCell(Text('₹${r.insurance.toStringAsFixed(0)}')),
                        DataCell(Text('₹${r.welfare.toStringAsFixed(0)}')),
                        DataCell(Text('₹${r.tds.toStringAsFixed(0)}')),
                        DataCell(Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.visibility_outlined,
                                  size: 18, color: _C.textSecondary),
                              onPressed: () => _viewRecord(r),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.edit_outlined,
                                  size: 18, color: _C.textSecondary),
                              onPressed: () => _openForm(existing: r),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
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

  Widget _shiftChip(String label) {
    // Teal-family shades per shift, matching the MD role theme instead of orange.
    final Color bg;
    final Color fg;
    switch (label) {
      case 'Morning':
        bg = _C.mdAccentBg; // light teal
        fg = _C.mdAccent;
        break;
      case 'Evening':
        bg = const Color(0xFFE0F7FA); // light cyan-teal
        fg = const Color(0xFF00838F);
        break;
      default: // Night
        bg = const Color(0xFFE8EAF6); // light indigo-teal
        fg = const Color(0xFF3949AB);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  Widget _boolChip(bool value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: value ? _C.mdAccentBg : _C.background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(value ? 'Yes' : '--',
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: value ? _C.mdAccent : _C.textSecondary)),
    );
  }

  void _viewRecord(MDRecord record) {
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
              _viewRow('MD ID', record.MDId),
              _viewRow('Shift', record.shift.label),
              _viewRow('Bank Account', record.bankAccount),
              _viewRow('Monthly Salary', '₹${record.monthlySalary.toStringAsFixed(0)}'),
              _viewRow('PF Enabled', record.pfEnabled ? 'Yes (12%)' : 'No'),
              _viewRow('ESI Enabled', record.esiEnabled ? 'Yes (0.75%)' : 'No'),
              _viewRow('Insurance', '₹${record.insurance.toStringAsFixed(0)}'),
              _viewRow('Welfare', '₹${record.welfare.toStringAsFixed(0)}'),
              _viewRow('TDS', '₹${record.tds.toStringAsFixed(0)}'),
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

  void _confirmDelete(MDRecord record) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete record?'),
        content: Text(
            'Remove ${record.name} (${record.MDId})? This does not delete past salary history.'),
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

  void _openForm({MDRecord? existing}) {
    showDialog(
      context: context,
      builder: (ctx) => _MDRecordFormDialog(
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

class _MDRecordFormDialog extends StatefulWidget {
  final MDRecord? existing;
  final ValueChanged<MDRecord> onSave;
  final CollectionReference<Map<String, dynamic>> collection;

  const _MDRecordFormDialog({
    this.existing,
    required this.onSave,
    required this.collection,
  });

  @override
  State<_MDRecordFormDialog> createState() => _MDRecordFormDialogState();
}

class _MDRecordFormDialogState extends State<_MDRecordFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _MDIdCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _bankCtrl;
  late final TextEditingController _salaryCtrl;
  late final TextEditingController _insuranceCtrl;
  late final TextEditingController _welfareCtrl;
  late final TextEditingController _tdsCtrl;
  late Shift _shift;
  late bool _pfEnabled;
  late bool _esiEnabled;
  bool _isSaving = false;
  String? _mdIdError; // shown under the MD ID field when it's a duplicate

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _MDIdCtrl = TextEditingController(text: e?.MDId ?? '');
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _bankCtrl = TextEditingController(text: e?.bankAccount ?? '');
    _salaryCtrl = TextEditingController(text: e?.monthlySalary.toString() ?? '');
    _insuranceCtrl = TextEditingController(text: e?.insurance.toString() ?? '0');
    _welfareCtrl = TextEditingController(text: e?.welfare.toString() ?? '0');
    _tdsCtrl = TextEditingController(text: e?.tds.toString() ?? '0');
    _shift = e?.shift ?? Shift.morning;
    _pfEnabled = e?.pfEnabled ?? true;
    _esiEnabled = e?.esiEnabled ?? true;
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
                _field(_MDIdCtrl, 'MD ID', hint: 'e.g. MD001', errorText: _mdIdError),
                _field(_nameCtrl, 'Name'),
                _shiftDropdown(),
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
                _field(_tdsCtrl, 'TDS', keyboardType: TextInputType.number, isCurrency: true),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('PF Enabled (12%)'),
                  value: _pfEnabled,
                  activeThumbColor: _C.mdAccent,
                  onChanged: (v) => setState(() => _pfEnabled = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('ESI Enabled (0.75%)'),
                  value: _esiEnabled,
                  activeThumbColor: _C.mdAccent,
                  onChanged: (v) => setState(() => _esiEnabled = v),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                        onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _C.navyDark, foregroundColor: Colors.white, elevation: 0),
                      child: _isSaving
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                          : const Text('Save'),
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

  Widget _shiftDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<Shift>(
        initialValue: _shift,
        decoration: const InputDecoration(
            labelText: 'Shift', border: OutlineInputBorder(), isDense: true),
        items: Shift.values.map((s) => DropdownMenuItem(value: s, child: Text(s.label))).toList(),
        onChanged: (v) => setState(() => _shift = v ?? _shift),
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
          errorText: errorText, // shows "MD ID already exists" under the field
        ),
        onChanged: (_) {
          // Clear the duplicate error as soon as the user edits the ID again.
          if (errorText != null) setState(() => _mdIdError = null);
        },
        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final enteredId = _MDIdCtrl.text.trim();
    setState(() {
      _isSaving = true;
      _mdIdError = null;
    });

    // Check Firestore for another record with the same MD ID.
    // On edit, the record's own doc is excluded so re-saving the same
    // record with its own ID doesn't falsely flag as a duplicate.
    final existingDocs = await widget.collection
        .where('MDId', isEqualTo: enteredId)
        .get();
    final isDuplicate = existingDocs.docs.any(
            (doc) => doc.id != widget.existing?.docId);

    if (isDuplicate) {
      setState(() {
        _isSaving = false;
        _mdIdError = 'MD ID "$enteredId" already exists — use a different one.';
      });
      return;
    }

    widget.onSave(MDRecord(
      docId: widget.existing?.docId,
      MDId: enteredId,
      name: _nameCtrl.text.trim(),
      shift: _shift,
      monthlySalary: double.tryParse(_salaryCtrl.text) ?? 0,
      insurance: double.tryParse(_insuranceCtrl.text) ?? 0,
      welfare: double.tryParse(_welfareCtrl.text) ?? 0,
      bankAccount: _bankCtrl.text.trim(),
      pfEnabled: _pfEnabled,
      esiEnabled: _esiEnabled,
      tds: double.tryParse(_tdsCtrl.text) ?? 0,
    ));
    if (mounted) Navigator.pop(context);
  }
}