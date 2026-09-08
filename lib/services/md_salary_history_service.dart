// lib/services/md_salary_history_service.dart
//
// Firestore access for `md_salary_history`. Simpler than Staff's
// equivalent service — MD has no CL/OD leave balance to restore on
// delete, so deleting a record is a plain doc delete.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/md_salary_history_model.dart';

class MDSalaryHistoryService {
  final CollectionReference<Map<String, dynamic>> _ref =
  FirebaseFirestore.instance.collection('md_salary_history');

  Stream<List<MDSalaryHistoryModel>> getSalaryHistory() {
    return _ref.snapshots().map(
          (snap) => snap.docs.map(MDSalaryHistoryModel.fromDoc).toList(),
    );
  }

  Future<void> deleteSalaryHistory(String id) => _ref.doc(id).delete();

  // -------------------------------------------------------------------
  // CLEAR HISTORY — bulk delete helpers, matching the Labour module's
  // three scopes (all / a whole year / one month).
  // -------------------------------------------------------------------

  Future<void> deleteAll() async {
    final snap = await _ref.get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }

  Future<void> deleteByYear(int year) async {
    final snap = await _ref.where('year', isEqualTo: year).get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }

  Future<void> deleteByMonth(int month, int year) async {
    final snap = await _ref
        .where('month', isEqualTo: month)
        .where('year', isEqualTo: year)
        .get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }
}