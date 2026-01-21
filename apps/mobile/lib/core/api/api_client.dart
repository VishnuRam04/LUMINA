import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  // Use localhost for iOS simulator
  static const String baseUrl = 'http://127.0.0.1:8000'; 

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

  Future<Map<String, dynamic>> chat(String query) async {
    final url = Uri.parse('$baseUrl/chat');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'query': query,
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
}
