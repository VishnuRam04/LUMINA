import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/auth/dev_auth.dart';
import '../data/file_repository.dart';
import '../domain/subject_file.dart';
import '../domain/subjects.dart';

class SubjectDetailPage extends StatefulWidget {
  final Subject subject;

  const SubjectDetailPage({super.key, required this.subject});

  @override
  State<SubjectDetailPage> createState() => _SubjectDetailPageState();
}

// ... (SubjectDetailPage class definition remains same)

class _SubjectDetailPageState extends State<SubjectDetailPage> {
  late final FileRepository fileRepo;
  String? uid;
  bool isUploading = false;

  // Mock data for quizzes (keeping this for now as per instructions)
  final List<Map<String, dynamic>> quizzes = [
    {'title': 'Complete Lab Report', 'difficulty': 'Medium', 'questions': 10, 'progress': 0.3},
    {'title': 'Complete Lab Report', 'difficulty': 'Medium', 'questions': 10, 'progress': 0.3},
  ];

  @override
  void initState() {
    super.initState();
    fileRepo = FileRepository(FirebaseFirestore.instance, FirebaseStorage.instance);
    _init();
  }

  Future<void> _init() async {
    final u = await DevAuth.ensureSignedIn();
    if (mounted) setState(() => uid = u);
  }

