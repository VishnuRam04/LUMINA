import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/subject_file.dart';

class FileRepository {
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  FileRepository(this._db, this._storage);

  CollectionReference<Map<String, dynamic>> _filesRef(
    String uid,
    String subjectId,
  ) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('subjects')
        .doc(subjectId)
        .collection('files');
  }

  Reference _storageRef(String uid, String subjectId, String filename) {
    return _storage.ref().child(
      'users/$uid/subjects/$subjectId/files/$filename',
    );
  }

  Stream<List<SubjectFile>> watchFiles(String uid, String subjectId) {
    return _filesRef(uid, subjectId)
        .orderBy('uploaded_at', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => SubjectFile.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Future<void> uploadFile({
    required String uid,
    required String subjectId,
    File? file,
    Uint8List? bytes,
    required String filename,
    bool saveMetadata = true,
  }) async {
    print('Starting upload for $filename');

    try {
      final safeFilename = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      print('Sanitized filename: $safeFilename (Original: $filename)');

      final ref = _storageRef(uid, subjectId, safeFilename);
      print('Storage Reference: ${ref.fullPath}');

      UploadTask task;
      if (bytes != null) {
        print('Uploading from bytes (${bytes.length} bytes)');
        task = ref.putData(bytes);
      } else if (file != null) {
        if (!file.existsSync()) {
          throw Exception('File does not exist locally');
        }
        print('Uploading from dart:io File');
        task = ref.putFile(file);
      } else {
        throw Exception('Must provide either file or bytes');
      }

      final snapshot = await task.whenComplete(() {});
      print('Upload whenComplete. State: ${snapshot.state}');

      if (snapshot.state != TaskState.success) {
        throw Exception('Upload failed with state: ${snapshot.state}');
      }

      print('Getting download URL...');
      final url = await snapshot.ref.getDownloadURL();
      print('Download URL obtained: $url');
      final size = snapshot.totalBytes;

      if (saveMetadata) {
        print('Saving metadata to Firestore...');
        await _filesRef(uid, subjectId).add({
          'name': filename,
          'url': url,
          'size_bytes': size,
          'uploaded_at': FieldValue.serverTimestamp(),
        });
        print('Metadata saved.');
      }
    } catch (e, stack) {
      print('ERROR during upload: $e');
      print(stack);
      rethrow;
    }
  }

  Future<void> deleteFile({
    required String uid,
    required String subjectId,
    required String fileId,
    required String filename,
  }) async {
    // 1. Delete from Firestore
    await _filesRef(uid, subjectId).doc(fileId).delete();

    // 2. Delete from Storage
    try {
      final safeFilename = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      await _storageRef(uid, subjectId, safeFilename).delete();
    } catch (e) {
      // Ignore if file doesn't exist in storage
      print('Error deleting file from storage: $e');
    }
  }

  Future<List<String>> getAllUserFiles(String uid) async {
    try {
      // 1. Get all subjects
      final subjectsSnap = await _db
          .collection('users')
          .doc(uid)
          .collection('subjects')
          .get();

      List<String> allFilenames = [];

      // 2. For each subject, get files
      // Using Future.wait for parallel execution
      await Future.wait(
        subjectsSnap.docs.map((subjectDoc) async {
          final filesSnap = await subjectDoc.reference
              .collection('files')
              .get();
          allFilenames.addAll(
            filesSnap.docs.map((d) => d.data()['name'] as String),
          );
        }),
      );

      return allFilenames;
    } catch (e) {
      print('Error fetching all user files: $e');
      return [];
    }
  }

  Future<List<SubjectFile>> getFiles(String uid, String subjectId) async {
    final snap = await _filesRef(
      uid,
      subjectId,
    ).orderBy('uploaded_at', descending: true).get();
    return snap.docs.map((d) => SubjectFile.fromMap(d.id, d.data())).toList();
  }
}
