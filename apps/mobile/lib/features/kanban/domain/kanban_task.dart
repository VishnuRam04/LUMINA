import 'package:cloud_firestore/cloud_firestore.dart';

class KanbanTask {
  final String id;
  final String title;
  final String columnId; // 'todo', 'in_progress', 'done' or custom IDs
  final DateTime? dueDate;
  final List<String> assignees; // URLs or User IDs
  final int commentCount;
  final String priority; // 'high', 'medium', 'low'

  KanbanTask({
    required this.id,
    required this.title,
    required this.columnId,
    this.dueDate,
    required this.assignees,
    this.commentCount = 0,
    this.priority = 'low',
  });

  factory KanbanTask.fromMap(String id, Map<String, dynamic> data) {
    return KanbanTask(
      id: id,
      title: data['title'] ?? '',
      columnId: data['column_id'] ?? 'todo',
      dueDate: (data['due_date'] as Timestamp?)?.toDate(),
      assignees: List<String>.from(data['assignees'] ?? []),
      commentCount: data['comment_count'] ?? 0,
      priority: data['priority'] ?? 'low',
    );
  }
}
