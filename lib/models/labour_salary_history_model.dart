// lib/models/labour_salary_history_model.dart
//
// Data model for a single saved row in `labour_salary_history`.
// Mirrors the shape of Staff's SalaryHistoryModel so the History screen
// can follow the same patterns (grouping, filtering, PDF export).

import 'package:cloud_firestore/cloud_firestore.dart';

const List<String> kLabourHistoryMonthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];

class LabourSalaryHistoryModel {
  final String id;
  final String labourId;
  final String name;
  final String bankAccount;
  final int month; // 1-12
  final int year;
  final int workingDays;
  final double daysWorked;
  final double otHours;
  final double baseSalary;
  final double otAmount;
  final double productionAllowance;
  final double grossWages;
  final double pfAmount;
  final double esiAmount;
  final double insurance;
  final double welfare;
  final double totalDeductions;
  final double netSalary;
  final DateTime? generatedAt;

  LabourSalaryHistoryModel({
    required this.id,
    required this.labourId,
    required this.name,
    required this.bankAccount,
    required this.month,
    required this.year,
    required this.workingDays,
    required this.daysWorked,
    required this.otHours,
    required this.baseSalary,
    required this.otAmount,
    required this.productionAllowance,
    required this.grossWages,
    required this.pfAmount,
    required this.esiAmount,
    required this.insurance,
    required this.welfare,
    required this.totalDeductions,
    required this.netSalary,
    this.generatedAt,
  });

  /// e.g. "August 2026" — used for grouping, sorting and filtering,
  /// the same way Staff's `month` string field is used.
  String get monthLabel => '${kLabourHistoryMonthNames[month - 1]} $year';

  factory LabourSalaryHistoryModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    double toD(dynamic v) => (v is num) ? v.toDouble() : 0.0;
    int toI(dynamic v) => (v is num) ? v.toInt() : 0;

    return LabourSalaryHistoryModel(
      id: doc.id,
      labourId: data['labourId'] ?? '',
      name: data['name'] ?? '',
      bankAccount: data['bankAccount'] ?? '',
      month: toI(data['month']),
      year: toI(data['year']),
      workingDays: toI(data['workingDays']),
      daysWorked: toD(data['daysWorked']),
      otHours: toD(data['otHours']),
      baseSalary: toD(data['baseSalary']),
      otAmount: toD(data['otAmount']),
      productionAllowance: toD(data['productionAllowance']),
      grossWages: toD(data['grossWages']),
      pfAmount: toD(data['pfAmount']),
      esiAmount: toD(data['esiAmount']),
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