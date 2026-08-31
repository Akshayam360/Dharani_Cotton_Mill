// lib/models/md_salary_history_model.dart
//
// Data model for a single saved row in `md_salary_history`.
// Mirrors the shape of Labour's LabourSalaryHistoryModel so the History
// screen can follow the same patterns (grouping, filtering, PDF export).

import 'package:cloud_firestore/cloud_firestore.dart';

const List<String> kMDHistoryMonthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];

class MDSalaryHistoryModel {
  final String id;
  final String MDId;
  final String name;
  final String bankAccount;
  final int month; // 1-12
  final int year;
  final int workingDays;
  final double presentDays;
  final double basicDa;
  final double hra;
  final double grossWages;
  final double pfAmount;
  final double esiAmount;
  final double insurance;
  final double welfare;
  final double tds;
  final double totalDeductions;
  final double netSalary;
  final DateTime? generatedAt;

  MDSalaryHistoryModel({
    required this.id,
    required this.MDId,
    required this.name,
    required this.bankAccount,
    required this.month,
    required this.year,
    required this.workingDays,
    required this.presentDays,
    required this.basicDa,
    required this.hra,
    required this.grossWages,
    required this.pfAmount,
    required this.esiAmount,
    required this.insurance,
    required this.welfare,
    required this.tds,
    required this.totalDeductions,
    required this.netSalary,
    this.generatedAt,
  });

  /// e.g. "August 2026" — used for grouping, sorting and filtering,
  /// the same way Labour's `monthLabel` getter is used.
  String get monthLabel => '${kMDHistoryMonthNames[month - 1]} $year';

  factory MDSalaryHistoryModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    double toD(dynamic v) => (v is num) ? v.toDouble() : 0.0;
    int toI(dynamic v) => (v is num) ? v.toInt() : 0;

    return MDSalaryHistoryModel(
      id: doc.id,
      MDId: data['MDId'] ?? '',
      name: data['name'] ?? '',
      bankAccount: data['bankAccount'] ?? '',
      month: toI(data['month']),
      year: toI(data['year']),
      workingDays: toI(data['workingDays']),
      presentDays: toD(data['presentDays']),
      basicDa: toD(data['basicDa']),
      hra: toD(data['hra']),
      grossWages: toD(data['grossWages']),
      pfAmount: toD(data['pfAmount']),
      esiAmount: toD(data['esiAmount']),
      insurance: toD(data['insurance']),
      welfare: toD(data['welfare']),
      tds: toD(data['tds']),
      totalDeductions: toD(data['totalDeductions']),
      netSalary: toD(data['netSalary']),
      generatedAt: (data['generatedAt'] is Timestamp)
          ? (data['generatedAt'] as Timestamp).toDate()
          : null,
    );
  }
}