// lib/services/pdf/exempted_payroll_pdf_service.dart
//
// Generates a one-page-per-month Exempted salary register PDF, styled
// to match the app's deep-teal Exempted theme. Simpler than MD/Labour's
// version since Exempted has no PF/ESI/TDS — just Gross, Insurance,
// Welfare and Net Salary.
//
// Built as a manual pw.Table (not TableHelper.fromTextArray) so the
// TOTAL row can be bold + shaded independently of the regular rows.
//
// NOTE: cells use "Rs." instead of "₹" — the pdf package's default font
// can't render the ₹ glyph (shows as a garbled box character).

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/exempted_salary_history_model.dart';

class ExemptedPayrollPdfService {
  Future<Uint8List> generateMonthlyPayrollPdf({
    required String month,
    required List<ExemptedSalaryHistoryModel> records,
  }) async {
    final pdf = pw.Document();

    const brandColor = PdfColor.fromInt(0xFF00838F);

    const headers = [
      'Emp ID',
      'Name',
      'Bank Account',
      'Gross',
      'Insurance',
      'Welfare',
      'Deduction',
      'Net Salary',
    ];

    final totalGross = records.fold<double>(0, (s, r) => s + r.grossWages);
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
      decoration: const pw.BoxDecoration(color: brandColor),
      children: headers
          .map((h) => cell(h, bold: true, color: PdfColors.white, fontSize: 11))
          .toList(),
    );

    final dataRows = records
        .map((r) => pw.TableRow(children: [
      cell(r.empId),
      cell(r.name),
      cell(r.bankAccount.isEmpty ? '-' : r.bankAccount),
      cell(r.grossWages.toStringAsFixed(0)),
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
        cell(totalGross.toStringAsFixed(0), bold: true, fontSize: 11),
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
              style: pw.TextStyle(
                  fontSize: 20, fontWeight: pw.FontWeight.bold, color: brandColor),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Exempted Salary Register',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
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
                'Total Exempted : ${records.length}',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'Total Salary : Rs.${totalNet.toStringAsFixed(2)}',
                style: pw.TextStyle(
                    fontSize: 13, fontWeight: pw.FontWeight.bold, color: brandColor),
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