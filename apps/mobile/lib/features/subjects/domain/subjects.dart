import 'package:cloud_firestore/cloud_firestore.dart';

class Subject {
  final String id;
  final String subjectName;
  final String subjectCode;
  final String subjectLecturer;
  final String? colorHex;
  final String? section;
  final bool hasStudyPlan;
  final List<String> bloomLevels;

  Subject({
    required this.id,
    required this.subjectName,
    required this.subjectCode,
    required this.subjectLecturer,
    this.colorHex,
    this.section,
    this.hasStudyPlan = false,
    this.bloomLevels = const [],
  });

  factory Subject.fromMap(String id, Map<String, dynamic> data) {
    return Subject(
      id: id,
      subjectName: (data['subject_name'] ?? '') as String,
      subjectCode: (data['subject_code'] ?? '') as String,
      subjectLecturer: (data['subject_lecturer'] ?? '') as String,
      colorHex: data['color_hex'] as String?,
      section: data['section'] as String?,
      hasStudyPlan: data['has_study_plan'] as bool? ?? false,
      bloomLevels: List<String>.from(data['bloom_levels'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'subject_name': subjectName,
      'subject_code': subjectCode,
      'subject_lecturer': subjectLecturer,
      if (colorHex != null) 'color_hex': colorHex,
      if (section != null) 'section': section,
      'has_study_plan': hasStudyPlan,
      'bloom_levels': bloomLevels,
      'updated_at': FieldValue.serverTimestamp(),
      'created_at': FieldValue.serverTimestamp(),
    };
  }
}
