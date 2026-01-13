import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/kanban_board.dart';

class KanbanRepository {
  KanbanRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _boardsRef(String uid) {
    // Assuming boards are top-level or user-specific? 
    // Usually boards are shared, so maybe top-level 'boards' collection 
    // and we query where user is a member.
    // For now, let's stick to user-specific for simplicity as per other features, 
    // or maybe simple 'boards' collection if valid.
    // Given the prompt "join them", they are likely shared.
    return _db.collection('boards');
  }

  Stream<List<KanbanBoard>> watchBoards(String uid) {
    // Watch boards where 'members' array contains uid
    return _boardsRef(uid)
        .where('members', arrayContains: uid)
        .orderBy('updated_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => KanbanBoard.fromMap(d.id, d.data()))
            .toList());
  }

  Future<void> createBoard({
    required String uid,
    required String title,
    required String description,
    required bool isPublic,
  }) async {
    await _boardsRef(uid).add({
      'title': title,
      'description': description,
      'is_public': isPublic,
      'members': [uid],
      'member_avatars': ['https://i.pravatar.cc/150?u=$uid'], // Placeholder avatar
      'created_by': uid,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> joinBoard(String uid, String boardCode) async {
    // Logic to find board by code and add uid to members
    // implementation pending backend logic for "codes"
  }

  Future<void> deleteBoard(String boardId) async {
    await _db.collection('boards').doc(boardId).delete();
  }
}
