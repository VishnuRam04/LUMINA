import 'package:cloud_firestore/cloud_firestore.dart';

class SubjectFile {
  final String id;
  final String name;
  final String url;
  final int sizeBytes;
  final DateTime uploadedAt;

  SubjectFile({
    required this.id,
    required this.name,
    required this.url,
    required this.sizeBytes,
    required this.uploadedAt,
  });

  factory SubjectFile.fromMap(String id, Map<String, dynamic> data) {
    return SubjectFile(
      id: id,
      name: data['name'] ?? '',
      url: data['url'] ?? '',
      sizeBytes: data['size_bytes'] ?? 0,
      uploadedAt: (data['uploaded_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
