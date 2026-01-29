class QuizQuestion {
  final String id;
  final String type; // 'multiple_choice' or 'open_ended'
  final String question;
  final List<String> options;
  final String? correctAnswer;
  final String explanation;

  QuizQuestion({
    required this.id,
    required this.type,
    required this.question,
    required this.explanation,
    this.options = const [],
    this.correctAnswer,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      id: json['id'] ?? '',
      type: json['type'] ?? 'multiple_choice',
      question: json['question'] ?? '',
      options: List<String>.from(json['options'] ?? []),
      correctAnswer: json['correct_answer'],
      explanation: json['explanation'] ?? '',
    );
  }
}

class Quiz {
  final String id;
  final String subjectId;
  final String title;
  final List<QuizQuestion> questions;
  final DateTime createdAt;

  Quiz({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.questions,
    required this.createdAt,
  });

  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      id: json['id'] ?? '',
      subjectId: json['subject_id'] ?? '',
      title: json['title'] ?? 'Generated Quiz',
      questions: (json['questions'] as List)
          .map((q) => QuizQuestion.fromJson(q))
          .toList(),
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}
