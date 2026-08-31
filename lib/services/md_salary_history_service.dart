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
}