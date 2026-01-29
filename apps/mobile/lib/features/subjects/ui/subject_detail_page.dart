import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/auth/dev_auth.dart';
import '../data/file_repository.dart';
import '../domain/subject_file.dart';
import '../domain/subjects.dart';
import '../../../../core/api/api_client.dart';
import '../../chat/ui/chat_page.dart';
import '../../flashcards/ui/flashcard_deck_page.dart';
import '../../quiz/data/quiz_repository.dart';
import '../../quiz/domain/quiz_model.dart';
import '../../quiz/ui/quiz_page.dart';
import '../../quiz/ui/quiz_creation_dialog.dart';

class SubjectDetailPage extends StatefulWidget {
  final Subject subject;

  const SubjectDetailPage({super.key, required this.subject});

  @override
  State<SubjectDetailPage> createState() => _SubjectDetailPageState();
}

class _SubjectDetailPageState extends State<SubjectDetailPage> {

  late final FileRepository fileRepo;
  late final QuizRepository quizRepo;
  late Future<List<Quiz>> _quizzesFuture;
  String? uid;
  bool isUploading = false;


  @override
  void initState() {
    super.initState();
    fileRepo = FileRepository(FirebaseFirestore.instance, FirebaseStorage.instance);
    quizRepo = QuizRepository();
    _quizzesFuture = quizRepo.fetchQuizzes(widget.subject.id);
    _init(); // missing in original snippet but presumed context
  }
  
