import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/subject_repository.dart';
import '../domain/subjects.dart';
import '../../../core/auth/dev_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'subject_detail_page.dart';
class SubjectsPage extends StatefulWidget {
  const SubjectsPage({super.key});

  @override
  State<SubjectsPage> createState() => _SubjectsPageState();
}

class _SubjectsPageState extends State<SubjectsPage> {
  late final SubjectRepository repo;
  final ScrollController _scrollController = ScrollController();
  String? uid;

  @override
  void initState() {
    super.initState();
    repo = SubjectRepository(FirebaseFirestore.instance);
    _init();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/background.png',
            fit: BoxFit.cover,
          ),
        ),
        SafeArea(
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

              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 10.0, bottom: 20.0),
                      child: Column(
                        children: [
                          const Text(
                            'Subjects',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w400,
                              color: Colors.black,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Hello')),
                              );
                            },
                            child: const Text('Say Hello'),
                          )
                        ],
                      ),
                    ),
                  ),
                  if (subjects.isEmpty)
                    const SliverFillRemaining(
                      child: Center(child: Text('No subjects yet. Tap + to add.')),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 160),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final s = subjects[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: SubjectCard(
                                subject: s,
                                onDelete: () => repo.deleteSubject(uid: uid!, subjectId: s.id),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => SubjectDetailPage(subject: s)),
                                  );
                                },
                              ),
                            );
                          },
                          childCount: subjects.length,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        Positioned(
          bottom: 160,
          right: 20,
          child: FloatingActionButton(
            backgroundColor: SubjectCard.deepBlue,
            onPressed: _showAddDialog,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }
} 

class SubjectCard extends StatelessWidget {
  const SubjectCard({
    super.key,
    required this.subject,
    required this.onDelete,
    this.onTap,
  });

  final Subject subject;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  // Colors from the palette
  static const deepBlue = Color(0xFF4C4EA1);
  static const yellow = Color(0xFFFACD16);
  static const pink = Color(0xFFEF3E5F);
  static const lightBlue = Color(0xFFCCD6E3);



  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: () {
        HapticFeedback.mediumImpact();
        showCupertinoModalPopup<void>(
          context: context,
          builder: (BuildContext context) => CupertinoActionSheet(
            title: const Text('Delete Subject'),
            message: Text('Are you sure you want to delete ${subject.subjectName}?'),
            actions: <CupertinoActionSheetAction>[
              CupertinoActionSheetAction(
                isDestructiveAction: true,
                onPressed: () {
                  Navigator.pop(context);
                  onDelete();
                },
                child: const Text('Delete'),
              ),
            ],
            cancelButton: CupertinoActionSheetAction(
              isDefaultAction: true,
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const SweepGradient(
          colors: [
            deepBlue,
            yellow,
            pink,
            lightBlue,
            deepBlue,
            yellow,
            pink,
            lightBlue,
            deepBlue,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(5), // This creates the border thickness
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(21), // 16 - 3 to match nesting
        ),
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
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Progress
            const Text(
              '75% Complete',
              style: TextStyle(
                color: Color(0xFF7CA0C7),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: const LinearProgressIndicator(
                value: 0.55,
                backgroundColor: lightBlue,
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
      ),
    );
  }
}
