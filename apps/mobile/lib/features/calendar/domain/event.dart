import 'package:cloud_firestore/cloud_firestore.dart';

class CalendarEvent {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String location;
  final String? subjectId;
  final bool isRecurring;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.subjectId,
    required this.isRecurring,
  });

  factory CalendarEvent.fromMap(String id, Map<String, dynamic> data) {
    return CalendarEvent(
      id: id,
      title: (data['title'] ?? '') as String,
      startTime: (data['start_time'] as Timestamp).toDate(),
      endTime: (data['end_time'] as Timestamp).toDate(),
      location: (data['location'] ?? '') as String,
      subjectId: data['subject_id'] as String?,
      isRecurring: (data['is_recurring'] ?? false) as bool,
    );
  }
}
