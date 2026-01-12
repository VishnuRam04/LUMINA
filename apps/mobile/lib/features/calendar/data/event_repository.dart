import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/event.dart';

class EventRepository {
  EventRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _eventsRef(String uid) {
    return _db.collection('users').doc(uid).collection('events');
  }

  Stream<List<CalendarEvent>> watchEvents(String uid) {
    return _eventsRef(uid)
        .orderBy('start_time', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => CalendarEvent.fromMap(d.id, d.data())).toList());
  }

  Future<void> addEvent({
    required String uid,
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    required String location,
    required String? subjectId,
    required bool isRecurring,
  }) async {
    await _eventsRef(uid).add({
      'title': title.trim(),
      'start_time': Timestamp.fromDate(startTime),
      'end_time': Timestamp.fromDate(endTime),
      'location': location.trim(),
      'subject_id': subjectId,
      'is_recurring': isRecurring,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteEvent({required String uid, required String eventId}) async {
    await _eventsRef(uid).doc(eventId).delete();
  }
}
