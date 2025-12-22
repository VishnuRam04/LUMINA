import 'package:cloud_firestore/cloud_firestore.dart';

class Subject {
  final String id;
  final String subjectName;
  final String subjectCode;
  final String subjectLecturer;

  Subject({
    required this.id,
    required this.subjectName,
    required this.subjectCode,
    required this.subjectLecturer,
  });

  factory Subject.fromMap(String id, Map<String, dynamic> data) {
    return Subject(
      id: id,
      subjectName: (data['subject_name'] ?? '') as String,
      subjectCode: (data['subject_code'] ?? '') as String,
      subjectLecturer: (data['subject_lecturer'] ?? '') as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'subject_name': subjectName,
      'subject_code': subjectCode,
      'subject_lecturer': subjectLecturer,
      'updated_at': FieldValue.serverTimestamp(),
      'created_at': FieldValue.serverTimestamp(),
    };
  }
}
