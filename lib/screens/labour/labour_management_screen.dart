

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class LabourColors {
  static const Color primary = Color(0xFF37474F);
  static const Color primaryLight = Color(0xFF62727B);
  static const Color primaryDark = Color(0xFF102027);
  static const Color background = Color(0xFFF5F6F7);
  static const Color cardBorder = Color(0xFFE3E6E8);
}

// ---------------------------------------------------------------------------
// MODEL
// ---------------------------------------------------------------------------
enum Shift { morning, evening, night }

extension ShiftX on Shift {
  String get label {
    switch (this) {
      case Shift.morning:
        return 'Morning';
      case Shift.evening:
        return 'Evening';
      case Shift.night:
        return 'Night';
    }
  }

  Color get color {
    switch (this) {
      case Shift.morning:
        return const Color(0xFFEF6C00); // amber-orange
      case Shift.evening:
        return const Color(0xFF6A1B9A); // purple
      case Shift.night:
        return const Color(0xFF1565C0); // blue
    }
  }

  static Shift fromString(String value) {
    return Shift.values.firstWhere(
          (s) => s.name == value,
      orElse: () => Shift.morning,
    );
  }
}

class LabourModel {
  final String labourId;
  final String name;
  final Shift shift;
  final double perDaySalary;
  final double productionAllowance;
  final double insurance;
  final double welfare;
  final String bankAccount;
  final bool pfEnabled;
  final bool esiEnabled;

  LabourModel({
    required this.labourId,
    required this.name,
    required this.shift,
    required this.perDaySalary,
    required this.productionAllowance,
    required this.insurance,
    required this.welfare,
    required this.bankAccount,
    required this.pfEnabled,
    required this.esiEnabled,
  });

