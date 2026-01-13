class KanbanBoard {
  final String id;
  final String title;
  final String description;
  final DateTime updatedAt;
  final List<String> memberAvatars; // Lists of URLs for member avatars

  KanbanBoard({
    required this.id,
    required this.title,
    required this.description,
    required this.updatedAt,
    required this.memberAvatars,
  });

  factory KanbanBoard.fromMap(String id, Map<String, dynamic> data) {
    return KanbanBoard(
      id: id,
      title: (data['title'] ?? '') as String,
      description: (data['description'] ?? '') as String,
      updatedAt: (data['updated_at'] as dynamic)?.toDate() ?? DateTime.now(),
      memberAvatars: List<String>.from(data['member_avatars'] ?? []),
    );
  }
}
