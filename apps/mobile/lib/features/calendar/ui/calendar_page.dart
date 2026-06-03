import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../subjects/data/subject_repository.dart';
import '../../subjects/domain/subjects.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/task_repository.dart';
import '../domain/task.dart';
import '../domain/event.dart';
import '../data/event_repository.dart';
import '../../../core/notifications/notification_service.dart';
import '../../chat/ui/chat_page.dart';
import 'task_card.dart';

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
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && mounted) {
      setState(() => uid = user.uid);
    }
  }

  Future<void> _openTaskDialog({TaskItem? existing}) async {
    if (uid == null) return;
    final subjects = await subjectRepo.getSubjects(uid!);
    _showTaskDialog(existing: existing, subjects: subjects);
  }

  Future<void> _openEventDialog({CalendarEvent? existing}) async {
    if (uid == null) return;
    final subjects = await subjectRepo.getSubjects(uid!);
    _showEventDialog(existing: existing, subjects: subjects);
  }

  Future<void> _showEventDialog({
    CalendarEvent? existing,
    required List<Subject> subjects,
  }) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final locationCtrl = TextEditingController(text: existing?.location ?? '');

    DateTime startTime =
        existing?.startTime ?? DateTime.now().add(const Duration(hours: 1));
    DateTime endTime =
        existing?.endTime ?? startTime.add(const Duration(hours: 1));
    String? subjectId = existing?.subjectId;
    bool isRecurring = existing?.isRecurring ?? false;
    int? reminderMinutes;

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

            final result = DateTime(
              date.year,
              date.month,
              date.day,
              time.hour,
              time.minute,
            );

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
            title: Text(existing == null ? 'Add Event' : 'Edit Event'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: 12),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Start Time'),
                    subtitle: Text(
                      DateFormat('yyyy-MM-dd hh:mm a').format(startTime),
                    ),
                    trailing: const Icon(Icons.access_time),
                    onTap: () => pickDateTime(true),
                  ),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('End Time'),
                    subtitle: Text(
                      DateFormat('yyyy-MM-dd hh:mm a').format(endTime),
                    ),
                    trailing: const Icon(Icons.access_time),
                    onTap: () => pickDateTime(false),
                  ),

                  TextField(
                    controller: locationCtrl,
                    decoration: const InputDecoration(labelText: 'Location'),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String?>(
                    value: subjectId,
                    decoration: const InputDecoration(labelText: 'Subject'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('None')),
                      ...subjects.map(
                        (s) => DropdownMenuItem(
                          value: s.id,
                          child: Text('${s.subjectName} (${s.subjectCode})'),
                        ),
                      ),
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
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    value: reminderMinutes,
                    decoration: const InputDecoration(labelText: 'Reminder'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('None')),
                      DropdownMenuItem(value: 60, child: Text('1 Hour Before')),
                      DropdownMenuItem(value: 360, child: Text('6 Hours Before')),
                      DropdownMenuItem(value: 1440, child: Text('1 Day Before')),
                    ],
                    onChanged: (v) => setLocal(() => reminderMinutes = v),
                  ),
                ],
              ),
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
      ),
    );

    if (saved == true && uid != null) {
      if (titleCtrl.text.trim().isEmpty) return;
      try {
        if (existing == null) {
          await eventRepo.addEvent(
            uid: uid!,
            title: titleCtrl.text,
            location: locationCtrl.text,
            startTime: startTime,
            endTime: endTime,
            subjectId: subjectId,
            isRecurring: isRecurring,
          );
        } else {
          await eventRepo.updateEvent(
            uid: uid!,
            eventId: existing.id,
            title: titleCtrl.text,
            location: locationCtrl.text,
            startTime: startTime,
            endTime: endTime,
            subjectId: subjectId,
            isRecurring: isRecurring,
          );
        }
        
        if (reminderMinutes != null) {
          DateTime notifyTime = startTime.subtract(Duration(minutes: reminderMinutes!));
          if (notifyTime.isAfter(DateTime.now())) {
            NotificationService().scheduleNotification(
              id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
              title: 'Upcoming Event: ${titleCtrl.text}',
              body: 'Starts at ${DateFormat('h:mm a').format(startTime)}',
              scheduledTime: notifyTime,
            );
          }
        }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to save the event right now. Please try again.'),
            ),
          );
}
      
    }
  }



  Future<void> _showTaskDialog({
    TaskItem? existing,
    required List<Subject> subjects,
  }) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    DateTime? dueDate =
        existing?.dueDate ?? _selectedDay; 
    TaskPriority priority = existing?.priority ?? TaskPriority.medium;
    TaskStatus status = existing?.status ?? TaskStatus.todo;
    String? subjectId = existing?.subjectId;
    int? reminderMinutes;

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) {
          Future<void> pickDueDate() async {
            final initial = dueDate ?? DateTime.now();
            final date = await showDatePicker(
              context: context,
              initialDate: initial,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
            );
            if (date == null) return;

            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(initial),
            );
            if (time == null) return;

            setLocal(() {
              dueDate = DateTime(
                date.year,
                date.month,
                date.day,
                time.hour,
                time.minute,
              );
            });
          }

          return AlertDialog(
            title: Text(existing == null ? 'Add Task' : 'Edit Task'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Due Date', style: TextStyle(fontSize: 14)),
                    subtitle: Text(
                      dueDate != null
                          ? DateFormat('EEE, MMM d, yyyy h:mm a').format(dueDate!)
                          : 'No due date set',
                      style: TextStyle(
                          color: dueDate != null ? Colors.black87 : Colors.red,
                          fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(Icons.calendar_month, color: Color(0xFFEF3E5F)),
                    onTap: pickDueDate,
                  ),
                  const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  value: subjectId,
                  decoration: const InputDecoration(labelText: 'Subject'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    ...subjects.map(
                      (s) => DropdownMenuItem(
                        value: s.id,
                        child: Text('${s.subjectName} (${s.subjectCode})'),
                      ),
                    ),
                  ],
                  onChanged: (v) => setLocal(() => subjectId = v),
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<TaskPriority>(
                  value: priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: const [
                    DropdownMenuItem(
                      value: TaskPriority.high,
                      child: Text('High'),
                    ),
                    DropdownMenuItem(
                      value: TaskPriority.medium,
                      child: Text('Medium'),
                    ),
                    DropdownMenuItem(
                      value: TaskPriority.low,
                      child: Text('Low'),
                    ),
                  ],
                  onChanged: (v) =>
                      setLocal(() => priority = v ?? TaskPriority.medium),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  value: reminderMinutes,
                  decoration: const InputDecoration(labelText: 'Reminder'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('None')),
                    DropdownMenuItem(value: 60, child: Text('1 Hour Before')),
                    DropdownMenuItem(value: 360, child: Text('6 Hours Before')),
                    DropdownMenuItem(value: 1440, child: Text('1 Day Before')),
                  ],
                  onChanged: (v) => setLocal(() => reminderMinutes = v),
                ),
              ],
            ),
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
      }),
    );

    if (saved == true && uid != null) {
      if (titleCtrl.text.trim().isEmpty) return;
      if (existing == null) {
        await taskRepo.addTask(
          uid: uid!,
          title: titleCtrl.text,
          description: descCtrl.text,
          dueDate: dueDate,
          priority: priority,
          status: status,
          subjectId: subjectId,
        );
      } else {
        await taskRepo.updateTask(
          uid: uid!,
          taskId: existing.id,
          title: titleCtrl.text,
          description: descCtrl.text,
          dueDate: dueDate,
          priority: priority,
          status: status,
          subjectId: subjectId,
        );
      }
      
      if (reminderMinutes != null && dueDate != null) {
        DateTime notifyTime = dueDate!.subtract(Duration(minutes: reminderMinutes!));
        if (notifyTime.isAfter(DateTime.now())) {
          NotificationService().scheduleNotification(
            id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
            title: 'Task Due Soon: ${titleCtrl.text}',
            body: 'Due at ${DateFormat('EEE, MMM d, h:mm a').format(dueDate!)}',
            scheduledTime: notifyTime,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (uid == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return StreamBuilder<List<TaskItem>>(
      stream: taskRepo.watchTasks(uid!),
      builder: (context, taskSnap) {
        return StreamBuilder<List<CalendarEvent>>(
          stream: eventRepo.watchEvents(uid!),
          builder: (context, eventSnap) {
            final tasks = taskSnap.data ?? [];
            final events = eventSnap.data ?? [];

            List<dynamic> getItemsForDay(DateTime day) {
              final dayTasks = tasks
                  .where((t) => t.dueDate != null && isSameDay(t.dueDate, day))
                  .toList();
              final dayEvents = events.where((e) {
                if (isSameDay(e.startTime, day)) return true;
                if (e.isRecurring) {
                  return day.weekday == e.startTime.weekday && 
                         (day.isAfter(e.startTime) || isSameDay(day, e.startTime));
                }
                return false;
              }).toList();
              return [...dayTasks, ...dayEvents];
            }

            final selectedItems = getItemsForDay(_selectedDay ?? _focusedDay);
     

            selectedItems.sort((a,b){
              final dateA = ( a is CalendarEvent) ? a.startTime : (a as TaskItem).dueDate ?? DateTime.now();
              final dateB = ( b is CalendarEvent) ? b.startTime : (b as TaskItem).dueDate ?? DateTime.now();

              return dateA.compareTo(dateB);
            });

            return Scaffold(
              backgroundColor: Colors.white,
              appBar: AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                centerTitle: true,
                title: const Text(
                  'Calendar',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              body: Column(
                children: [
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
                      titleTextStyle: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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
                        border: Border.all(
                          color: const Color(0xFF4C4EA1).withOpacity(0.5),
                        ),
                      ),
                      todayTextStyle: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, day, events) {
                        if (events.isEmpty) return const SizedBox();

                        final hasTask = events.any((e) => e is TaskItem);
                        final hasEvent = events.any((e) => e is CalendarEvent);

                        final dots = <Widget>[];

                        if (hasEvent) {
                          dots.add(
                            Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 1.5,
                              ),
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF4C4EA1),
                                shape: BoxShape.circle,
                              ),
                            ),
                          );
                        }
                        if (hasTask) {
                          dots.add(
                            Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 1.5,
                              ),
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF3E5F),
                                shape: BoxShape.circle,
                              ),
                            ),
                          );
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
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatPage())),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(2), 
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4C4EA1), Color(0xFFEF3E5F), Color(0xFFFACD16)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/LUMINA FYP FINALR.png',
                              width: 28,
                              height: 28,
                              errorBuilder: (c, e, s) => const Icon(
                                Icons.auto_awesome,
                                color: Colors.purple,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'ASK LUMINA',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _openEventDialog(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.deepBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Add Event',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Add Task',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),


                  Expanded(
                    child: selectedItems.isEmpty
                        ? const Center(
                            child: Text('No events or tasks for this day.'),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                            itemCount: selectedItems.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
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

  void _showItemOptions({required dynamic item}) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  if (item is TaskItem) {
                    _openTaskDialog(existing: item);
                  } else if (item is CalendarEvent) {
                    _openEventDialog(existing: item);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  if (item is TaskItem) {
                    await taskRepo.deleteTask(uid: uid!, taskId: item.id);
                  } else if (item is CalendarEvent) {
                    await eventRepo.deleteEvent(uid: uid!, eventId: item.id);
                  }
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEventCard(CalendarEvent e) {
    return GestureDetector(
      onLongPress: () => _showItemOptions(item: e),
      child: Container(
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
                color: Color(0xFF4C4EA1), 
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
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
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${DateFormat('hh:mm a').format(e.startTime)} - ${DateFormat('hh:mm a').format(e.endTime)}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        if (e.location.isNotEmpty)
                          Text(
                            e.location,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(TaskItem t) {
    return GestureDetector(
      onLongPress: () => _showItemOptions(item: t),
      child: TaskCard(
        key: ValueKey(t.id),
        task: t,
        onToggle: (isDone) async {
          await taskRepo.updateTask(
            uid: uid!,
            taskId: t.id,
            title: t.title,
            description: t.description,
            dueDate: t.dueDate,
            priority: t.priority,
            status: isDone ? TaskStatus.done : TaskStatus.todo,
            subjectId: t.subjectId,
          );
        },
      ),
    );
  }
}