  factory LabourModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return LabourModel(
      labourId: doc.id,
      name: data['name'] ?? '',
      shift: ShiftX.fromString(data['shift'] ?? 'morning'),
      perDaySalary: (data['perDaySalary'] ?? 0).toDouble(),
      productionAllowance: (data['productionAllowance'] ?? 0).toDouble(),
      insurance: (data['insurance'] ?? 0).toDouble(),
      welfare: (data['welfare'] ?? 0).toDouble(),
      bankAccount: data['bankAccount'] ?? '',
      pfEnabled: data['pfEnabled'] ?? false,
      esiEnabled: data['esiEnabled'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'shift': shift.name,
      'perDaySalary': perDaySalary,
      'productionAllowance': productionAllowance,
      'insurance': insurance,
      'welfare': welfare,
      'bankAccount': bankAccount,
      'pfEnabled': pfEnabled,
      'esiEnabled': esiEnabled,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

// ---------------------------------------------------------------------------
// MAIN SCREEN
// ---------------------------------------------------------------------------
class LabourManagementScreen extends StatefulWidget {
  const LabourManagementScreen({super.key});

  @override
  State<LabourManagementScreen> createState() =>
      _LabourManagementScreenState();
}

class _LabourManagementScreenState extends State<LabourManagementScreen> {
  final _searchController = TextEditingController();
  final _tableHScrollController = ScrollController();
  String _searchQuery = '';

  final CollectionReference<Map<String, dynamic>> _labourRef =
  FirebaseFirestore.instance.collection('labours');

  @override
  void dispose() {
    _searchController.dispose();
    _tableHScrollController.dispose();
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

  void _openAddEditDialog({LabourModel? existing}) {
    final isEdit = existing != null;
    showDialog(
      context: context,
      builder: (_) => AddEditLabourDialog(
        existing: existing,
        onSave: (model) async {
          if (!isEdit) {
            // Duplicate Labour ID check — only relevant when adding new.
            final docSnap = await _labourRef.doc(model.labourId).get();
            if (docSnap.exists) {
              throw Exception('Labour ID "${model.labourId}" already exists');
            }
          }
          await _labourRef.doc(model.labourId).set(model.toMap());
        },
      ),
    ).then((result) {
      // result == true means the dialog saved successfully before closing.
      if (result == true) {
        _showSnack(isEdit
            ? 'Labour updated successfully'
            : 'Labour added successfully');
      }
    });
  }

  void _confirmDelete(LabourModel labour) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Labour'),
        content: Text(
          'Are you sure you want to remove ${labour.name} (${labour.labourId})? '
              'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await _labourRef.doc(labour.labourId).delete();
              if (context.mounted) {
                Navigator.pop(context);
                _showSnack('Labour deleted successfully');
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _viewDetails(LabourModel labour) {
    showDialog(
      context: context,
      builder: (_) => LabourDetailsDialog(labour: labour),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: LabourColors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          // Scale padding & decide if header should wrap to a new line
          // across common desktop breakpoints (compact laptop -> wide monitor).
          final horizontalPadding = width < 900 ? 20.0 : (width < 1400 ? 32.0 : 48.0);
          final isNarrow = width < 760;

          return Padding(
            padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding, vertical: horizontalPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row — wraps to a column on narrow desktop widths
                isNarrow
                    ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _headerText(),
                    const SizedBox(height: 16),
                    _addButton(),
                  ],
                )
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(child: _headerText()),
                    _addButton(),
                  ],
                ),
                const SizedBox(height: 24),

                // Search bar
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search by name or ID...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: LabourColors.cardBorder),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Table
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: LabourColors.cardBorder),
                    ),
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _labourRef.orderBy(FieldPath.documentId).snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40),
                              child: Text('No labour records yet. Tap "Add Labour" to begin.'),
                            ),
                          );
                        }

                        final allLabour =
                        snapshot.data!.docs.map(LabourModel.fromDoc).toList();
                        final filtered = _searchQuery.isEmpty
                            ? allLabour
                            : allLabour.where((l) {
                          return l.name.toLowerCase().contains(_searchQuery) ||
                              l.labourId.toLowerCase().contains(_searchQuery);
                        }).toList();

                        if (filtered.isEmpty) {
                          return const Center(child: Text('No matching records.'));
                        }

                        return Scrollbar(
                          controller: _tableHScrollController,
                          thumbVisibility: true,
                          trackVisibility: true,
                          child: SingleChildScrollView(
                            controller: _tableHScrollController,
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              // Ensures the table stretches to fill wide desktop
                              // screens instead of hugging the left edge, while
                              // still scrolling horizontally on narrower ones
                              // or when content (e.g. a long name) is wider.
                              constraints:
                              BoxConstraints(minWidth: constraints.maxWidth),
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(
                                    LabourColors.background),
                                columns: const [
                                  DataColumn(label: Text('LABOUR ID')),
                                  DataColumn(label: Text('NAME')),
                                  DataColumn(label: Text('SHIFT')),
                                  DataColumn(label: Text('PER DAY SALARY')),
                                  DataColumn(label: Text('PROD. ALLOWANCE')),
                                  DataColumn(label: Text('PF')),
                                  DataColumn(label: Text('ESI')),
                                  DataColumn(label: Text('BANK ACCOUNT')),
                                  DataColumn(label: Text('ACTIONS')),
                                ],
                                rows: filtered.map((l) {
                                  return DataRow(cells: [
                                    DataCell(Text(l.labourId)),
                                    DataCell(Text(l.name)),
                                    DataCell(ShiftBadge(shift: l.shift)),
                                    DataCell(Text('₹${l.perDaySalary.toStringAsFixed(0)}')),
                                    DataCell(Text('₹${l.productionAllowance.toStringAsFixed(0)}')),
                                    DataCell(Text(l.pfEnabled ? 'Yes' : '--')),
                                    DataCell(Text(l.esiEnabled ? 'Yes' : '--')),
                                    DataCell(Text(l.bankAccount)),
                                    DataCell(Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.visibility_outlined, size: 20),
                                          onPressed: () => _viewDetails(l),
                                          tooltip: 'View',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 20),
                                          onPressed: () => _openAddEditDialog(existing: l),
                                          tooltip: 'Edit',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline,
                                              size: 20, color: Colors.redAccent),
                                          onPressed: () => _confirmDelete(l),
                                          tooltip: 'Delete',
                                        ),
                                      ],
                                    )),
                                  ]);
                                }).toList(),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _headerText() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Labour Management',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: LabourColors.primaryDark,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Add, edit and review every labour payroll-impacting record.',
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _addButton() {
    return ElevatedButton.icon(
      onPressed: () => _openAddEditDialog(),
      style: ElevatedButton.styleFrom(
        backgroundColor: LabourColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: const Icon(Icons.add),
      label: const Text('Add Labour'),
    );
  }
}

// ---------------------------------------------------------------------------
// SHIFT BADGE — small colored pill
// ---------------------------------------------------------------------------
class ShiftBadge extends StatelessWidget {final Shift shift;
const ShiftBadge({super.key, required this.shift});

@override
Widget build(BuildContext context) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: shift.color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: shift.color.withValues(alpha: 0.4)),
    ),
    child: Text(
      shift.label,
      style: TextStyle(
        color: shift.color,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    ),
  );
}
}

// ---------------------------------------------------------------------------
// ADD / EDIT DIALOG
// ---------------------------------------------------------------------------
class AddEditLabourDialog extends StatefulWidget {
  final LabourModel? existing;
  final Future<void> Function(LabourModel) onSave;

  const AddEditLabourDialog({super.key, this.existing, required this.onSave});

  @override
  State<AddEditLabourDialog> createState() => _AddEditLabourDialogState();
}

