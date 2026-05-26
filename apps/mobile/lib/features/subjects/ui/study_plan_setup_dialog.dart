import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../calendar/data/event_repository.dart';
import '../../calendar/data/task_repository.dart';
import '../../calendar/domain/task.dart';
import '../../../core/auth/dev_auth.dart';
import '../domain/subjects.dart';

class StudyPlanSetupDialog extends StatefulWidget {
  final List<dynamic> initialEvents;
  final Subject subject;
  final List<String> fileNames;

  const StudyPlanSetupDialog({
    super.key,
    required this.initialEvents,
    required this.subject,
    required this.fileNames,
  });

  @override
  State<StudyPlanSetupDialog> createState() => _StudyPlanSetupDialogState();
}

class AssessmentItem {
  String type;
  DateTime date;
  List<String> chapters;
  String title;

  AssessmentItem({
    required this.type,
    required this.date,
    required this.chapters,
    required this.title,
  });
}

class _StudyPlanSetupDialogState extends State<StudyPlanSetupDialog> {
  List<AssessmentItem> assessments = [];
  bool isSaving = false;
  bool _generateTasks = true;

  final List<String> types = [
    'Class',
    'Quiz',
    'Exam',
    'Assignment',
    'Project',
    'Midterm',
    'Final',
  ];
  late final List<String> chapters;

  @override
  void initState() {
    super.initState();
    chapters = widget.fileNames.isEmpty
        ? ['No Files Available']
        : widget.fileNames.toSet().toList();

    // Parse backend initial events
    for (var ev in widget.initialEvents) {
      try {
        final dStr = ev['date'] as String;
        DateTime d;
        if (dStr.contains('T')) {
          d = DateTime.tryParse(dStr) ?? DateTime.now().add(const Duration(days: 7));
        } else {
          final temp = DateTime.tryParse(dStr) ?? DateTime.now().add(const Duration(days: 7));
          d = DateTime(temp.year, temp.month, temp.day, 9, 0); // Default 9 AM if no time provided
        }

        String t = 'Quiz';
        final evType = (ev['type'] as String?)?.toLowerCase() ?? '';
        final evTitle = (ev['title'] as String?)?.toLowerCase() ?? '';
        
        if (evType.contains('class') || evTitle.contains('class') || evTitle.contains('lecture') || evTitle.contains('lab')) t = 'Class';
        if (evType.contains('assignment') || evTitle.contains('assignment')) t = 'Assignment';
        if (evType.contains('project') || evTitle.contains('project')) t = 'Project';
        if (evType.contains('exam') || evTitle.contains('exam')) t = 'Exam';
        if (evType.contains('midterm') || evTitle.contains('midterm') || evTitle.contains('test')) t = 'Midterm';
        if (evType.contains('final') || evTitle.contains('final')) t = 'Final';
        if (evType.contains('quiz') || evTitle.contains('quiz')) t = 'Quiz';

        assessments.add(
          AssessmentItem(
            type: t,
            date: d,
            title: ev['title'] as String? ?? t,
            chapters: (t == 'Assignment' || t == 'Project')
                ? []
                : [
                    chapters.isNotEmpty ? chapters.first : 'No Files Available',
                  ],
          ),
        );
      } catch (e) {
        print('Error parsing event: $e');
      }
    }

    if (assessments.isEmpty) {
      assessments.add(
        AssessmentItem(
          type: 'Quiz',
          date: DateTime.now().add(const Duration(days: 7)),
          title: 'Quiz',
          chapters: chapters.isEmpty ? [] : [chapters.first],
        ),
      );
    }
  }

