class KanbanBoard {
  final String id;
  final String title;
  final String description;
  final DateTime updatedAt;
  final List<String> memberAvatars;
  final List<String> memberNames;
  final List<String> members;
  final List<dynamic> columns;
  String ownerUid = '';

  KanbanBoard({
    required this.id,
    required this.title,
    required this.description,
    required this.updatedAt,
    required this.memberAvatars,
    required this.memberNames,
    required this.members,
    required this.columns,
  });

  factory KanbanBoard.fromMap(String id, Map<String, dynamic> data) {
    return KanbanBoard(
      id: id,
      title: (data['title'] ?? '') as String,
      description: (data['description'] ?? '') as String,
      updatedAt: (data['updated_at'] as dynamic)?.toDate() ?? DateTime.now(),
      memberAvatars: List<String>.from(data['member_avatars'] ?? []),
      memberNames: List<String>.from(data['member_names'] ?? []),
      members: List<String>.from(data['members'] ?? []),
      columns: data['columns'] ?? [{'id': 'todo', 'name': 'To Do'}],
    )..ownerUid = data['owner_uid'] ?? '';
  }
}
