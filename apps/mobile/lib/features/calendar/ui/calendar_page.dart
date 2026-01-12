import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../subjects/data/subject_repository.dart';
import '../../subjects/domain/subjects.dart';
import '../../../core/auth/dev_auth.dart';
import '../data/task_repository.dart';
import '../domain/task.dart';
import '../domain/event.dart';
import '../data/event_repository.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}



class _CalendarPageState extends State<CalendarPage> {
  late final TaskRepository taskRepo;
  late final SubjectRepository subjectRepo;
  late final EventRepository eventRepo;

  String? uid;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    taskRepo = TaskRepository(FirebaseFirestore.instance);
    subjectRepo = SubjectRepository(FirebaseFirestore.instance);
    eventRepo = EventRepository(FirebaseFirestore.instance);
    _selectedDay = _focusedDay;
    _init();
  }

  Future<void> _init() async {
    final u = await DevAuth.ensureSignedIn();
    setState(() => uid = u);
  }

  Future<void> _openTaskDialog({TaskItem? existing}) async {
    if (uid == null) return;
    final subjects = await subjectRepo.getSubjects(uid!);
    _showTaskDialog(existing: existing, subjects: subjects);
  }

  Future<void> _openEventDialog() async {
     if (uid == null) return;
    final subjects = await subjectRepo.getSubjects(uid!);
    _showEventDialog(subjects: subjects);
  }

  Future<void> _showEventDialog({required List<Subject> subjects}) async {
    final titleCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    
    DateTime startTime = DateTime.now().add(const Duration(hours: 1));
    DateTime endTime = startTime.add(const Duration(hours: 1));
    String? subjectId;
    bool isRecurring = false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) {
          
          Future<void> pickDateTime(bool isStart) async {
            final initial = isStart ? startTime : endTime;
            final date = await showDatePicker(
              context: context,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
              initialDate: initial,
            );
            if (date == null) return;
            
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(initial),
            );
            if (time == null) return;

            final result = DateTime(date.year, date.month, date.day, time.hour, time.minute);
            
            setLocal(() {
              if (isStart) {
                startTime = result;
                if (endTime.isBefore(startTime)) {
                  endTime = startTime.add(const Duration(hours: 1));
                }
              } else {
                endTime = result;
              }
            });
          }

          return AlertDialog(
            title: const Text('Add Event'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
                  const SizedBox(height: 12),
                  
                  // Start Time
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Start Time'),
                    subtitle: Text(DateFormat('yyyy-MM-dd hh:mm a').format(startTime)),
                    trailing: const Icon(Icons.access_time),
                    onTap: () => pickDateTime(true),
                  ),
                  
                  // End Time
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('End Time'),
                    subtitle: Text(DateFormat('yyyy-MM-dd hh:mm a').format(endTime)),
                    trailing: const Icon(Icons.access_time),
                    onTap: () => pickDateTime(false),
                  ),

                  TextField(controller: locationCtrl, decoration: const InputDecoration(labelText: 'Location')),
                  const SizedBox(height: 12),
                  
                  DropdownButtonFormField<String?>(
                    value: subjectId,
                    decoration: const InputDecoration(labelText: 'Subject'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('None')),
                      ...subjects.map((s) => DropdownMenuItem(value: s.id, child: Text('${s.subjectName} (${s.subjectCode})'))),
                    ],
                    onChanged: (v) => setLocal(() => subjectId = v),
                  ),
                  
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Recurring Event'),
                    value: isRecurring,
                    onChanged: (v) => setLocal(() => isRecurring = v),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
            ],
          );
        },
      ),
    );

    if (saved == true && uid != null) {
      if (titleCtrl.text.trim().isEmpty) return;
      try {
        await eventRepo.addEvent(
          uid: uid!,
          title: titleCtrl.text,
          location: locationCtrl.text,
          startTime: startTime,
          endTime: endTime,
          subjectId: subjectId,
          isRecurring: isRecurring,
        );
      } catch (e) {
        if (e is FirebaseException && e.code == 'permission-denied') {
          _showPermissionErrorDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
  
  void _showPermissionErrorDialog() {
    showDialog(
      context: context, 
      builder: (_) => AlertDialog(
        title: const Text('Permission Denied'),
        content: const Text('Please update your Firestore Security Rules to allow access to the "events" collection.\n\nAdd this to your rules:\nmatch /events/{eventId} {\n  allow read, write: if request.auth != null && request.auth.uid == userId;\n}'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  Future<void> _showTaskDialog({TaskItem? existing, required List<Subject> subjects}) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    DateTime? dueDate = existing?.dueDate ?? _selectedDay; // Default to selected day
    TaskPriority priority = existing?.priority ?? TaskPriority.medium;
    TaskStatus status = existing?.status ?? TaskStatus.todo;
    String? subjectId = existing?.subjectId;

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Add Task' : 'Edit Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 8),
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  value: subjectId,
                  decoration: const InputDecoration(labelText: 'Subject'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    ...subjects.map((s) => DropdownMenuItem(value: s.id, child: Text('${s.subjectName} (${s.subjectCode})'))),
                  ],
                  onChanged: (v) => setLocal(() => subjectId = v),
                ),
                const SizedBox(height: 12),
                // Priority
                DropdownButtonFormField<TaskPriority>(
                  value: priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: const [
                    DropdownMenuItem(value: TaskPriority.high, child: Text('High')),
                    DropdownMenuItem(value: TaskPriority.medium, child: Text('Medium')),
                    DropdownMenuItem(value: TaskPriority.low, child: Text('Low')),
                  ],
                  onChanged: (v) => setLocal(() => priority = v ?? TaskPriority.medium),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
          ],
        ),
      ),
    );

    if (saved == true && uid != null) {
      if (titleCtrl.text.trim().isEmpty) return;
      if (existing == null) {
        await taskRepo.addTask(
          uid: uid!, title: titleCtrl.text, description: descCtrl.text,
          dueDate: dueDate, priority: priority, status: status, subjectId: subjectId,
        );
      } else {
        await taskRepo.updateTask(
          uid: uid!, taskId: existing.id, title: titleCtrl.text, description: descCtrl.text,
          dueDate: dueDate, priority: priority, status: status, subjectId: subjectId,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (uid == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return StreamBuilder<List<TaskItem>>(
      stream: taskRepo.watchTasks(uid!),
      builder: (context, taskSnap) {
        return StreamBuilder<List<CalendarEvent>>(
          stream: eventRepo.watchEvents(uid!),
          builder: (context, eventSnap) {
            final tasks = taskSnap.data ?? [];
            final events = eventSnap.data ?? [];

            // Helper to get items for a specific day
            List<dynamic> getItemsForDay(DateTime day) {
              final dayTasks = tasks.where((t) => t.dueDate != null && isSameDay(t.dueDate, day)).toList();
              final dayEvents = events.where((e) => isSameDay(e.startTime, day)).toList();
              return [...dayTasks, ...dayEvents];
            }

            final selectedItems = getItemsForDay(_selectedDay ?? _focusedDay);
            // Sort by time?
            // selectedItems.sort(...)

            return Scaffold(
              backgroundColor: Colors.white,
              appBar: AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                centerTitle: true,
                title: const Text('Calendar', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                iconTheme: const IconThemeData(color: Colors.black),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.filter_list),
                    onPressed: () {}, 
                  ),
                ],
              ),
              body: Column(
                children: [
                  // Calendar Grid
                  TableCalendar(
                    firstDay: DateTime.utc(2024, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    currentDay: DateTime.now(),
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    eventLoader: getItemsForDay,
                    calendarFormat: CalendarFormat.month,
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    calendarStyle: CalendarStyle(
                      selectedDecoration: BoxDecoration(
                        color: const Color(0xFF4C4EA1).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      selectedTextStyle: const TextStyle(
                        color: Color(0xFF4C4EA1),
                        fontWeight: FontWeight.bold,
                      ),
                      todayDecoration: BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF4C4EA1).withOpacity(0.5)),
                      ),
                      todayTextStyle: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                      // We will use markerBuilder instead of simple decoration to handle multi-color dots
                    ),
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, day, events) {
                        if (events.isEmpty) return const SizedBox();
                        
                        final hasTask = events.any((e) => e is TaskItem);
                        final hasEvent = events.any((e) => e is CalendarEvent);
                        
                        final dots = <Widget>[];
                        
                        // Order: Event (Blue) then Task (Red)
                        if (hasEvent) {
                          dots.add(Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            width: 6, 
                            height: 6,
                            decoration: const BoxDecoration(color: Color(0xFF4C4EA1), shape: BoxShape.circle),
                          ));
                        }
                        if (hasTask) {
                         dots.add(Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            width: 6, 
                            height: 6,
                            decoration: const BoxDecoration(color: Color(0xFFEF3E5F), shape: BoxShape.circle),
                          ));
                        }

                        return Positioned(
                          bottom: 5,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: dots,
                          ),
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // "Ask Lumina" Placeholder
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                         Image.asset(
                            'assets/images/sparkles.png',
                            width: 24,
                            height: 24,
                            errorBuilder: (c, e, s) => const Icon(Icons.auto_awesome, color: Colors.purple),
                          ),
                        const SizedBox(width: 8),
                        const Text(
                          'ASK LUMINA',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _openEventDialog(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4C4EA1),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Add Event', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _openTaskDialog(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF3E5F),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Add Task', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // items List
                  Expanded(
                    child: selectedItems.isEmpty
                      ? const Center(child: Text('No events or tasks for this day.'))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          itemCount: selectedItems.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final item = selectedItems[i];
                            if (item is TaskItem) {
                              return _buildTaskCard(item);
                            } else if (item is CalendarEvent) {
                              return _buildEventCard(item);
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEventCard(CalendarEvent e) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF4C4EA1), // Deep Blue for events
              borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4C4EA1).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.event, color: Color(0xFF4C4EA1)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${DateFormat('hh:mm a').format(e.startTime)} - ${DateFormat('hh:mm a').format(e.endTime)}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      if (e.location.isNotEmpty)
                         Text(
                          e.location,
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(TaskItem t) {
    return TaskCard(
      key: ValueKey(t.id),
      task: t,
      onComplete: () async {
        // User said "removed", usually meaning marked as done and potentially hidden.
        // We will update status to 'Done'. If the user wants to truly 'delete', we can change this.
        // For now, updating to Done preserves history.
        // If the view filters out 'Done', it will be "removed".
        // If not, we might want to actually delete.
        // Let's effectively "remove" it by deleting it for now to match the request exactly
        // OR better: Update to Done. The user can filter.
        // But "removed" implies standard behavior. I'll stick to updating to Done.
        await taskRepo.updateTask(
          uid: uid!,
          taskId: t.id,
          title: t.title,
          description: t.description,
          dueDate: t.dueDate,
          priority: t.priority,
          status: TaskStatus.done,
          subjectId: t.subjectId,
        );
      },
    );
  }
}

class TaskCard extends StatefulWidget {
  final TaskItem task;
  final VoidCallback onComplete;

  const TaskCard({
    super.key,
    required this.task,
    required this.onComplete,
  });

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _isCompleted = widget.task.status == TaskStatus.done;
  }

  @override
  void didUpdateWidget(TaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.status != widget.task.status) {
      _isCompleted = widget.task.status == TaskStatus.done;
    }
  }

  void _handleTap() {
    if (_isCompleted) return; // Already done

    setState(() => _isCompleted = true);

    // Wait for animation to finish before calling callback
    Future.delayed(const Duration(milliseconds: 600), () {
      widget.onComplete();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    final bool isHigh = t.priority == TaskPriority.high;
    // Standardize all tasks to Red as per request
    final Color barColor = const Color(0xFFEF3E5F);
    
    // If it was already done before loading, show final state immediately
    // If we just clicked it, _isCompleted is true.
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Color Bar
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Radio/Checkbox Circle
                GestureDetector(
                  onTap: _handleTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: barColor, width: 2),
                      color: _isCompleted ? barColor : Colors.transparent,
                    ),
                    child: _isCompleted
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title with Strikethrough Animation
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 300),
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 16,
                          color: _isCompleted ? Colors.grey : Colors.black,
                          decoration: _isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
                        ),
                        child: Text(t.title),
                      ),
                      const SizedBox(height: 4),
                      if (t.dueDate != null)
                        Text(
                          DateFormat('dd/MM hh:mm a').format(t.dueDate!),
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      if (t.description.isNotEmpty)
                         AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                            decoration: _isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
                          ),
                          child: Text(
                            t.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Priority Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isHigh ? 'High' : 'Low',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
