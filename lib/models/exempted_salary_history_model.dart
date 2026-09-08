// lib/models/exempted_salary_history_model.dart
//
// Data model for a single saved row in `exempted_salary_history`.
// Mirrors MDSalaryHistoryModel — but Exempted has no PF/ESI/TDS since
// those statutory deductions don't apply to this role. Only Insurance
// and Welfare (both flat amounts) are deducted from gross wages.

import 'package:cloud_firestore/cloud_firestore.dart';

const List<String> kExemptedHistoryMonthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];

class ExemptedSalaryHistoryModel {
  final String id;
  final String empId;
  final String name;
  final String bankAccount;
  final int month; // 1-12
  final int year;
  final int workingDays;
  final double presentDays;
  final double grossWages;
  final double insurance;
  final double welfare;
  final double totalDeductions;
  final double netSalary;
  final DateTime? generatedAt;

  ExemptedSalaryHistoryModel({
    required this.id,
    required this.empId,
    required this.name,
    required this.bankAccount,
    required this.month,
    required this.year,
    required this.workingDays,
    required this.presentDays,
    required this.grossWages,
    required this.insurance,
    required this.welfare,
    required this.totalDeductions,
    required this.netSalary,
    this.generatedAt,
  });

  /// e.g. "August 2026" — used for grouping, sorting and filtering.
  String get monthLabel => '${kExemptedHistoryMonthNames[month - 1]} $year';

  factory ExemptedSalaryHistoryModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    double toD(dynamic v) => (v is num) ? v.toDouble() : 0.0;
    int toI(dynamic v) => (v is num) ? v.toInt() : 0;

    return ExemptedSalaryHistoryModel(
      id: doc.id,
      empId: data['empId'] ?? '',
      name: data['name'] ?? '',
      bankAccount: data['bankAccount'] ?? '',
      month: toI(data['month']),
      year: toI(data['year']),
      workingDays: toI(data['workingDays']),
      presentDays: toD(data['presentDays']),
      grossWages: toD(data['grossWages']),
      insurance: toD(data['insurance']),
      welfare: toD(data['welfare']),
      totalDeductions: toD(data['totalDeductions']),
      netSalary: toD(data['netSalary']),
      generatedAt: (data['generatedAt'] is Timestamp)
          ? (data['generatedAt'] as Timestamp).toDate()
          : null,
    );
  }
}