import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/auth/dev_auth.dart';
import '../../calendar/data/event_repository.dart';
import '../../calendar/domain/event.dart';
import '../../calendar/data/task_repository.dart';
import '../../calendar/domain/task.dart';
import '../../calendar/ui/calendar_page.dart'; // For TaskCard

class HomePage extends StatefulWidget {
  final VoidCallback? onAskLuminaPressed;

  const HomePage({super.key, this.onAskLuminaPressed});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? uid;
  late EventRepository eventRepo;
  late TaskRepository taskRepo;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    eventRepo = EventRepository(FirebaseFirestore.instance);
    taskRepo = TaskRepository(FirebaseFirestore.instance);
    _initAuth();
  }

  Future<void> _initAuth() async {
    final u = await DevAuth.ensureSignedIn();
    if (mounted) {
      setState(() => uid = u);
    }
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F5F7), // Fallback
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<List<CalendarEvent>>(
      stream: eventRepo.watchEvents(uid!),
      builder: (context, eventSnap) {
        return StreamBuilder<List<TaskItem>>(
          stream: taskRepo.watchTasks(uid!),
          builder: (context, taskSnap) {
            final events = eventSnap.data ?? [];
            final tasks = taskSnap.data ?? [];

            // Filter events for selected day (for the calendar timeline only)
            final dayEvents = events.where((e) => isSameDay(e.startTime, _selectedDate)).toList();
            
            // For the bottom list: Show ALL tasks, sorted by Priority then Due Date
            final sortedTasks = List<TaskItem>.from(tasks);
            sortedTasks.sort((a, b) {
              // 1. Priority (High < Medium < Low)
              int priorityComp = a.priority.index.compareTo(b.priority.index);
              if (priorityComp != 0) return priorityComp;
              
              // 2. Due Date (Earliest first, Null last)
              if (a.dueDate == null && b.dueDate == null) return 0;
              if (a.dueDate == null) return 1;
              if (b.dueDate == null) return -1;
              return a.dueDate!.compareTo(b.dueDate!);
            });

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
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // App Bar / Title
                              const Padding(
                                padding: EdgeInsets.only(left: 8.0),
                                child: Text(
                                  'Dash',
                                  style: TextStyle(
                                    fontSize: 14, 
                                    color: Colors.grey, 
                                    fontWeight: FontWeight.w400
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // 1. Weekly Calendar Card (Pass specific events for timeline)
                              _buildWeeklyCalendar(dayEvents),
                              
                              const SizedBox(height: 16),

                              // Ask Lumina
                              GestureDetector(
                                onTap: widget.onAskLuminaPressed,
                                child: Container(
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
                              ),
                              
                              const SizedBox(height: 16),
                               // Section Title
                              const Padding(
                                padding: EdgeInsets.only(left: 4.0, bottom: 8),
                                child: Text(
                                  'All Tasks', 
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                                ),
                              ),

                              // Task List
                              if (sortedTasks.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(20.0),
                                  child: Center(child: Text('No tasks yet.', style: TextStyle(color: Colors.grey))),
                                )
                              else
                                ListView.separated(
                                  physics: const NeverScrollableScrollPhysics(),
                                  shrinkWrap: true,
                                  itemCount: sortedTasks.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                                  itemBuilder: (context, i) {
                                    final item = sortedTasks[i];
                                    return _buildTaskCard(item);
                                  },
                                ),
                                
                                const SizedBox(height: 80), // Bottom padding
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
        );
      }
    );
  }

  // --- 1. Calendar Widget ---
  Widget _buildWeeklyCalendar(List<CalendarEvent> events) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, 5))
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Days Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final now = DateTime.now();
              // Calculate start of week (Sunday)
              final startOfWeek = now.subtract(Duration(days: now.weekday % 7));
              final date = startOfWeek.add(Duration(days: index));
              final dayName = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'][index];
              
              // Highlight based on _selectedDate
              final isSelected = isSameDay(date, _selectedDate);
              
              return InkWell(
                onTap: () {
                  setState(() => _selectedDate = date);
                },
                borderRadius: BorderRadius.circular(16),
                child: _buildDayItem(dayName, date.day.toString(), isSelected),
              );
            }),
          ),
          const SizedBox(height: 24),
          
          // Timeline Events (Use passed events)
          if (events.isEmpty) 
             const Padding(
                padding: EdgeInsets.symmetric(vertical: 20.0),
                child: Text(
                  'No classes today',
                  style: TextStyle(color: Colors.grey),
                ),
              )
          else 
            Column(
              children: events.map((event) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: _buildTimelineItem(event),
                );
              }).toList(),
            ),
        ],
      ),
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
    // Reuse TaskCard from Calendar Page
    return TaskCard(
      key: ValueKey(t.id),
      task: t,
      onComplete: () async {
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



  Widget _buildDayItem(String day, String date, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: isActive 
        ? BoxDecoration(
            color: AppColors.deepBlue, 
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepBlue.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 4)
              )
            ]
          )
        : null,
      child: Column(
        children: [
          Text(
            day, 
            style: TextStyle(
              fontSize: 16, 
              fontWeight: FontWeight.bold, 
              color: isActive ? Colors.white : Colors.black
            )
          ),
          const SizedBox(height: 6),
          Text(
            date, 
            style: TextStyle(
              fontSize: 14, 
              color: isActive ? Colors.white.withOpacity(0.8) : Colors.grey
            )
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(CalendarEvent event) {
    // Format Time: 10.00 AM - 11.30 AM
    final start = DateFormat('h.mm a').format(event.startTime);
    final end = DateFormat('h.mm a').format(event.endTime);
    final timeStr = '$start - $end';

    // Cycle colors or random based on event ID hash
    final colors = [AppColors.deepBlue, AppColors.pink, AppColors.yellow];
    final color = colors[event.hashCode % colors.length];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Colored Bar
        Container(
          width: 6, 
          height: 48, 
          decoration: BoxDecoration(
            color: color, 
            borderRadius: BorderRadius.circular(30)
          ),
        ),
        const SizedBox(width: 12),
        
        // Time Column
        SizedBox(
          width: 90, // Slightly wider for formatted time
          child: Text(
            timeStr, 
            style: const TextStyle(
              fontSize: 13, 
              color: Colors.grey,
              height: 1.4
            )
          ),
        ),
        const SizedBox(width: 8),

        // Content Column
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.title, 
                style: const TextStyle(
                  fontSize: 15, 
                  fontWeight: FontWeight.w600,
                  color: Colors.black87
                )
              ),
              const SizedBox(height: 4),
              if (event.location.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      event.location, 
                      style: const TextStyle(fontSize: 13, color: Colors.grey)
                    ),
                  ],
                )
            ],
          ),
        )
      ],
    );
  }
}
