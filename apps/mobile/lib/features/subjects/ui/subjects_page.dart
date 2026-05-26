import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/api/api_client.dart';
import '../data/subject_repository.dart';
import '../data/file_repository.dart';
import '../domain/subjects.dart';
import '../../../core/auth/dev_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'subject_detail_page.dart';
import 'study_plan_setup_dialog.dart';
import '../../../core/notifications/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../calendar/domain/event.dart';
import '../../calendar/data/event_repository.dart';
import '../../calendar/data/task_repository.dart';

class SubjectsPage extends StatefulWidget {
  const SubjectsPage({super.key});

  @override
  State<SubjectsPage> createState() => _SubjectsPageState();
}

class _SubjectsPageState extends State<SubjectsPage> {
  late final SubjectRepository repo;
  late final FileRepository fileRepo;
  final ScrollController _scrollController = ScrollController();
  String? uid;

  final Map<String, bool> _uploadingStates = {};

  @override
  void initState() {
    super.initState();
    repo = SubjectRepository(FirebaseFirestore.instance);
    fileRepo = FileRepository(
      FirebaseFirestore.instance,
      FirebaseStorage.instance,
    );
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

  Future<void> _studyPlan(Subject subject) async {

    await _pickAndUploadFile(subject);
  }

  Future<void> _pickAndUploadFile(Subject subject) async {
    if (uid == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: kIsWeb,
    );

    if (result != null) {
      final filename = result.files.single.name;
      
      final allFiles = await fileRepo.getAllUserFiles(uid!);
      if (allFiles.contains(filename)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('File "$filename" already exists in your workspace!')),
          );
        }
        return;
      }
      
