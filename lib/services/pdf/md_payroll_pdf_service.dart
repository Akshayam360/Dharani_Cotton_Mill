// lib/services/pdf/md_payroll_pdf_service.dart
//
// Generates a one-page-per-month MD salary register PDF, styled to
// match the app's teal MD theme.
//
// Built as a manual pw.Table (rather than TableHelper.fromTextArray) so
// the final TOTAL row can be bold + shaded independently of the regular
// data rows — fromTextArray only supports one uniform style for every
// row, which isn't enough to make just the last row stand out.
//
// Requires the `pdf` package — if not in pubspec.yaml yet, add:
//   pdf: ^3.10.7
//   printing: ^5.11.1
//
// NOTE: cells use "Rs." instead of "₹" — the pdf package's default font
// can't render the ₹ glyph (it shows as a garbled box character), so
// this deliberately differs from the Labour version to avoid
// reintroducing that bug.

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/md_salary_history_model.dart';

class MDPayrollPdfService {
  Future<Uint8List> generateMonthlyPayrollPdf({
    required String month,
    required List<MDSalaryHistoryModel> records,
  }) async {
    final pdf = pw.Document();

    const brandTeal = PdfColor.fromInt(0xFF00695C);

    const headers = [
      'MD ID',
      'Name',
      'Bank Account',
      'Gross',
      'PF',
      'Insurance',
      'Welfare',
      'TDS',
      'Deduction',
      'Net Salary',
    ];

    final totalGross = records.fold<double>(0, (s, r) => s + r.grossWages);
    final totalPf = records.fold<double>(0, (s, r) => s + r.pfAmount);
    final totalInsurance =
    records.fold<double>(0, (s, r) => s + r.insurance);
    final totalWelfare = records.fold<double>(0, (s, r) => s + r.welfare);
    final totalTds = records.fold<double>(0, (s, r) => s + r.tds);
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
      decoration: const pw.BoxDecoration(color: brandTeal),
      children: headers
          .map((h) => cell(h, bold: true, color: PdfColors.white, fontSize: 11))
          .toList(),
    );

    final dataRows = records
        .map((r) => pw.TableRow(children: [
      cell(r.MDId),
      cell(r.name),
      cell(r.bankAccount.isEmpty ? '-' : r.bankAccount),
      cell(r.grossWages.toStringAsFixed(0)),
      cell(r.pfAmount.toStringAsFixed(0)),
      cell(r.insurance.toStringAsFixed(0)),
      cell(r.welfare.toStringAsFixed(0)),
      cell(r.tds.toStringAsFixed(0)),
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
        cell(totalPf.toStringAsFixed(0), bold: true, fontSize: 11),
        cell(totalInsurance.toStringAsFixed(0), bold: true, fontSize: 11),
        cell(totalWelfare.toStringAsFixed(0), bold: true, fontSize: 11),
        cell(totalTds.toStringAsFixed(0), bold: true, fontSize: 11),
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
                  fontSize: 20, fontWeight: pw.FontWeight.bold, color: brandTeal),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'MD Salary Register',
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
                'Total MD : ${records.length}',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'Total Salary : Rs.${totalNet.toStringAsFixed(2)}',
                style: pw.TextStyle(
                    fontSize: 13, fontWeight: pw.FontWeight.bold, color: brandTeal),
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

  /// Generates a single-page payslip PDF for one MD record — used by
  /// the per-row PDF/Print actions in the Salary History table.
  Future<Uint8List> generateSalarySlipPdf(MDSalaryHistoryModel r) async {
    final doc = pw.Document();
    const brandTeal = PdfColor.fromInt(0xFF00695C);

    pw.Widget row(String label, String value, {bool bold = false}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Dharani Cotton Mill',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text('MD Salary Slip',
                style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
            pw.SizedBox(height: 4),
            pw.Text(r.monthLabel, style: const pw.TextStyle(fontSize: 11)),
            pw.Divider(),
            row('MD ID', r.MDId),
            row('Name', r.name),
            row('Account No', r.bankAccount.isEmpty ? '-' : r.bankAccount),
            row('Present Days', r.presentDays == r.presentDays.roundToDouble()
                ? r.presentDays.toInt().toString()
                : r.presentDays.toStringAsFixed(1)),
            pw.Divider(),
            row('Basic + DA (60%)', 'Rs.${r.basicDa.toStringAsFixed(2)}'),
            row('HRA (40%)', 'Rs.${r.hra.toStringAsFixed(2)}'),
            row('Gross Wages', 'Rs.${r.grossWages.toStringAsFixed(2)}', bold: true),
            pw.SizedBox(height: 6),
            row('PF (12%)', 'Rs.${r.pfAmount.toStringAsFixed(2)}'),
            row('Insurance', 'Rs.${r.insurance.toStringAsFixed(2)}'),
            row('Welfare', 'Rs.${r.welfare.toStringAsFixed(2)}'),
            row('TDS', 'Rs.${r.tds.toStringAsFixed(2)}'),
            row('Total Deductions', 'Rs.${r.totalDeductions.toStringAsFixed(2)}',
                bold: true),
            pw.Divider(thickness: 1),
            pw.SizedBox(height: 4),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              color: brandTeal,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Net Salary',
                      style: pw.TextStyle(
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 13)),
                  pw.Text('Rs.${r.netSalary.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return doc.save();
  }
}