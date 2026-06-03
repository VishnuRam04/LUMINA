import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/api/api_client.dart';
import '../domain/quiz_model.dart';
import 'dart:async';

class QuizRepository {
  final FirebaseFirestore _firestore;
  final ApiClient _apiClient;

  QuizRepository({FirebaseFirestore? firestore, ApiClient? apiClient})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _apiClient = apiClient ?? ApiClient();

  Future<List<Quiz>> fetchQuizzes(String subjectId) async {
    final data = await _apiClient.getQuizzes(subjectId);
    return data.map((json) => Quiz.fromJson(json)).toList();
  }

  Future<Quiz> generateQuiz(String subjectId, List<String> fileIds, {int count = 15, List<String> bloomLevels = const []}) async {
    final data = await _apiClient.generateQuiz(subjectId, fileIds, count: count, bloomLevels: bloomLevels);
    return Quiz.fromJson(data);
  }

  Future<Map<String, dynamic>> gradeAnswer(String question, String userAnswer, String context) async {
    return _apiClient.gradeOpenEnded(question, userAnswer, context);
  }

  Future<void> deleteQuiz(String subjectId, String quizId) async {
    await _apiClient.deleteQuiz(quizId);
  }
  Future<void> updateScore(String quizId, double score) async {
    await _apiClient.updateQuizScore(quizId, score);
  }
}