  void _refreshQuizzes() {
    setState(() {
      _quizzesFuture = quizRepo.fetchQuizzes(widget.subject.id);
    });
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
        
        // TRIGGER INGESTION
        try {
           final storagePath = 'users/$uid/subjects/${widget.subject.id}/files/$filename'; 
           // Note: We need the PRECISE storage path we used in FileRepo.
           // In FileRepo we sanitized the filename. Ideally FileRepo returns the path.
           // For now, let's assume standard sanitation or rely on backend to handle standard filename?
           // Actually, let's stick to the path we know.
           
           // Better: Update FileRepo to return the storage path or url.
           // But let's just construct it here for MVP since we know the logic.
           // Sanitize logic was: filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
           final safeName = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
           final fullPath = 'users/$uid/subjects/${widget.subject.id}/files/$safeName';
           
           await ApiClient().ingestFile(
             filePath: fullPath, 
             subjectId: widget.subject.id, 
             filename: filename
           );
           print('Ingestion triggered for $fullPath');
        } catch (apiErr) {
           print('Ingestion failed: $apiErr');
           // Don't block UI success for this, just log it.
        }

        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('File uploaded and processing started...')),
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
            bottom: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16, 
                right: 16, 
                top: 8, 
                bottom: 40 + MediaQuery.of(context).padding.bottom
              ),
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
                  // Generated Quiz Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Generated Quiz',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        onPressed: () async {
                          if (uid == null) return;
                          // Fetch files first
                          final files = await fileRepo.getFiles(uid!, widget.subject.id);
                          if (mounted) {
                            await showDialog(
                              context: context, 
                              builder: (_) => QuizCreationDialog(subjectId: widget.subject.id, files: files)
                            );
                            _refreshQuizzes();
                          }
                        }, 
                        icon: const Icon(Icons.add_circle, color: Color(0xFF4C4EA1))
                      )
                    ],
                  ),

                  const SizedBox(height: 12),


                  SizedBox(
                    height: 180,
                    child: FutureBuilder<List<Quiz>>(
                      future: _quizzesFuture,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                           print("Quiz Fetch Error: ${snapshot.error}"); 
                           return Center(child: Text("Error loading quizzes. Check console.", style: TextStyle(color: Colors.red, fontSize: 10)));
                        }
                        if (snapshot.connectionState == ConnectionState.waiting) {
                           return const Center(child: CircularProgressIndicator());
                        }
                        
                        final quizzes = snapshot.data ?? [];
                        
                        if (quizzes.isEmpty) {
                          // Show Suggestions (Keep existing logic)
                          return FutureBuilder<List<SubjectFile>>(
                            future: fileRepo.getFiles(uid!, widget.subject.id),
                            builder: (context, fileSnap) {
                              if (!fileSnap.hasData) return const Center(child: CircularProgressIndicator());
                              final files = fileSnap.data!;
                              if (files.isEmpty) return const Center(child: Text("Upload files to get quiz suggestions!", style: TextStyle(color: Colors.grey)));

                              // Group files into chunks of 3
                              List<List<SubjectFile>> chunks = [];
                              for (var i = 0; i < files.length; i += 3) {
                                chunks.add(files.sublist(i, i + 3 > files.length ? files.length : i + 3));
                              }

                              return ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: chunks.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 12),
                                itemBuilder: (context, index) {
                                  final chunk = chunks[index];
                                  final title = (chunk.length == files.length) 
                                      ? "Full Subject Quiz" 
                                      : "Chapters ${index * 3 + 1} - ${index * 3 + chunk.length}";
                                      
                                  // Suggestion Card
                                  return Container(
                                    width: 200,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF7E57C2), // Purple like screenshot
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [BoxShadow(color: const Color(0xFF7E57C2).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                                    ),
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                        const SizedBox(height: 4),
                                        Text("${chunk.length} Chapters", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                        const Spacer(),
                                        // Illustration placeholder (simple icon for now)
                                        const Align(alignment: Alignment.centerRight, child: Icon(Icons.school, color: Colors.white24, size: 40)),
                                        const Spacer(),
                                        ElevatedButton(
                                          onPressed: () async {
                                            // Trigger Generation
                                            // Reuse existing dialog logic or direct? Direct is better for "Let's Go" feel.
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Generating Quiz...")));
                                            try {
                                              // Direct generate
                                              final quiz = await quizRepo.generateQuiz(
                                                widget.subject.id, 
                                                chunk.map((f) => f.name).toList(), // Use safe list
                                                count: 10,
                                                difficulty: "Medium"
                                              );
                                              if (context.mounted) {
                                                await Navigator.push(context, MaterialPageRoute(builder: (_) => QuizPage(quiz: quiz)));
                                                _refreshQuizzes();
                                              }
                                            } catch (e) {
                                              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFFFD54F), // Yellow button
                                            foregroundColor: Colors.black,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          child: const Text("Let's go!", style: TextStyle(fontWeight: FontWeight.bold)),
                                        )
                                      ],
                                    ),
                                  );
                                },
                              );
                            }
                          );
                        }
                        
                        return ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: quizzes.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            return _buildQuizCard(quizzes[index]);
                          },
                        );
                      }
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

  Widget _buildQuizCard(Quiz quiz) {
    // Mock progress for now or store it? storing progress requires QuizAttempt model.
    // Allow retaking for now.
    double progress = 0.0; 

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
          Text(quiz.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          const Text('Difficulty: Medium', style: TextStyle(fontSize: 10, color: Colors.black54)), // Difficulty not stored in Quiz model yet? It was in Request. Add if needed.
          Text('${quiz.questions.length} Questions', style: const TextStyle(fontSize: 10, color: Colors.black54)),
          const Spacer(),
          // Button
          SizedBox(
            width: double.infinity,
            height: 28,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => QuizPage(quiz: quiz)));
              },
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
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatPage()));
        },
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
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FlashcardDeckPage(
                    subjectId: widget.subject.id,
                    subjectName: widget.subject.subjectName,
                    fileId: file.name,
                    chapterName: file.name,
                  ),
                ),
              );
            },
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
                         
                         // Trigger Backend Deletion
                         try {
                           await ApiClient().deleteFile(file.name);
                           print('Backend deletion triggered for ${file.name}');
                         } catch (e) {
                           print('Backend deletion failed: $e');
                         }
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
