import 'package:cloud_firestore/cloud_firestore.dart';

class Flashcard {
  final String id;
  final String subjectId;
  final String? fileId;
  final String front;
  final String back;
  final String status; // 'new', 'learning', 'mastered'
  final DateTime nextReview;
  final int repetition;
  final int interval;
  final double easeFactor;

  Flashcard({
    required this.id,
    required this.subjectId,
    this.fileId,
    required this.front,
    required this.back,
    required this.status,
    required this.nextReview,
    required this.repetition,
    required this.interval,
    required this.easeFactor,
  });

  factory Flashcard.fromJson(Map<String, dynamic> json, String id) {
    return Flashcard(
      id: id,
      subjectId: json['subject_id'] ?? '',
      fileId: json['file_id'],
      front: json['front'] ?? '',
      back: json['back'] ?? '',
      status: json['status'] ?? 'new',
      nextReview: _parseDate(json['next_review']),
      repetition: json['repetition'] ?? 0,
      interval: json['interval'] ?? 0,
      easeFactor: (json['ease_factor'] ?? 2.5).toDouble(),
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }
}
