import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../data/kanban_repository.dart';
import '../domain/kanban_board.dart';
import '../domain/kanban_task.dart';

class KanbanBoardPage extends StatefulWidget {
  final KanbanBoard board;
  const KanbanBoardPage({super.key, required this.board});

  @override
  State<KanbanBoardPage> createState() => _KanbanBoardPageState();
}

class _KanbanBoardPageState extends State<KanbanBoardPage> {
  late final KanbanRepository repo;

  // Hardcoded columns for now as per mockup + common practice
  final List<String> columns = ['To Do', 'In Progress', 'Done'];
  final Map<String, String> columnIds = {
    'To Do': 'todo',
    'In Progress': 'in_progress',
    'Done': 'done',
  };

  @override
  void initState() {
    super.initState();
    repo = KanbanRepository(FirebaseFirestore.instance);
  }

  void _showAddTaskDialog(String columnId) {
    final titleCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Task'),
        content: TextField(
          controller: titleCtrl,
          decoration: const InputDecoration(labelText: 'Task Title'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (titleCtrl.text.isNotEmpty) {
                 repo.addTask(
                   boardId: widget.board.id,
                   title: titleCtrl.text,
                   columnId: columnId,
                   dueDate: DateTime.now().add(const Duration(days: 3)), // Mock due date
                   priority: 'high', // Mock priority
                 );
                 Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
           // Background matching other pages
           Positioned.fill(
            child: Image.asset('assets/images/background.png', fit: BoxFit.cover),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Back Button & Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                       GestureDetector(
                         onTap: () => Navigator.pop(context),
                         child: const Icon(Icons.arrow_back_ios, size: 20),
                       ),
                       const SizedBox(width: 8),
                       Expanded(
                         child: Text(
                           widget.board.title,
                           style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                           overflow: TextOverflow.ellipsis,
                         ),
                       ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Group Members Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Group Members', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          // Avatars
                          SizedBox(
                            height: 50,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              shrinkWrap: true,
                              itemCount: widget.board.memberAvatars.length.clamp(0, 4),
                              separatorBuilder: (_, __) => const SizedBox(width: -15), // Overlap
                              itemBuilder: (context, i) {
                                return CircleAvatar(
                                  radius: 25,
                                  backgroundColor: Colors.white,
                                  child: CircleAvatar(
                                    radius: 23,
                                    backgroundImage: NetworkImage(widget.board.memberAvatars[i]),
                                    onBackgroundImageError: (_, __) => const Icon(Icons.person),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 24),
                          // Invite Button
                          Column(
                            children: [
                               Container(
                                 width: 50,
                                 height: 50,
                                 decoration: BoxDecoration(
                                   color: Colors.grey[200],
                                   shape: BoxShape.circle,
                                 ),
                                 child: const Icon(Icons.add, color: Colors.grey),
                               ),
                               const SizedBox(height: 4),
                               const Text('Invite Member', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Columns
                Expanded(
                  child: StreamBuilder<List<KanbanTask>>(
                    stream: repo.watchTasks(widget.board.id),
                    builder: (context, snap) {
                      final tasks = snap.data ?? [];
                      
                      return ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: columns.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 16),
                        itemBuilder: (context, i) {
                          final colName = columns[i];
                          final colId = columnIds[colName]!;
                          final colTasks = tasks.where((t) => t.columnId == colId).toList();
                          
                          return _buildColumn(colName, colId, colTasks);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumn(String title, String colId, List<KanbanTask> tasks) {
    return Container(
      width: 300,
      margin: const EdgeInsets.only(bottom: 24), // Space from bottom
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1), // Fallback
         // Implement gradient border if possible similar to board card
      ),
      child: Container(
        // Gradient border simulation
         decoration: BoxDecoration(
           borderRadius: BorderRadius.circular(20),
           gradient: const LinearGradient(
              colors: [
                 Color(0xFF4C4EA1),
                 Color(0xFFFACD16),
                 Color(0xFFEF3E5F),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
           ),
         ),
         padding: const EdgeInsets.all(3),
         child: Container(
           decoration: BoxDecoration(
             color: Colors.white,
             borderRadius: BorderRadius.circular(17),
           ),
           child: Column(
             children: [
               // Header
               Padding(
                 padding: const EdgeInsets.all(16),
                 child: Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Text(
                       '$title (${tasks.length})', 
                       style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                     ),
                     GestureDetector(
                       onTap: () => _showAddTaskDialog(colId),
                       child: Container(
                         padding: const EdgeInsets.all(4),
                         decoration: BoxDecoration(
                           color: Colors.grey[300],
                           shape: BoxShape.circle,
                         ),
                         child: const Icon(Icons.add, size: 20),
                       ),
                     ),
                   ],
                 ),
               ),
               if (colId == 'todo') // Only 'To Do' has the big blue Add Task button in mockup
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _showAddTaskDialog(colId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4C4EA1),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: const Text('Add Task'),
                      ),
                    ),
                  ),

               // Task List
               Expanded(
                 child: ListView.separated(
                   padding: const EdgeInsets.all(16),
                   itemCount: tasks.length,
                   separatorBuilder: (_, __) => const SizedBox(height: 16),
                   itemBuilder: (context, i) => _buildTaskCard(tasks[i]),
                 ),
               ),
             ],
           ),
         ),
      ),
    );
  }

  Widget _buildTaskCard(KanbanTask task) {
    Color priorityColor = Colors.green;
    if (task.priority == 'high') priorityColor = const Color(0xFFEF3E5F);
    if (task.priority == 'medium') priorityColor = const Color(0xFFFACD16);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(color: priorityColor, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Avatars (Placeholder)
              const CircleAvatar(
                 radius: 12, 
                 backgroundColor: Colors.grey,
                 child: Icon(Icons.person, size: 16, color: Colors.white),
              ),
               const SizedBox(width: 4),
               const CircleAvatar(
                 radius: 12, 
                 backgroundColor: Colors.grey,
                 child: Icon(Icons.person, size: 16, color: Colors.white),
              ),
              const Spacer(),
              const Icon(Icons.chat_bubble_outline, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text('${task.commentCount}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          if (task.dueDate != null)
             Container(
               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
               decoration: BoxDecoration(
                 border: Border.all(color: const Color(0xFF4C4EA1).withOpacity(0.5)),
                 borderRadius: BorderRadius.circular(8),
               ),
               child: Text(
                 'Due ${DateFormat('d MMM').format(task.dueDate!)}',
                 style: const TextStyle(fontSize: 10, color: Color(0xFF4C4EA1), fontWeight: FontWeight.bold),
               ),
             ),
        ],
      ),
    );
  }
}
