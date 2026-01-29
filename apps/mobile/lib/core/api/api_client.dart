import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  // ---------------------------------------------------------------------------
  // ⚠️ IMPORTANT FOR PHYSICAL DEVICE:
  // 1. Run "ifconfig" in terminal to find your IP (e.g., 192.168.1.10).
  // 2. Replace "127.0.0.1" below with that IP if running on a real phone.
  // 3. Ensure your phone and computer are on the SAME Wi-Fi.
  // ---------------------------------------------------------------------------
  static String get baseUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000'; // Android Emulator
    }
    // For iOS Simulator: 127.0.0.1 is fine.
    // For Physical Device: CHANGE THIS to your LAN IP!
    return 'http://172.17.94.57:8000';
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
        headers: {'Content-Type': 'application/json'},
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

  Future<Map<String, dynamic>> chat(String query, {List<Map<String, String>> history = const []}) async {
    final url = Uri.parse('$baseUrl/chat');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'query': query,
          'history': history,
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
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'filename': filename}),
      );
    } catch (e) {
      print('API Delete Error: $e');
      // Non-critical, so we can swallow or log
    }
  }
  Future<void> reviewFlashcard(String cardId, int rating) async {
    final url = Uri.parse('$baseUrl/flashcards/review');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
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
        headers: {'Content-Type': 'application/json'},
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
        headers: {'Content-Type': 'application/json'},
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
  Future<Map<String, dynamic>> generateQuiz(String subjectId, List<String> fileIds, {int count = 10, String difficulty = "Medium"}) async {
    final url = Uri.parse('$baseUrl/quiz/generate');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'subject_id': subjectId,
          'file_ids': fileIds,
          'count': count,
          'difficulty': difficulty
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
        headers: {'Content-Type': 'application/json'},
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
      final response = await http.get(url);
      if (response.statusCode != 200) throw Exception('Failed to fetch quizzes');
      return jsonDecode(response.body) as List<dynamic>;
    } catch (e) {
      print('API Error: $e');
      rethrow;
    }
  }
}
