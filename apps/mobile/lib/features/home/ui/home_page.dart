import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/auth/dev_auth.dart';
import '../../auth/ui/auth_page.dart';
import '../../calendar/data/event_repository.dart';
import '../../calendar/domain/event.dart';
import '../../calendar/data/task_repository.dart';
import '../../calendar/domain/task.dart';
import '../../calendar/ui/calendar_page.dart'; // For TaskCard
import '../../profile/ui/profile_page.dart';

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
        backgroundColor: Color(0xFFF5F5F7), 
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

            final dayEvents = events.where((e) => isSameDay(e.startTime, _selectedDate)).toList();
            
            var sortedTasks = List<TaskItem>.from(tasks);
            sortedTasks.sort((a, b) {
              int priorityComp = a.priority.index.compareTo(b.priority.index);
              if (priorityComp != 0) return priorityComp;
              
              if (a.dueDate == null && b.dueDate == null) return 0;
              if (a.dueDate == null) return 1;
              if (b.dueDate == null) return -1;
              return a.dueDate!.compareTo(b.dueDate!);
            });
            
            sortedTasks = sortedTasks.take(5).toList();

            // // sortedTasks.sort(a,b){
            // if (a.dueDate == null && b.dueDate == null) return 0;
            // if (a.dueDate == null) return 1;
            // if (b.dueDate == null) return -1;

            // int datecomp = a.dueDate!.compareTo(b.dueDate!);
            // if (datecomp != 0) return datecomp;
            // return a.priority.index.compareTo(b.priority.index);
            
            // }

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
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()));
                                      },
                                      child: CircleAvatar(
                                        radius: 18,
                                        backgroundColor: Colors.grey[300],
                                        backgroundImage: FirebaseAuth.instance.currentUser?.photoURL != null
                                            ? NetworkImage(FirebaseAuth.instance.currentUser!.photoURL!)
                                            : null,
                                        child: FirebaseAuth.instance.currentUser?.photoURL == null
                                            ? const Icon(Icons.person, color: Colors.white, size: 20)
                                            : null,
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: () async {
                                        await FirebaseAuth.instance.signOut();
                                        if (context.mounted) {
                                          Navigator.of(context).pushAndRemoveUntil(
                                            MaterialPageRoute(builder: (_) => const AuthPage()),
                                            (route) => false,
                                          );
                                        }
                                      },
                                      icon: const Icon(Icons.logout, size: 16, color: Colors.red),
                                      label: const Text("Sign Out", style: TextStyle(color: Colors.red, fontSize: 12)),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              _buildWeeklyCalendar(dayEvents),
                              
                              const SizedBox(height: 16),

                              GestureDetector(
                                onTap: widget.onAskLuminaPressed,
                                child: Container(
                                  padding: const EdgeInsets.all(2), 
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF4C4EA1), Color(0xFFEF3E5F), Color(0xFFFACD16)],
                                    ),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
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
                              ),
                              
                              const SizedBox(height: 16),
                              const Padding(
                                padding: EdgeInsets.only(left: 4.0, bottom: 8),
                                child: Text(
                                  'All Tasks', 
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                                ),
                              ),

                              
                              if (sortedTasks.isEmpty)
                                const Padding(
                                
                                  padding: EdgeInsets.all(20.0),

                                  child:Center(
                                  child: Column(
                                  
                                  children:[
                                    
                                    Icon(Icons.check_circle_outline, color:Colors.green, size:40),

                                    SizedBox(height: 8),
                                    
                                     Text('No tasks yet.', style:TextStyle(color: Colors.grey)),
                                  ],
                                  ),
                                  ),

                            
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final now = DateTime.now();
              final startOfWeek = now.subtract(Duration(days: now.weekday % 7));
              final date = startOfWeek.add(Duration(days: index));
              final dayName = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'][index];
              
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
          
          if (events.isEmpty) 
             const Padding(
                padding: EdgeInsets.symmetric(vertical: 20.0),
                child: Text(
                  'No events today',
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
    final start = DateFormat('h.mm a').format(event.startTime);
    final end = DateFormat('h.mm a').format(event.endTime);

    final timeStr = '$start - $end';


    Color color = AppColors.deepBlue;
    if (event.colorHex != null) {
      try {
        color = Color(int.parse(event.colorHex!.replaceAll('#', '0xFF')));
      } catch (_) {}
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6, 
          height: 48, 
          decoration: BoxDecoration(
            color: color, 
            borderRadius: BorderRadius.circular(30)
          ),
        ),
        const SizedBox(width: 12),
        
        SizedBox(
          width: 90, 
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
                    Expanded(
                      child: Text(
                        event.location, 
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
