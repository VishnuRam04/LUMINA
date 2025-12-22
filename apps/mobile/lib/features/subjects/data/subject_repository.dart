import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/subjects.dart';

class SubjectRepository {
  SubjectRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _subjectsRef(String uid) {
    return _db.collection('users').doc(uid).collection('subjects');
  }

  Stream<List<Subject>> watchSubjects(String uid) {
    return _subjectsRef(uid)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Subject.fromMap(d.id, d.data()))
            .toList());
  }

  Future<void> addSubject({
    required String uid,
    required String subjectName,
    required String subjectCode,
    required String subjectLecturer,
  }) async {
    await _subjectsRef(uid).add({
      'subject_name': subjectName.trim(),
      'subject_code': subjectCode.trim(),
      'subject_lecturer': subjectLecturer.trim(),
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateSubject({
    required String uid,
    required String subjectId,
    required String subjectName,
    required String subjectCode,
    required String subjectLecturer,
  }) async {
    await _subjectsRef(uid).doc(subjectId).update({
      'subject_name': subjectName.trim(),
      'subject_code': subjectCode.trim(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteSubject({
    required String uid,
    required String subjectId,
  }) async {
    await _subjectsRef(uid).doc(subjectId).delete();
  }
}
