import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class StaffColors {
  static const Color primary = Color(0xFF6D4C41); // brown (Staff role)
  static const Color primaryLight = Color(0xFF8D6E63);
  static const Color primaryDark = Color(0xFF3E2723);
  static const Color background = Color(0xFFF5F6F7);
  static const Color cardBorder = Color(0xFFE3E6E8);
}

// ---------------------------------------------------------------------------
// MODEL
// ---------------------------------------------------------------------------
class StaffModel {
  final String staffId;
  final String name;
  final double monthlySalary;
  final double lic;
  final double welfare;
  final String bankAccount;
  final bool pfEnabled;
  final bool esiEnabled;

  StaffModel({
    required this.staffId,
    required this.name,
    required this.monthlySalary,
    required this.lic,
    required this.welfare,
    required this.bankAccount,
    required this.pfEnabled,
    required this.esiEnabled,
  });

  factory StaffModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return StaffModel(
      staffId: doc.id,
      name: data['name'] ?? '',
      monthlySalary: (data['monthlySalary'] ?? 0).toDouble(),
      lic: (data['lic'] ?? 0).toDouble(),
      welfare: (data['welfare'] ?? 0).toDouble(),
      bankAccount: data['bankAccount'] ?? '',
      pfEnabled: data['pfEnabled'] ?? false,
      esiEnabled: data['esiEnabled'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'monthlySalary': monthlySalary,
      'lic': lic,
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
class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  final _searchController = TextEditingController();
  final _tableHScrollController = ScrollController();
  String _searchQuery = '';

  final CollectionReference<Map<String, dynamic>> _staffRef =
  FirebaseFirestore.instance.collection('staff');

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

  void _openAddEditDialog({StaffModel? existing}) {
    final isEdit = existing != null;
    showDialog(
      context: context,
      builder: (_) => AddEditStaffDialog(
        existing: existing,
        onSave: (model) async {
          final idChanged = isEdit && existing.staffId != model.staffId;

          if (!isEdit || idChanged) {
            // Duplicate Staff ID check — new record, or an edit that
            // renamed the ID to something else already in use.
            final docSnap = await _staffRef.doc(model.staffId).get();
            if (docSnap.exists) {
              throw Exception('Staff ID "${model.staffId}" already exists');
            }
          }

          if (idChanged) {
            // Renaming the ID means the doc lives at a new path —
            // write the new doc, then remove the old one so it
            // doesn't linger as an orphaned record.
            await _staffRef.doc(model.staffId).set(model.toMap());
            await _staffRef.doc(existing.staffId).delete();
          } else {
            await _staffRef.doc(model.staffId).set(model.toMap());
          }
        },
      ),
    ).then((result) {
      // result == true means the dialog saved successfully before closing.
      if (result == true) {
        _showSnack(
            isEdit ? 'Staff updated successfully' : 'Staff added successfully');
      }
    });
  }

  void _confirmDelete(StaffModel staff) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Staff'),
        content: Text(
          'Are you sure you want to remove ${staff.name} (${staff.staffId})? '
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
              await _staffRef.doc(staff.staffId).delete();
              if (context.mounted) {
                Navigator.pop(context);
                _showSnack('Staff deleted successfully');
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _viewDetails(StaffModel staff) {
    showDialog(
      context: context,
      builder: (_) => StaffDetailsDialog(staff: staff),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: StaffColors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;

          // Scale padding & decide if header should wrap to a new line
          // across common desktop breakpoints (compact laptop -> wide monitor).
          final horizontalPadding =
          width < 900 ? 20.0 : (width < 1400 ? 32.0 : 48.0);
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
                  onChanged: (v) =>
                      setState(() => _searchQuery = v.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search by name or ID...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: StaffColors.cardBorder),
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
                      border: Border.all(color: StaffColors.cardBorder),
                    ),
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _staffRef.orderBy(FieldPath.documentId).snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40),
                              child: Text('No staff records yet. Tap "Add Staff" to begin.'),
                            ),
                          );
                        }

                        final allStaff =
                        snapshot.data!.docs.map(StaffModel.fromDoc).toList();
                        final filtered = _searchQuery.isEmpty
                            ? allStaff
                            : allStaff.where((s) {
                          return s.name.toLowerCase().contains(_searchQuery) ||
                              s.staffId.toLowerCase().contains(_searchQuery);
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
                                    StaffColors.background),
                                columns: const [
                                  DataColumn(label: Text('STAFF ID')),
                                  DataColumn(label: Text('NAME')),
                                  DataColumn(label: Text('MONTHLY SALARY')),
                                  DataColumn(label: Text('LIC')),
                                  DataColumn(label: Text('WELFARE')),
                                  DataColumn(label: Text('PF')),
                                  DataColumn(label: Text('ESI')),
                                  DataColumn(label: Text('BANK ACCOUNT')),
                                  DataColumn(label: Text('ACTIONS')),
                                ],
                                rows: filtered.map((s) {
                                  return DataRow(cells: [
                                    DataCell(Text(s.staffId)),
                                    DataCell(Text(s.name)),
                                    DataCell(Text('₹${s.monthlySalary.toStringAsFixed(0)}')),
                                    DataCell(Text(s.lic > 0
                                        ? '₹${s.lic.toStringAsFixed(0)}'
                                        : '--')),
                                    DataCell(Text('₹${s.welfare.toStringAsFixed(0)}')),
                                    DataCell(Text(s.pfEnabled ? 'Yes' : '--')),
                                    DataCell(Text(s.esiEnabled ? 'Yes' : '--')),
                                    DataCell(Text(s.bankAccount)),
                                    DataCell(Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.visibility_outlined, size: 20),
                                          onPressed: () => _viewDetails(s),
                                          tooltip: 'View',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 20),
                                          onPressed: () => _openAddEditDialog(existing: s),
                                          tooltip: 'Edit',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline,
                                              size: 20, color: Colors.redAccent),
                                          onPressed: () => _confirmDelete(s),
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
          'Staff Management',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: StaffColors.primaryDark,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Add, edit and review every staff payroll-impacting record.',
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _addButton() {
    return ElevatedButton.icon(
      onPressed: () => _openAddEditDialog(),
      style: ElevatedButton.styleFrom(
        backgroundColor: StaffColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: const Icon(Icons.add),
      label: const Text('Add Staff'),
    );
  }
}

// ---------------------------------------------------------------------------
// ADD / EDIT DIALOG
// ---------------------------------------------------------------------------
class AddEditStaffDialog extends StatefulWidget {
  final StaffModel? existing;
  final Future<void> Function(StaffModel) onSave;

  const AddEditStaffDialog({super.key, this.existing, required this.onSave});

  @override
  State<AddEditStaffDialog> createState() => _AddEditStaffDialogState();
}

class _AddEditStaffDialogState extends State<AddEditStaffDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _idCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _bankCtrl;
  late final TextEditingController _salaryCtrl;
  late final TextEditingController _licCtrl;
  late final TextEditingController _welfareCtrl;

  bool _pfEnabled = false;
  bool _esiEnabled = false;
  bool _saving = false;
  String? _errorText;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _idCtrl = TextEditingController(text: e?.staffId ?? '');
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _bankCtrl = TextEditingController(text: e?.bankAccount ?? '');
    _salaryCtrl = TextEditingController(
        text: e != null ? e.monthlySalary.toStringAsFixed(0) : '');
    // LIC is optional — left blank when there's none, rather than defaulting to 0.
    _licCtrl = TextEditingController(
        text: e != null && e.lic > 0 ? e.lic.toStringAsFixed(0) : '');
    _welfareCtrl =
        TextEditingController(text: e != null ? e.welfare.toStringAsFixed(0) : '0');
    _pfEnabled = e?.pfEnabled ?? false;
    _esiEnabled = e?.esiEnabled ?? false;
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _nameCtrl.dispose();
    _bankCtrl.dispose();
    _salaryCtrl.dispose();
    _licCtrl.dispose();
    _welfareCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _errorText = null;
    });

    final model = StaffModel(
      staffId: _idCtrl.text.trim(),
      name: _nameCtrl.text.trim(),
      monthlySalary: double.tryParse(_salaryCtrl.text.trim()) ?? 0,
      lic: double.tryParse(_licCtrl.text.trim()) ?? 0,
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
                        _isEdit ? 'Edit Staff' : 'Add Staff',
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
                          decoration: const InputDecoration(labelText: 'Staff ID'),
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
                  if (_isEdit) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Changing the Staff ID moves this record to a new ID — '
                          'past salary history stays linked to the old ID.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _salaryCtrl,
                          keyboardType: TextInputType.number,
                          decoration:
                          const InputDecoration(labelText: 'Monthly Salary (₹)'),
                          validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                          controller: _licCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'LIC (₹, leave blank if none)'),
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
                            activeThumbColor: StaffColors.primary,
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
                            activeThumbColor: StaffColors.primary,
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
                          backgroundColor: StaffColors.primary,
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
                            : Text(_isEdit ? 'Update Staff' : 'Add Staff'),
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
class StaffDetailsDialog extends StatelessWidget {
  final StaffModel staff;
  const StaffDetailsDialog({super.key, required this.staff});

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
                  const Text('Staff Details',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              _row('Staff ID', staff.staffId),
              _row('Name', staff.name),
              _row('Bank Account', staff.bankAccount),
              _row('Monthly Salary', '₹${staff.monthlySalary.toStringAsFixed(0)}'),
              _row('LIC', staff.lic > 0 ? '₹${staff.lic.toStringAsFixed(0)}' : '--'),
              _row('Welfare', '₹${staff.welfare.toStringAsFixed(0)}'),
              _row('PF', staff.pfEnabled ? '12%' : '--'),
              _row('ESI', staff.esiEnabled ? '0.75%' : '--'),
            ],
          ),
        ),
      ),
    );
  }
}