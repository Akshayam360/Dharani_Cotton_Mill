// lib/services/exempted_salary_history_service.dart
//
// Firestore access for `exempted_salary_history`. Plain doc delete —
// no leave balance to restore, same as MD/Labour's history services.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/exempted_salary_history_model.dart';

class ExemptedSalaryHistoryService {
  final CollectionReference<Map<String, dynamic>> _ref =
  FirebaseFirestore.instance.collection('exempted_salary_history');

  Stream<List<ExemptedSalaryHistoryModel>> getSalaryHistory() {
    return _ref.snapshots().map(
          (snap) => snap.docs.map(ExemptedSalaryHistoryModel.fromDoc).toList(),
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