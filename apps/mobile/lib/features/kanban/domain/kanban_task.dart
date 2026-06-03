import 'package:cloud_firestore/cloud_firestore.dart';

class KanbanTask {
  final String id;
  final String title;
  final String columnId; 
  final DateTime? dueDate;
  final List<String> assignees; 
  final List<String> unreadBy; 
  final int commentCount;
  final String priority; 
  final String? attachmentUrl;
  final String? attachmentName;

  KanbanTask({
    required this.id,
    required this.title,
    required this.columnId,
    this.dueDate,
    required this.assignees,
    this.unreadBy = const [],
    this.commentCount = 0,
    this.priority = 'low',
    this.attachmentUrl,
    this.attachmentName,
  });

  factory KanbanTask.fromMap(String id, Map<String, dynamic> data) {
    return KanbanTask(
      id: id,
      title: data['title'] ?? '',
      columnId: data['column_id'] ?? 'todo',
      dueDate: (data['due_date'] as Timestamp?)?.toDate(),
      assignees: List<String>.from(data['assignees'] ?? []),
      unreadBy: List<String>.from(data['unread_by'] ?? []),
      commentCount: data['comment_count'] ?? 0,
      priority: data['priority'] ?? 'low',
      attachmentUrl: data['attachment_url'],
      attachmentName: data['attachment_name'],
    );
  }
}
