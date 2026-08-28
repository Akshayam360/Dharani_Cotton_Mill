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
          (snap) =>
          snap.docs.map(LabourSalaryHistoryModel.fromDoc).toList(),
    );
  }

  Future<void> deleteSalaryHistory(String id) => _ref.doc(id).delete();
}