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
    String? colorHex,
  }) async {
    await _eventsRef(uid).add({
      'title': title.trim(),
      'start_time': Timestamp.fromDate(startTime),
      'end_time': Timestamp.fromDate(endTime),
      'location': location.trim(),
      'subject_id': subjectId,
      'is_recurring': isRecurring,
      if (colorHex != null) 'color_hex': colorHex,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteEvent({required String uid, required String eventId}) async {
    await _eventsRef(uid).doc(eventId).delete();
  }

  Future<void> updateEvent({
    required String uid,
    required String eventId,
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    required String location,
    required String? subjectId,
    required bool isRecurring,
    String? colorHex,
  }) async {
    final Map<String, dynamic> data = {
      'title': title.trim(),
      'start_time': Timestamp.fromDate(startTime),
      'end_time': Timestamp.fromDate(endTime),
      'location': location.trim(),
      'subject_id': subjectId,
      'is_recurring': isRecurring,
      'updated_at': FieldValue.serverTimestamp(),
    };
    if (colorHex != null) data['color_hex'] = colorHex;
    await _eventsRef(uid).doc(eventId).update(data);
  }

  Future<void> deleteEventsBySubjectId(String uid, String subjectId) async {
    final snapshot = await _eventsRef(uid).where('subject_id', isEqualTo: subjectId).get();
    if (snapshot.docs.isNotEmpty) {
      final batch = _db.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}
