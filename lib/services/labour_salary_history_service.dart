// lib/services/labour_salary_history_service.dart
//
// Firestore access for `labour_salary_history`. Simpler than Staff's
// equivalent service — Labour has no CL/OD leave balance to restore on
// delete, so deleting a record is a plain doc delete.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/labour_salary_history_model.dart';

class LabourSalaryHistoryService {
  final CollectionReference<Map<String, dynamic>> _ref =
  FirebaseFirestore.instance.collection('labour_salary_history');

  Stream<List<LabourSalaryHistoryModel>> getSalaryHistory() {
    return _ref.snapshots().map(
          (snap) => snap.docs.map(LabourSalaryHistoryModel.fromDoc).toList(),
    );
  }

  Future<void> deleteSalaryHistory(String id) => _ref.doc(id).delete();

  /// Deletes every saved salary history record. Used by "Clear All History".
  Future<void> deleteAll() async {
    final snap = await _ref.get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// Deletes every record for a given year, across all months.
  Future<void> deleteByYear(int year) async {
    final snap = await _ref.where('year', isEqualTo: year).get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// Deletes every record for one specific month + year combination.
  Future<void> deleteByMonth(int month, int year) async {
    final snap = await _ref
        .where('year', isEqualTo: year)
        .where('month', isEqualTo: month)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}