  Future<void> _pickAndUploadFile() async {
    if (uid == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() => isUploading = true);
      try {
        final file = File(result.files.single.path!);
        final filename = result.files.single.name;
        
        await fileRepo.uploadFile(
          uid: uid!,
          subjectId: widget.subject.id,
          file: file,
          filename: filename,
        );
        
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('File uploaded successfully')),
           );
        }
      } catch (e) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Upload failed: $e')),
           );
        }
      } finally {
        if (mounted) setState(() => isUploading = false);
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    if (uid == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Image.asset(
              'assets/images/background.png',
              fit: BoxFit.cover,
            ),
          ),
          
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Back Button & Title Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       GestureDetector(
                         onTap: () => Navigator.pop(context),
                         child: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.black54),
                       ),
                       // Title
                       Text(
                         widget.subject.subjectName,
                         style: const TextStyle(
                           fontSize: 24,
                           fontWeight: FontWeight.bold,
                         ),
                       ),
                       const SizedBox(width: 24), // Balance spacing
                    ],
                  ),
                  
                  const SizedBox(height: 24),

                  // Subject Info Card
                  _buildSubjectCard(),

                  const SizedBox(height: 24),

                  // Generated Quiz (kept as is)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Generated Quiz',
                      style: TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.bold
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    height: 160,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: quizzes.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        return _buildQuizCard(quizzes[index]);
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Ask Lumina Banner
                  _buildAskLuminaBanner(),

                  const SizedBox(height: 24),

                  // Notes & Materials - REAL DATA
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFFD54F), width: 2), 
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Notes & Materials',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            TextButton.icon(
                              onPressed: isUploading ? null : _pickAndUploadFile,
                              icon: isUploading 
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) 
                                : const Icon(Icons.upload_file, size: 18),
                              label: Text(isUploading ? 'Uploading...' : 'Upload PDF'),
                            ),
                          ],
                        ),
                        const Text(
                          'Uploaded Files',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        
                        StreamBuilder<List<SubjectFile>>(
                          stream: fileRepo.watchFiles(uid!, widget.subject.id),
                          builder: (context, snap) {
                            if (snap.hasError) return Text('Error: ${snap.error}');
                            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                            
                            final files = snap.data!;
                            if (files.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text('No files uploaded yet.', style: TextStyle(color: Colors.grey)),
                              );
                            }

                            return Column(
                              children: files.map((file) => _buildFileItem(file)).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ... (SubjectCard, QuizCard, Banner omitted for brevity if they are unchanged, but replace content tool replaces blocks so I must include them or leverage previous blocks if I could select ranges precisely. 
  // Since I am replacing the whole Class body essentially, I should include the helper methods too or use multiple chunks.
  // I will use replacement chunks to just update the STATE and BUILD method, assuming helpers are at the bottom.)

  // Actually, I'll provide the WHOLE build method and above, and keep the helpers.
  // Wait, I need to update _buildFileItem to take SubjectFile instead of String.


  Widget _buildSubjectCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.transparent), // Gradient border handled by wrapper usually, simplified here
        boxShadow: [
           BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Container(
         decoration: BoxDecoration(
           borderRadius: BorderRadius.circular(20),
           gradient: const LinearGradient(
             colors: [Color(0xFF4C4EA1), Color(0xFFFACD16), Color(0xFFEF3E5F)],
             begin: Alignment.topLeft,
             end: Alignment.bottomRight,
           ),
         ),
         padding: const EdgeInsets.all(3), // Border width
         child: Container(
           decoration: BoxDecoration(
             color: Colors.white,
             borderRadius: BorderRadius.circular(18),
           ),
           padding: const EdgeInsets.all(16),
           child: Row(
             children: [
               Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(
                       widget.subject.subjectName,
                       style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                     ),
                     const SizedBox(height: 8),
                     Text(
                       widget.subject.subjectCode,
                       style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                     ),
                     const SizedBox(height: 8),
                      Text(
                       widget.subject.subjectLecturer,
                       style: const TextStyle(fontSize: 14, color: Colors.black87),
                     ),
                   ],
                 ),
               ),
               // Placeholder for "Math doodle" image
               const Opacity(
                 opacity: 0.5,
                 child: Icon(Icons.calculate_outlined, size: 60, color: Colors.grey),
               ),
             ],
           ),
         ),
      ),
    );
  }

  Widget _buildQuizCard(Map<String, dynamic> quiz) {
    return Container(
      width: 160,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
         boxShadow: [
           BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset:const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(quiz['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Text('Difficulty: ${quiz['difficulty']}', style: const TextStyle(fontSize: 10, color: Colors.black54)),
          Text('${quiz['questions']} Questions', style: const TextStyle(fontSize: 10, color: Colors.black54)),
          const Spacer(),
          Row(
            children: [
              // Circular progress
              SizedBox(
                width: 40,
                height: 40,
                child: Stack(
                  children: [
                    CircularProgressIndicator(
                      value: quiz['progress'],
                      backgroundColor: Colors.purple.withOpacity(0.1),
                      color: const Color(0xFF7E57C2), // Purple
                    ),
                    Center(child: Text('${(quiz['progress']*100).toInt()}%', style: const TextStyle(fontSize: 9))),
                  ],
                ),
              ),
              const Spacer(),
              // Arrow or button? Button says "Take Quiz"
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 28,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4C4EA1),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Take Quiz', style: TextStyle(fontSize: 10, color: Colors.white)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAskLuminaBanner() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4C4EA1), width: 2), // Blue border
         boxShadow: [
           BoxShadow(color: const Color(0xFF4C4EA1).withOpacity(0.3), blurRadius: 4, offset:const Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
           const Icon(Icons.auto_awesome, color: Colors.amber, size: 24),
           const SizedBox(width: 8),
           RichText(
             text: const TextSpan(
               children: [
                 TextSpan(text: 'ASK ', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                 TextSpan(text: 'LUMINA', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w400, letterSpacing: 1.5)),
               ],
             ),
           ),
        ],
      ),
    );
  }

  Widget _buildFileItem(SubjectFile file) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.picture_as_pdf, size: 30, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(file.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text(_formatBytes(file.sizeBytes), style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () {}, // Flash cards placeholder
            style: OutlinedButton.styleFrom(
               side: const BorderSide(color: Color(0xFF4C4EA1)),
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
               minimumSize: const Size(0, 28),
            ),
            child: const Text('Flash Cards', style: TextStyle(fontSize: 10, color: Color(0xFF4C4EA1), fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          
          // Delete option
          GestureDetector(
            onTap: () {
              // Confirm delete
              showDialog(
                context: context, 
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete File?'),
                  content: Text('Are you sure you want to delete ${file.name}?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () async {
                         Navigator.pop(ctx);
                         await fileRepo.deleteFile(
                           uid: uid!,
                           subjectId: widget.subject.id,
                           fileId: file.id,
                           filename: file.name,
                         );
                      }, 
                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
            child: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
          ),
        ],
      ),
    );
  }
}
