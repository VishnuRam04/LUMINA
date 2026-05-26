import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../domain/kanban_board.dart';
import '../domain/kanban_task.dart';
import '../domain/kanban_comment.dart';

class KanbanRepository {
  KanbanRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _boardsRef() {
    return _db.collection('boards');
  }

  Stream<List<KanbanBoard>> watchBoards(String uid) {
    return _boardsRef()
        .where('members', arrayContains: uid)
        .orderBy('updated_at', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) {
            final data = d.data();
            // We store created_by for knowing who actually owns it
            return KanbanBoard.fromMap(d.id, data)
              ..ownerUid = data['created_by'] ?? data['owner_uid'] ?? '';
          }).toList(),
        );
  }

  Future<String> getOrGenerateShareCode(String uid, String boardId) async {
    try {
      final query = await _db
          .collection('board_codes')
          .where('board_id', isEqualTo: boardId)
          .where('owner_uid', isEqualTo: uid)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        return query.docs.first.id;
      }
    } catch (e) {
      print(
        'Query for existing share code failed (possibly rules propagation): $e',
      );
      // If the list query fails due to temporary permissions, we gracefully fallback
      // and just create a new code. Overwriting is safe.
    }

    String code = (100000 + DateTime.now().microsecondsSinceEpoch % 900000)
        .toString();
    try {
      await _db.collection('board_codes').doc(code).set({
        'board_id': boardId,
        'owner_uid': uid,
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Creating share code failed: $e');
      return 'FAILED'; // Special string handled optionally
    }

    return code;
  }

  Future<void> createBoard({
    required String uid,
    required String title,
    required String description,
    required bool isPublic,
  }) async {
    await _boardsRef().add({
      'title': title,
      'description': description,
      'is_public': isPublic,
      'members': [uid],
      'member_avatars': [
        FirebaseAuth.instance.currentUser?.photoURL ?? '',
      ],
      'member_names': [
        FirebaseAuth.instance.currentUser?.displayName ?? 'User',
      ],
      'created_by': uid,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'columns': [
        {'id': 'todo', 'name': 'To Do'},
      ],
    });
  }

  Future<bool> joinBoard(String guestUid, String boardCode) async {
    if (boardCode.length != 6) return false;
    final doc = await _db.collection('board_codes').doc(boardCode).get();
    if (!doc.exists) return false;

    final data = doc.data()!;
    final String ownerUid = data['owner_uid'];
    final String boardId = data['board_id'];

    if (ownerUid == guestUid) return true; // Already owns it

    // 1. Add guest to the actual Board's members list directly
    final currentAvatarUrl = FirebaseAuth.instance.currentUser?.photoURL ?? '';
    final currentName = FirebaseAuth.instance.currentUser?.displayName ?? 'User';
    
    await _boardsRef().doc(boardId).update({
      'members': FieldValue.arrayUnion([guestUid]),
      'member_avatars': FieldValue.arrayUnion([currentAvatarUrl]),
      'member_names': FieldValue.arrayUnion([currentName]),
    });

    return true;
  }

  Future<void> deleteBoard(String uid, String boardId) async {
    await _boardsRef().doc(boardId).delete();
  }

  // --- Tasks ---

  Stream<List<KanbanTask>> watchTasks(String uid, String boardId) {
    return _boardsRef()
        .doc(boardId)
        .collection('tasks')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => KanbanTask.fromMap(d.id, d.data())).toList(),
        );
  }

  Future<void> addTask({
    required String uid,
    required String boardId,
    required String title,
    required String columnId,
    DateTime? dueDate,
    List<String> assignees = const [],
    String priority = 'low',
    String? attachmentUrl,
    String? attachmentName,
  }) async {
    final unreadBy = assignees.where((id) => id != uid).toList();
    final Map<String, dynamic> data = {
      'title': title,
      'column_id': columnId,
      'due_date': dueDate != null ? Timestamp.fromDate(dueDate) : null,
      'assignees': assignees,
      'unread_by': unreadBy,
      'comment_count': 0,
      'priority': priority,
      'created_at': FieldValue.serverTimestamp(),
    };

    if (attachmentUrl != null) data['attachment_url'] = attachmentUrl;
    if (attachmentName != null) data['attachment_name'] = attachmentName;

    await _boardsRef().doc(boardId).collection('tasks').add(data);
  }

  Future<void> updateTask({
    required String uid,
    required String boardId,
    required String taskId,
    required String title,
    required String columnId,
    DateTime? dueDate,
    String priority = 'low',
    String? attachmentUrl,
    String? attachmentName,
  }) async {
    final Map<String, dynamic> data = {
      'title': title,
      'column_id': columnId,
      'priority': priority,
      'due_date': dueDate != null ? Timestamp.fromDate(dueDate) : null,
    };

    if (attachmentUrl != null) data['attachment_url'] = attachmentUrl;
    if (attachmentName != null) data['attachment_name'] = attachmentName;

    await _boardsRef()
        .doc(boardId)
        .collection('tasks')
        .doc(taskId)
        .update(data);
  }

  // --- Comments ---
  Stream<List<KanbanComment>> watchComments(
    String uid,
    String boardId,
    String taskId,
  ) {
    return _boardsRef()
        .doc(boardId)
        .collection('tasks')
        .doc(taskId)
        .collection('comments')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => KanbanComment.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> addComment({
    required String uid,
    required String boardId,
    required String taskId,
    required String text,
    required String authorId,
    List<String> mentionedUids = const [],
  }) async {
    final taskRef = _boardsRef().doc(boardId).collection('tasks').doc(taskId);
    final commentsRef = taskRef.collection('comments');

    await _db.runTransaction((tx) async {
      // 1. Add the comment document
      final newCommentRef = commentsRef.doc();
      tx.set(newCommentRef, {
        'text': text,
        'author_id': authorId,
        'created_at': FieldValue.serverTimestamp(),
      });

      // 2. Increment comment count and update unread status
      final taskUpdate = <String, dynamic>{
        'comment_count': FieldValue.increment(1),
      };
      if (mentionedUids.isNotEmpty) {
        taskUpdate['unread_by'] = FieldValue.arrayUnion(mentionedUids);
      }
      tx.update(taskRef, taskUpdate);
    });
  }

  Future<void> markTaskRead(String boardId, String taskId, String uid) async {
    await _boardsRef().doc(boardId).collection('tasks').doc(taskId).update({
      'unread_by': FieldValue.arrayRemove([uid]),
    });
  }
}
