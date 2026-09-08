// lib/models/staff_salary_history_model.dart
//
// Data model for a single saved row in `staff_salary_history`.
// Mirrors the shape of Labour's LabourSalaryHistoryModel so the History
// screen can follow the same patterns (grouping, filtering, PDF export).

import 'package:cloud_firestore/cloud_firestore.dart';

const List<String> kStaffHistoryMonthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];

class StaffSalaryHistoryModel {
  final String id;
  final String staffId;
  final String name;
  final String bankAccount;
  final int month; // 1-12
  final int year;
  final int workingDays;
  final double daysWorked;
  final double monthlySalary;
  final double effectiveSalary;
  final double baseSalary;
  final double hra;
  final double pfAmount;
  final double esiAmount;
  final double lic;
  final double mess;
  final double welfare;
  final double totalDeductions;
  final double netSalary;
  final DateTime? generatedAt;

  StaffSalaryHistoryModel({
    required this.id,
    required this.staffId,
    required this.name,
    required this.bankAccount,
    required this.month,
    required this.year,
    required this.workingDays,
    required this.daysWorked,
    required this.monthlySalary,
    required this.effectiveSalary,
    required this.baseSalary,
    required this.hra,
    required this.pfAmount,
    required this.esiAmount,
    required this.lic,
    required this.mess,
    required this.welfare,
    required this.totalDeductions,
    required this.netSalary,
    this.generatedAt,
  });

  /// e.g. "August 2026" — used for grouping, sorting and filtering,
  /// the same way Labour's `monthLabel` getter is used.
  String get monthLabel => '${kStaffHistoryMonthNames[month - 1]} $year';

  factory StaffSalaryHistoryModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    double toD(dynamic v) => (v is num) ? v.toDouble() : 0.0;
    int toI(dynamic v) => (v is num) ? v.toInt() : 0;

    return StaffSalaryHistoryModel(
      id: doc.id,
      staffId: data['staffId'] ?? '',
      name: data['name'] ?? '',
      bankAccount: data['bankAccount'] ?? '',
      month: toI(data['month']),
      year: toI(data['year']),
      workingDays: toI(data['workingDays']),
      daysWorked: toD(data['daysWorked']),
      monthlySalary: toD(data['monthlySalary']),
      effectiveSalary: toD(data['effectiveSalary']),
      baseSalary: toD(data['baseSalary']),
      hra: toD(data['hra']),
      pfAmount: toD(data['pfAmount']),
      esiAmount: toD(data['esiAmount']),
      lic: toD(data['lic']),
      mess: toD(data['mess']),
      welfare: toD(data['welfare']),
      totalDeductions: toD(data['totalDeductions']),
      netSalary: toD(data['netSalary']),
      generatedAt: (data['generatedAt'] is Timestamp)
          ? (data['generatedAt'] as Timestamp).toDate()
          : null,
    );
  }
}