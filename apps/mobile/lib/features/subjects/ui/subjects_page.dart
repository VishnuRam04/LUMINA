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
      appBar: AppBar(title: const Text('Subjects')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Subject>>(
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
            itemCount: subjects.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final s = subjects[i];
              return ListTile(
                title: Text(s.subjectName),
                subtitle: Text('${s.subjectCode} • ${s.subjectLecturer}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => repo.deleteSubject(uid: uid!, subjectId: s.id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
