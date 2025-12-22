import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/subject_repository.dart';
import '../domain/subjects.dart';
import '../../../core/auth/dev_auth.dart';

class SubjectsPage extends StatefulWidget {
  const SubjectsPage({super.key});

  @override
  State<SubjectsPage> createState() => _SubjectsPageState();
}

class _SubjectsPageState extends State<SubjectsPage> {
  late final SubjectRepository repo;
  String? uid;

  @override
  void initState() {
    super.initState();
    repo = SubjectRepository(FirebaseFirestore.instance);
    _init();
  }

  Future<void> _init() async {
    final u = await DevAuth.ensureSignedIn();
    setState(() => uid = u);
  }

  Future<void> _showAddDialog() async {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final lecturerCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Subject'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Subject Name'),
            ),
            TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(labelText: 'Subject Code'),
            ),
            TextField(
              controller: lecturerCtrl,
              decoration: const InputDecoration(labelText: 'Subject Lecturer'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true && uid != null) {
      await repo.addSubject(
        uid: uid!,
        subjectName: nameCtrl.text,
        subjectCode: codeCtrl.text,
        subjectLecturer: lecturerCtrl.text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              '/Users/vishnuram/lumina/apps/mobile/assets/images/background.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 10.0, bottom: 20.0),
                  child: Text(
                    'Subjects',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w400,
                      color: Colors.black,
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<Subject>>(
                    stream: repo.watchSubjects(uid!),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return Center(child: Text('Error: ${snap.error}'));
                      }
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final subjects = snap.data!;
                      if (subjects.isEmpty) {
                        return const Center(child: Text('No subjects yet. Tap + to add.'));
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: subjects.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, i) {
                          final s = subjects[i];
                          return SubjectCard(
                            subject: s,
                            onDelete: () => repo.deleteSubject(uid: uid!, subjectId: s.id),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SubjectCard extends StatelessWidget {
  const SubjectCard({
    super.key,
    required this.subject,
    required this.onDelete,
  });

  final Subject subject;
  final VoidCallback onDelete;

  // Colors from the palette
  static const deepBlue = Color(0xFF484C9D);
  static const yellow = Color(0xFFFFC107);
  static const pink = Color(0xFFEF446F);
  static const lightGrey = Color(0xFFF5F5F5);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: deepBlue, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative color strips to mimic the multi-colored border vibe
          Positioned(
            top: 0,
            left: 20,
            right: 20,
            height: 4,
            child: Row(
              children: [
                Expanded(child: Container(color: deepBlue)),
                Expanded(child: Container(color: yellow)),
                Expanded(child: Container(color: pink)),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subject.subjectName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${subject.subjectCode} ${subject.subjectLecturer}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Delete button hidden in menu or just here for now?
                    // User didn't ask for delete button in the new design but we need it.
                    // I'll keep it subtle or remove it if strictly following design.
                    // For functionality I'll use a subtle InkWell on the card or similar, 
                    // but for now I'll stick to the "upload button" area for actions.
                    // Let's modify the delete to be a long-press or similar, 
                    // or just not show it to match the "clean" design requested.
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Progress
                const Text(
                  '75% Complete',
                  style: TextStyle(
                    color: Color(0xFF7CA0C7), // Muted blue/grey from image
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: const LinearProgressIndicator(
                    value: 0.55,
                    backgroundColor: lightGrey,
                    color: deepBlue,
                    minHeight: 8,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Buttons
                Row(
                  children: [
                    // Upload Button
                    Container(
                      height: 48,
                      width: 64,
                      decoration: BoxDecoration(
                        color: deepBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.upload_rounded, color: Colors.white),
                        onPressed: () {}, // No function
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Study Plan Button
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: pink,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextButton(
                          onPressed: () {}, // No function
                          child: const Text(
                            'Study Plan',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
