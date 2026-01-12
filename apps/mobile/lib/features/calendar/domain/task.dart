import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskPriority { high, medium, low }
enum TaskStatus { todo, doing, done }

class TaskItem {
  final String id;
  final String title;
  final String description;
  final DateTime? dueDate;
  final TaskPriority priority;
  final TaskStatus status;
  final String? subjectId;

  TaskItem({
    required this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.priority,
    required this.status,
    required this.subjectId,
  });

  static TaskPriority _priorityFrom(String? v) {
    switch (v) {
      case 'high':
        return TaskPriority.high;
      case 'medium':
        return TaskPriority.medium;
      case 'low':
      default:
        return TaskPriority.low;
    }
  }

  static TaskStatus _statusFrom(String? v) {
    switch (v) {
      case 'doing':
        return TaskStatus.doing;
      case 'done':
        return TaskStatus.done;
      case 'todo':
      default:
        return TaskStatus.todo;
    }
  }

  static String priorityToString(TaskPriority p) =>
      p == TaskPriority.high ? 'high' : p == TaskPriority.medium ? 'medium' : 'low';

  static String statusToString(TaskStatus s) =>
      s == TaskStatus.todo ? 'todo' : s == TaskStatus.doing ? 'doing' : 'done';

  factory TaskItem.fromMap(String id, Map<String, dynamic> data) {
    final ts = data['due_date'];
    DateTime? due;
    if (ts is Timestamp) due = ts.toDate();

    return TaskItem(
      id: id,
      title: (data['title'] ?? '') as String,
      description: (data['description'] ?? '') as String,
      dueDate: due,
      priority: _priorityFrom(data['priority'] as String?),
      status: _statusFrom(data['status'] as String?),
      subjectId: data['subject_id'] as String?,
    );
  }
}
