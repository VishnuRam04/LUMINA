import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/task.dart';

class TaskRepository {
  TaskRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _tasksRef(String uid) {
    return _db.collection('users').doc(uid).collection('tasks');
  }

  Stream<List<TaskItem>> watchTasks(String uid) {
    return _tasksRef(uid)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => TaskItem.fromMap(d.id, d.data())).toList());
  }

  Future<void> addTask({
    required String uid,
    required String title,
    required String description,
    required DateTime? dueDate,
    required TaskPriority priority,
    required TaskStatus status,
    required String? subjectId,
  }) async {
    await _tasksRef(uid).add({
      'title': title.trim(),
      'description': description.trim(),
      'due_date': dueDate == null ? null : Timestamp.fromDate(dueDate),
      'priority': TaskItem.priorityToString(priority),
      'status': TaskItem.statusToString(status),
      'subject_id': subjectId,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateTask({
    required String uid,
    required String taskId,
    required String title,
    required String description,
    required DateTime? dueDate,
    required TaskPriority priority,
    required TaskStatus status,
    required String? subjectId,
  }) async {
    await _tasksRef(uid).doc(taskId).update({
      'title': title.trim(),
      'description': description.trim(),
      'due_date': dueDate == null ? null : Timestamp.fromDate(dueDate),
      'priority': TaskItem.priorityToString(priority),
      'status': TaskItem.statusToString(status),
      'subject_id': subjectId,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteTask({required String uid, required String taskId}) async {
    await _tasksRef(uid).doc(taskId).delete();
  }
}
