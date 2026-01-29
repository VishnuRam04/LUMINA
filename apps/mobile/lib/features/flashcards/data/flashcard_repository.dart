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
    Query query = _firestore.collection('flashcards').where('subject_id', isEqualTo: subjectId);
    
    if (fileId != null) {
      // Assuming file_id is stored in snake_case in Firestore (from Python model)
      query = query.where('file_id', isEqualTo: fileId);
    }

    return query
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Flashcard.fromJson(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }
  
  // Future: Filter by 'new', 'learning' if needed for different tabs

  Future<void> reviewCard(String cardId, int rating) async {
    // 1-2: Need Review, 3-5: Got It
    // In UI: "Need Review" maps to 1. "I Got It" maps to 5.
    await _apiClient.reviewFlashcard(cardId, rating);
  }
  
  Future<void> addCard(String subjectId, String front, String back, {String? fileId}) async {
    await _apiClient.createFlashcard(subjectId, front, back, fileId: fileId);
  }

  Future<void> generateMore(String subjectId, String text) async {
    await _apiClient.manualGenerateFlashcards(subjectId, text);
  }
}