      setState(() => _uploadingStates[subject.id] = true);
      try {
        await fileRepo.uploadFile(
          uid: uid!,
          subjectId: subject.id,
          file: kIsWeb ? null : File(result.files.single.path!),
          bytes: kIsWeb ? result.files.single.bytes : null,
          filename: filename,
          saveMetadata:
              false, 
        );

        
        try {
          final safeName = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
          final fullPath = 'users/$uid/subjects/${subject.id}/files/$safeName';

          final planData = await ApiClient().studyPlan(
            filePath: fullPath,
            subjectId: subject.id,
            filename: filename,
            section: subject.section,
          );
          print('Study plan generated for $fullPath');

          NotificationService().showInstantNotification(
            title: 'File Processed',
            body: '$filename has been analyzed and your materials are ready!',
          );

          if (mounted) {
            final events = planData['events'] as List<dynamic>? ?? [];
            final files = await fileRepo.getFiles(uid!, subject.id);
            final fileNames = files.map((f) => f.name).toList();

            final result = await showModalBottomSheet<bool>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => StudyPlanSetupDialog(
                initialEvents: events,
                subject: subject,
                fileNames: fileNames,
              ),
            );
            
            if (result == true && mounted) {
                final bloomLevelsRaw = planData['bloom_levels'] as List<dynamic>? ?? [];
                final List<String> bloomLevels = bloomLevelsRaw.map((e) => e.toString()).toList();
                await repo.updateSubjectStudyPlanData(
                    uid: uid!,
                    subjectId: subject.id,
                    hasStudyPlan: true,
                    bloomLevels: bloomLevels,
                );
            }
          }
        } catch (apiErr) {
          print('Study plan generation failed: $apiErr');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Study Plan generation failed: $apiErr')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
        }
      } finally {
        if (mounted) {
          setState(() => _uploadingStates[subject.id] = false);
        }
      }
    }
  }

  Future<void> _showAddDialog() async {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final lecturerCtrl = TextEditingController();
    final sectionCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
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
                controller: sectionCtrl,
                decoration: const InputDecoration(labelText: 'Section (e.g. 1)'),
              ),
              TextField(
                controller: lecturerCtrl,
                decoration: const InputDecoration(labelText: 'Subject Lecturer'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == true && uid != null) {
      final defaultColors = [
        const Color(0xFF4C4EA1),
        const Color(0xFFEF3E5F),
        const Color(0xFFFACD16),
        Colors.green,
        Colors.teal,
      ];
      final colorStr = '#${defaultColors[nameCtrl.text.hashCode % defaultColors.length].value.toRadixString(16).substring(2).toUpperCase()}';
      
      await repo.addSubject(
        uid: uid!,
        subjectName: nameCtrl.text,
        subjectCode: codeCtrl.text,
        subjectLecturer: lecturerCtrl.text,
        colorHex: colorStr,
        section: sectionCtrl.text,
      );
    }
  }

  Future<void> _deleteSubjectWithFiles(Subject subject) async {
    if (uid == null) return;
    
    try {
      final files = await fileRepo.getFiles(uid!, subject.id);
      
      for (var file in files) {
        await fileRepo.deleteFile(
          uid: uid!,
          subjectId: subject.id,
          fileId: file.id,
          filename: file.name,
        );
        await ApiClient().deleteFile(file.name);
        print('Cascaded deletion for file: ${file.name}');
      }
      
      
      await EventRepository(FirebaseFirestore.instance).deleteEventsBySubjectId(uid!, subject.id);
      await TaskRepository(FirebaseFirestore.instance).deleteTasksBySubjectId(uid!, subject.id);

      await repo.deleteSubject(
        uid: uid!,
        subjectId: subject.id,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting subject contents: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Image.asset('assets/images/background.png', fit: BoxFit.cover),
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
                      padding: const EdgeInsets.only(top: 10.0, bottom: 20.0),
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
                        ],
                      ),
                    ),
                  ),
                  if (subjects.isEmpty)
                    const SliverFillRemaining(
                      child: Center(
                        child: Text('No subjects yet. Tap + to add.'),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 160),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, i) {
                          final s = subjects[i];
                          final isUploading = _uploadingStates[s.id] ?? false;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: SubjectCard(
                              subject: s,
                              onDelete: () => _deleteSubjectWithFiles(s),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        SubjectDetailPage(subject: s),
                                  ),
                                );
                              },
                              onStudyPlan: () => _studyPlan(s),
                              isUploading: isUploading,
                            ),
                          );
                        }, childCount: subjects.length),
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
    this.onStudyPlan,
    this.isUploading = false,
  });

  final Subject subject;
  final VoidCallback onDelete;
  final VoidCallback? onTap;
  final VoidCallback? onStudyPlan;
  final bool isUploading;

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
            message: Text(
              'Are you sure you want to delete ${subject.subjectName}?',
            ),
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
        padding: const EdgeInsets.all(5), 
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(21),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              
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

              StreamBuilder<List<CalendarEvent>>(
                stream: EventRepository(FirebaseFirestore.instance).watchEvents(FirebaseAuth.instance.currentUser!.uid),
                builder: (context, snap) {
                  if (!snap.hasData) return const SizedBox(height: 12);
                  final now = DateTime.now();
                  final upcoming = snap.data!.where((e) => e.subjectId == subject.id && e.startTime.isAfter(now)).toList();
                  if (upcoming.isEmpty) {
                     return const Padding(
                       padding: EdgeInsets.symmetric(vertical: 8),
                       child: Text('No upcoming events', style: TextStyle(color: Color(0xFF7CA0C7), fontSize: 13, fontWeight: FontWeight.w600)),
                     );
                  }
                  
                  upcoming.sort((a,b) => a.startTime.compareTo(b.startTime));
                  final nextEvent = upcoming.first;
                  final days = nextEvent.startTime.difference(now).inDays;
                  String dayStr = days == 0 ? 'Today' : 'in $days day${days == 1 ? '' : 's'}';
                  
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4C4EA1).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_available, size: 16, color: Color(0xFF4C4EA1)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                             '${nextEvent.title} - $dayStr', 
                             maxLines: 1, 
                             overflow: TextOverflow.ellipsis,
                             style: const TextStyle(color: Color(0xFF4C4EA1), fontSize: 13, fontWeight: FontWeight.w600)
                          ),
                        ),
                      ],
                    ),
                  );
                }
              ),

              const SizedBox(height: 24),

              Row(
                children: [

                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: pink,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextButton.icon(
                        onPressed: isUploading ? null : onStudyPlan,
                        icon: isUploading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.upload_file,
                                size: 18,
                                color: Colors.white,
                              ),
                        label: Text(
                          isUploading ? 'Generating...' : 'Generate Study Plan',
                          style: const TextStyle(
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