class _AddEditLabourDialogState extends State<AddEditLabourDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _idCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _bankCtrl;
  late final TextEditingController _perDayCtrl;
  late final TextEditingController _allowanceCtrl;
  late final TextEditingController _insuranceCtrl;
  late final TextEditingController _welfareCtrl;

  Shift _shift = Shift.morning;
  bool _pfEnabled = false;
  bool _esiEnabled = false;
  bool _saving = false;
  String? _errorText;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _idCtrl = TextEditingController(text: e?.labourId ?? '');
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _bankCtrl = TextEditingController(text: e?.bankAccount ?? '');
    _perDayCtrl =
        TextEditingController(text: e != null ? e.perDaySalary.toStringAsFixed(0) : '');
    _allowanceCtrl = TextEditingController(
        text: e != null ? e.productionAllowance.toStringAsFixed(0) : '0');
    _insuranceCtrl =
        TextEditingController(text: e != null ? e.insurance.toStringAsFixed(0) : '50');
    _welfareCtrl =
        TextEditingController(text: e != null ? e.welfare.toStringAsFixed(0) : '50');
    _shift = e?.shift ?? Shift.morning;
    _pfEnabled = e?.pfEnabled ?? false;
    _esiEnabled = e?.esiEnabled ?? false;
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _nameCtrl.dispose();
    _bankCtrl.dispose();
    _perDayCtrl.dispose();
    _allowanceCtrl.dispose();
    _insuranceCtrl.dispose();
    _welfareCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _errorText = null;
    });

    final model = LabourModel(
      labourId: _idCtrl.text.trim(),
      name: _nameCtrl.text.trim(),
      shift: _shift,
      perDaySalary: double.tryParse(_perDayCtrl.text.trim()) ?? 0,
      productionAllowance: double.tryParse(_allowanceCtrl.text.trim()) ?? 0,
      insurance: double.tryParse(_insuranceCtrl.text.trim()) ?? 0,
      welfare: double.tryParse(_welfareCtrl.text.trim()) ?? 0,
      bankAccount: _bankCtrl.text.trim(),
      pfEnabled: _pfEnabled,
      esiEnabled: _esiEnabled,
    );

    try {
      await widget.onSave(model);
      if (mounted) {
        // Pop with `true` so the parent screen knows to show the
        // success snackbar (Add/Update) only after a real save.
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorText = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isEdit ? 'Edit Labour' : 'Add Labour',
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _idCtrl,
                          enabled: !_isEdit,
                          decoration: const InputDecoration(labelText: 'Labour ID'),
                          validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(labelText: 'Name'),
                          validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<Shift>(
                          initialValue: _shift,
                          decoration: const InputDecoration(labelText: 'Shift'),
                          items: Shift.values
                              .map((s) => DropdownMenuItem(
                              value: s, child: Text(s.label)))
                              .toList(),
                          onChanged: (v) => setState(() => _shift = v!),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: TextFormField(
                          controller: _bankCtrl,
                          decoration:
                          const InputDecoration(labelText: 'Bank Account Number'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _perDayCtrl,
                          keyboardType: TextInputType.number,
                          decoration:
                          const InputDecoration(labelText: 'Per Day Salary (₹)'),
                          validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: TextFormField(
                          controller: _allowanceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Production Allowance (₹)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _insuranceCtrl,
                          keyboardType: TextInputType.number,
                          decoration:
                          const InputDecoration(labelText: 'Insurance (flat ₹)'),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: TextFormField(
                          controller: _welfareCtrl,
                          keyboardType: TextInputType.number,
                          decoration:
                          const InputDecoration(labelText: 'Welfare (flat ₹)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Row(
                        children: [
                          const Text('PF (12%)'),
                          Switch(
                            value: _pfEnabled,
                            activeThumbColor: LabourColors.primary,
                            onChanged: (v) => setState(() => _pfEnabled = v),
                          ),
                        ],
                      ),
                      const SizedBox(width: 40),
                      Row(
                        children: [
                          const Text('ESI (0.75%)'),
                          Switch(
                            value: _esiEnabled,
                            activeThumbColor: LabourColors.primary,
                            onChanged: (v) => setState(() => _esiEnabled = v),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline,
                              color: Colors.red.shade700, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorText!,
                              style: TextStyle(
                                  color: Colors.red.shade700, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: LabourColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 14),
                        ),
                        onPressed: _saving ? null : _submit,
                        child: _saving
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                            : Text(_isEdit ? 'Update Labour' : 'Add Labour'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// VIEW DETAILS DIALOG
// ---------------------------------------------------------------------------
class LabourDetailsDialog extends StatelessWidget {
  final LabourModel labour;
  const LabourDetailsDialog({super.key, required this.labour});

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
              width: 160,
              child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Labour Details',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              _row('Labour ID', labour.labourId),
              _row('Name', labour.name),
              _row('Shift', labour.shift.label),
              _row('Bank Account', labour.bankAccount),
              _row('Per Day Salary', '₹${labour.perDaySalary.toStringAsFixed(0)}'),
              _row('Production Allowance',
                  '₹${labour.productionAllowance.toStringAsFixed(0)}'),
              _row('Insurance', '₹${labour.insurance.toStringAsFixed(0)}'),
              _row('Welfare', '₹${labour.welfare.toStringAsFixed(0)}'),
              _row('PF', labour.pfEnabled ? '12%' : '--'),
              _row('ESI', labour.esiEnabled ? '0.75%' : '--'),
            ],
          ),
        ),
      ),
    );
  }
}