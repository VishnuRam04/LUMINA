import 'package:cloud_firestore/cloud_firestore.dart';

class KanbanComment {
  final String id;
  final String text;
  final String authorId;
  final DateTime createdAt;

  KanbanComment({
    required this.id,
    required this.text,
    required this.authorId,
    required this.createdAt,
  });

  factory KanbanComment.fromMap(String id, Map<String, dynamic> data) {
    return KanbanComment(
      id: id,
      text: data['text'] ?? '',
      authorId: data['author_id'] ?? '',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
