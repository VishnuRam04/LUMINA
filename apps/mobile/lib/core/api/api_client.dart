import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class ApiClient {
  static String get baseUrl {
    return 'https://lumina-api-63xt.onrender.com';
    
    // if (kIsWeb) return 'http://127.0.0.1:8000';
    // if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    // return 'http://127.0.0.1:8000';
  } 
  
  Future<Map<String, String>> _getHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {

       throw Exception('User not authenticated');
    }
    final token = await user.getIdToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<void> ingestFile({
    required String filePath, 
    required String subjectId, 
    required String filename
  }) async {
    final url = Uri.parse('$baseUrl/ingest');
    try {
      print('Calling Ingest API: $url');
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'file_path': filePath,
          'subject_id': subjectId,
          'filename': filename,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to ingest file: ${response.body}');
      }
      print('Ingestion successful: ${response.body}');
    } catch (e) {
      print('API Error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> studyPlan({
    required String filePath, 
    required String subjectId, 
    required String filename,
    String? section,
  }) async {
    final url = Uri.parse('$baseUrl/study-plan/generate');
    try {
      print('Calling Study Plan API: $url');
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'file_path': filePath,
          'subject_id': subjectId,
          'filename': filename,
          if (section != null && section.isNotEmpty) 'section': section,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to generate study plan: ${response.body}');
      }
      print('Study plan generated successfully: ${response.body}');
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      print('API Error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> chat(String query, {List<Map<String, String>> history = const [], String? imageBase64}) async {
    final url = Uri.parse('$baseUrl/chat');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'query': query,
          'history': history,
          if (imageBase64 != null) 'image_base64': imageBase64,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Chat failed: ${response.body}');
      }
      
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      print('API Error: $e');
      rethrow;
    }
  }

  Future<void> deleteFile(String filename) async {
    final url = Uri.parse('$baseUrl/delete');
    try {
      await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({'filename': filename}),
      );
    } catch (e) {
      print('API Delete Error: $e');
    }
  }
  
  Future<void> reviewFlashcard(String cardId, int rating) async {
    final url = Uri.parse('$baseUrl/flashcards/review');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'card_id': cardId,
          'rating': rating,
        }),
      );
       if (response.statusCode != 200) {
        throw Exception('Review failed: ${response.body}');
      }
    } catch (e) {
      print('API Error: $e');
      rethrow;
    }
  }

  Future<void> manualGenerateFlashcards(String subjectId, String text) async {
    final url = Uri.parse('$baseUrl/flashcards/generate');
     try {
      await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'subject_id': subjectId,
          'text_content': text,
          'count': 5
        }),
      );
    } catch (e) {
      print('API Error: $e');
      rethrow;
    }
  }
  
  Future<void> createFlashcard(String subjectId, String front, String back, {String? fileId}) async {
    final url = Uri.parse('$baseUrl/flashcards/create');
    try {
      await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'subject_id': subjectId,
          'file_id': fileId,
          'front': front,
          'back': back,
        }),
      );
    } catch (e) {
      print('API Error: $e');
      rethrow;
    }
  }
  
  Future<Map<String, dynamic>> generateQuiz(String subjectId, List<String> fileIds, {int count = 10, List<String> bloomLevels = const []}) async {
    final url = Uri.parse('$baseUrl/quiz/generate');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'subject_id': subjectId,
          'file_ids': fileIds,
          'count': count,
          'bloom_levels': bloomLevels
        }),
      );
      
       if (response.statusCode != 200) {
        throw Exception('Quiz generation failed: ${response.body}');
      }
      return jsonDecode(response.body);
    } catch (e) {
      print('API Error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> gradeOpenEnded(String question, String userAnswer, String context) async {
    final url = Uri.parse('$baseUrl/quiz/grade');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'question': question,
          'user_answer': userAnswer,
          'context': context
        }),
      );
      if (response.statusCode != 200) throw Exception('Grading failed');
      return jsonDecode(response.body);
    } catch (e) {
      print('API Error: $e');
      rethrow;
    }
  }
  
  Future<List<dynamic>> getQuizzes(String subjectId) async {
    final url = Uri.parse('$baseUrl/quiz/list/$subjectId');
    try {
      final response = await http.get(
        url,
        headers: await _getHeaders(),
      );
      if (response.statusCode != 200) throw Exception('Failed to fetch quizzes');
      return jsonDecode(response.body) as List<dynamic>;
    } catch (e) {
      print('API Error: $e');
      rethrow;
    }
  }

  Future<void> deleteQuiz(String quizId) async {
    final url = Uri.parse('$baseUrl/quiz/delete/$quizId');
    try {
      final response = await http.delete(
        url,
        headers: await _getHeaders(),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to delete quiz: ${response.body}');
      }
    } catch (e) {
      print('API Error: $e');
      rethrow;
    }
  }
  Future<void> updateQuizScore(String quizId, double score) async {
    final url = Uri.parse('$baseUrl/quiz/score/$quizId');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({'score': score}),
      );
      if (response.statusCode != 200) throw Exception('Failed to update score');
    } catch (e) {
      print('API Error: $e');
      rethrow;
    }
  }

  Future<void> deleteUser(String uid) async {
    final url = Uri.parse('$baseUrl/admin/users/$uid');
    try {
      final response = await http.delete(
        url,
        headers: await _getHeaders(),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to delete user: ${response.body}');
      }
    } catch (e) {
      print('API Error: $e');
      rethrow;
    }
  }
}
