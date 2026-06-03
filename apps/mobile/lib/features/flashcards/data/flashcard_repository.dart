import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/api/api_client.dart';
import '../domain/flashcard.dart';

class FlashcardRepository {
  final FirebaseFirestore _firestore;
  final ApiClient _apiClient;

  FlashcardRepository({FirebaseFirestore? firestore, ApiClient? apiClient})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _apiClient = apiClient ?? ApiClient();

  Stream<List<Flashcard>> watchCards(String subjectId, {String? fileId}) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);

    Query query = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('flashcards')
        .where('subject_id', isEqualTo: subjectId);
    
    if (fileId != null) {
      query = query.where('file_id', isEqualTo: fileId);
    }

    return query
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Flashcard.fromJson(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }
  

  Future<void> reviewCard(String cardId, int rating) async {

    await _apiClient.reviewFlashcard(cardId, rating);
  }
  
  Future<void> addCard(String subjectId, String front, String back, {String? fileId}) async {
    await _apiClient.createFlashcard(subjectId, front, back, fileId: fileId);
  }

  Future<void> generateMore(String subjectId, String text) async {
    await _apiClient.manualGenerateFlashcards(subjectId, text);
  }

  Future<void> deleteCardsByFileId(String uid, String fileId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('flashcards')
        .where('file_id', isEqualTo: fileId)
        .get();

    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
