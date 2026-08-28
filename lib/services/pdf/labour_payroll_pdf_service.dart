// lib/services/pdf/labour_payroll_pdf_service.dart
//
// Generates a one-page-per-month Labour salary register PDF, styled to
// match the app's blue-grey Labour theme.
//
// Built as a manual pw.Table (rather than TableHelper.fromTextArray) so
// the final TOTAL row can be bold + shaded independently of the regular
// data rows — fromTextArray only supports one uniform style for every
// row, which isn't enough to make just the last row stand out.
//
// Requires the `pdf` package — if not in pubspec.yaml yet, add:
//   pdf: ^3.10.7
//   printing: ^5.11.1

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/labour_salary_history_model.dart';

class LabourPayrollPdfService {
  Future<Uint8List> generateMonthlyPayrollPdf({
    required String month,
    required List<LabourSalaryHistoryModel> records,
  }) async {
    final pdf = pw.Document();

    const headers = [
      'Labour ID',
      'Name',
      'Bank Account',
      'OT Hrs',
      'Gross',
      'PF',
      'ESI',
      'Insurance',
      'Welfare',
      'Deduction',
      'Net Salary',
    ];

    final totalGross = records.fold<double>(0, (s, r) => s + r.grossWages);
    final totalPf = records.fold<double>(0, (s, r) => s + r.pfAmount);
    final totalEsi = records.fold<double>(0, (s, r) => s + r.esiAmount);
    final totalInsurance =
    records.fold<double>(0, (s, r) => s + r.insurance);
    final totalWelfare = records.fold<double>(0, (s, r) => s + r.welfare);
    final totalDeduction =
    records.fold<double>(0, (s, r) => s + r.totalDeductions);
    final totalNet = records.fold<double>(0, (s, r) => s + r.netSalary);

    pw.Widget cell(String text,
        {bool bold = false, PdfColor? color, double fontSize = 10.5}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color ?? PdfColors.black,
          ),
        ),
      );
    }

    final headerRow = pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF37474F)),
      children: headers
          .map((h) => cell(h, bold: true, color: PdfColors.white, fontSize: 11))
          .toList(),
    );

    final dataRows = records
        .map((r) => pw.TableRow(children: [
      cell(r.labourId),
      cell(r.name),
      cell(r.bankAccount.isEmpty ? '-' : r.bankAccount),
      cell(r.otHours.toStringAsFixed(1)),
      cell(r.grossWages.toStringAsFixed(0)),
      cell(r.pfAmount.toStringAsFixed(0)),
      cell(r.esiAmount.toStringAsFixed(2)),
      cell(r.insurance.toStringAsFixed(0)),
      cell(r.welfare.toStringAsFixed(0)),
      cell(r.totalDeductions.toStringAsFixed(0)),
      cell(r.netSalary.toStringAsFixed(0)),
    ]))
        .toList();

    String fmtGenerated(DateTime dt) {
      final day = dt.day.toString().padLeft(2, '0');
      final month2 = dt.month.toString().padLeft(2, '0');
      final year = dt.year.toString();
      int hour12 = dt.hour % 12;
      if (hour12 == 0) hour12 = 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$day-$month2-$year $hour12:$minute $period';
    }

    final generatedAt = fmtGenerated(DateTime.now());

    final totalRow = pw.TableRow(
      decoration: const pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border(top: pw.BorderSide(width: 1.2, color: PdfColors.black)),
      ),
      children: [
        cell('TOTAL', bold: true, fontSize: 11),
        cell('', bold: true, fontSize: 11),
        cell('', bold: true, fontSize: 11),
        cell('', bold: true, fontSize: 11),
        cell(totalGross.toStringAsFixed(0), bold: true, fontSize: 11),
        cell(totalPf.toStringAsFixed(0), bold: true, fontSize: 11),
        cell(totalEsi.toStringAsFixed(2), bold: true, fontSize: 11),
        cell(totalInsurance.toStringAsFixed(0), bold: true, fontSize: 11),
        cell(totalWelfare.toStringAsFixed(0), bold: true, fontSize: 11),
        cell(totalDeduction.toStringAsFixed(0), bold: true, fontSize: 11),
        cell(totalNet.toStringAsFixed(0), bold: true, fontSize: 11),
      ],
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Dharani Cotton Mill',
              style:
              pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Labour Salary Register',
              style:
              pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Month : $month',
                    style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Generated : $generatedAt',
                    style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Container(height: 1, color: PdfColors.black),
            pw.SizedBox(height: 12),
          ],
        ),
        build: (context) => [
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.6),
            children: [headerRow, ...dataRows, totalRow],
          ),
          pw.SizedBox(height: 18),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Total Labour : ${records.length}',
                style:
                pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'Total Salary : Rs.${totalNet.toStringAsFixed(2)}',
                style:
                pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Center(
            child: pw.Text(
              '*** Monthly Payroll Statement ***',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }
}