  Future<void> _selectDateTime(AssessmentItem item) async {
    final firstD = DateTime.now().subtract(const Duration(days: 365 * 5));
    final lastD = DateTime.now().add(const Duration(days: 365 * 5));
    
    DateTime initDate = item.date;
    if (initDate.isBefore(firstD)) initDate = firstD;
    if (initDate.isAfter(lastD)) initDate = lastD;

    final d = await showDatePicker(
      context: context,
      initialDate: initDate,
      firstDate: firstD,
      lastDate: lastD,
    );
    if (d == null) return;

    if (mounted) {
      final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(item.date),
      );
      if (t == null) return;

      setState(() {
        item.date = DateTime(d.year, d.month, d.day, t.hour, t.minute);
      });
    }
  }

  Future<void> _selectChapters(AssessmentItem item) async {
    if (item.type == 'Assignment' || item.type == 'Project') return;

    final selected = await showDialog<List<String>>(
      context: context,
      builder: (context) {
        final localSelected = List<String>.from(item.chapters);
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Select Chapters'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: chapters
                      .map(
                        (c) => CheckboxListTile(
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(c, style: const TextStyle(fontSize: 14)),
                          value: localSelected.contains(c),
                          onChanged: (val) {
                            setState(() {
                              if (val == true)
                                localSelected.add(c);
                              else
                                localSelected.remove(c);
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, localSelected),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selected != null) {
      if (mounted) {
        setState(() => item.chapters = selected);
      }
    }
  }

  Future<void> _generatePlan() async {
    setState(() => isSaving = true);
    try {
      final uid = await DevAuth.ensureSignedIn();
      if (uid == null) throw Exception('Not signed in');

      final db = FirebaseFirestore.instance;
      final eventRepo = EventRepository(db);
      final taskRepo = TaskRepository(db);

      await eventRepo.deleteEventsBySubjectId(uid, widget.subject.id);
      await taskRepo.deleteTasksBySubjectId(uid, widget.subject.id);

      for (var item in assessments) {
        if (item.type == 'Class') {
          // Generate 14 weeks of recurrent classes starting from the selected date
          for (int i = 0; i < 14; i++) {
            await eventRepo.addEvent(
              uid: uid,
              title: item.title,
              startTime: item.date.add(Duration(days: i * 7)),
              endTime: item.date.add(Duration(days: i * 7, hours: 2)),
              location: (item.chapters.isEmpty || item.chapters.first == 'No Files Available')
                  ? 'Lecture'
                  : 'Lecture on ${item.chapters.join(", ")}',
              subjectId: widget.subject.id,
              isRecurring: true,
              colorHex: widget.subject.colorHex,
            );
          }
        } else {
          // 1. Create Event for Assessment
          await eventRepo.addEvent(
            uid: uid,
            title: item.title,
            startTime: item.date,
            endTime: item.date.add(const Duration(hours: 1)),
            location: (item.chapters.isEmpty || item.chapters.first == 'No Files Available')
                ? 'Assessment'
                : 'Assessment on ${item.chapters.join(", ")}',
            subjectId: widget.subject.id,
            isRecurring: false,
            colorHex: widget.subject.colorHex,
          );
        }

        // 2. Create Tasks for studying
        if (_generateTasks) {
          if (item.type != 'Assignment' && item.type != 'Project') {
            int daysOffset = 2;
            
            if (item.chapters.isEmpty || item.chapters.first == 'No Files Available') {
              await taskRepo.addTask(
                uid: uid,
                title: 'Prepare for ${item.title}',
                dueDate: item.date.subtract(Duration(days: daysOffset)),
                subjectId: widget.subject.id,
                description: 'Upcoming ${item.type}',
                priority: TaskPriority.high,
                status: TaskStatus.todo,
              );
            } else {
              for (int i = item.chapters.length - 1; i >= 0; i--) {
                var chap = item.chapters[i];
                await taskRepo.addTask(
                  uid: uid,
                  title: 'Study $chap',
                  dueDate: item.date.subtract(Duration(days: daysOffset)),
                  subjectId: widget.subject.id,
                  description: 'Prepare for ${item.title}',
                  priority: TaskPriority.high,
                  status: TaskStatus.todo,
                );
                daysOffset += 3;
              }
            }
          } else {
            // It IS an Assignment or Project! Let's generate 3 milestones.
            List<String> milestones = ['Drafting & Research', 'Core Work / Writing', 'Final Review & Polish'];
            int daysOffset = 2;
            for (int i = milestones.length - 1; i >= 0; i--) {
              final taskDueDate = item.date.subtract(Duration(days: daysOffset));
              await taskRepo.addTask(
                uid: uid,
                title: '${milestones[i]} for ${item.type}',
                description: 'Milestone for upcoming ${item.type}',
                dueDate: taskDueDate,
                priority: i == 2 ? TaskPriority.high : TaskPriority.medium, // Review is High Priority
                status: TaskStatus.todo,
                subjectId: widget.subject.id,
              );
              daysOffset += 3; // Space out over 3 days each
            }
          }
        }
      }

      if (mounted) {
        Navigator.pop(context, true); // Success
      }
    } catch (e) {
      print('Error generating plan: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 24,
        bottom:
            MediaQuery.of(context).viewInsets.bottom +
            24, // adjust for keyboard
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: Text(
                'Setup Study Plan',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            ...assessments.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    // Type Dropdown
                    Expanded(
                      flex: 3,
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: item.type,
                            items: types
                                .map(
                                  (t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(
                                      t,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              setState(() {
                                item.type = v!;
                                if (v == 'Assignment' || v == 'Project') {
                                  item.chapters.clear();
                                }
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Date Picker
                    Expanded(
                      flex: 4,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _selectDateTime(item),
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            DateFormat('h a, MMM d, yyyy').format(item.date),
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Chapter Selection
                    Expanded(
                      flex: 3,
                      child:
                          (item.type == 'Assignment' || item.type == 'Project')
                          ? Container(
                              height: 48,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'N/A',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          : GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _selectChapters(item),
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Text(
                                  item.chapters.isEmpty
                                      ? 'Select...'
                                      : '${item.chapters.length} selected',
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                    ),
                    // Remove
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => setState(() => assessments.remove(item)),
                    ),
                  ],
                ),
              ),
            ),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Generate chapter-by-chapter preparation tasks',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              value: _generateTasks,
              onChanged: (val) => setState(() => _generateTasks = val),
              activeColor: const Color(0xFF4C4EA1),
            ),
            const SizedBox(height: 8),

            // Add Another button
            Container(
              height: 48,
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    assessments.add(
                      AssessmentItem(
                        type: 'Quiz',
                        date: DateTime.now().add(const Duration(days: 7)),
                        title: 'Quiz',
                        chapters: chapters.isEmpty ? [] : [chapters.first],
                      ),
                    );
                  });
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF4C4EA1)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  '+ Add Another Assesment',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Generate button (simulated gradient border via container)
            Container(
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFEF3E5F),
                    Color(0xFFFACD16),
                    Color(0xFF4C4EA1),
                  ],
                ),
              ),
              padding: const EdgeInsets.all(2),
              child: ElevatedButton(
                onPressed: isSaving ? null : _generatePlan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/sparkles.png',
                            width: 20,
                            height: 20,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Generate Study Plan',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
