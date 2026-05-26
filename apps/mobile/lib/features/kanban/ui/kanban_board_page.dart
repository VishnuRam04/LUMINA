import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../data/kanban_repository.dart';
import '../domain/kanban_board.dart';
import '../domain/kanban_task.dart';

class KanbanBoardPage extends StatefulWidget {
  final KanbanBoard board;
  final String uid;

  const KanbanBoardPage({super.key, required this.board, required this.uid});

  @override
  State<KanbanBoardPage> createState() => _KanbanBoardPageState();
}

class _KanbanBoardPageState extends State<KanbanBoardPage> {
  late final KanbanRepository repo;
  List<Map<String, dynamic>> _boardMembers = [];

  @override
  void initState() {
    super.initState();
    repo = KanbanRepository(FirebaseFirestore.instance);
    _fetchBoardMembers();
  }

  Future<void> _fetchBoardMembers() async {
    List<Map<String, dynamic>> members = [];
    for (int i = 0; i < widget.board.members.length; i++) {
      final uid = widget.board.members[i];
      final name = (i < widget.board.memberNames.length) 
          ? widget.board.memberNames[i] 
          : 'Guest ${uid.length > 4 ? uid.substring(0, 4) : uid}';
      members.add({'uid': uid, 'name': name});
    }
    if (mounted) {
      setState(() {
        _boardMembers = members;
      });
    }
  }

  void _showAddTaskDialog(String columnId) {
    final titleCtrl = TextEditingController();
    PlatformFile? pickedFile;
    DateTime? selectedDate;
    List<String> selectedAssignees = [widget.uid];
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add Task'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Task Title'),
                  autofocus: true,
                  enabled: !isUploading,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(selectedDate == null 
                            ? 'Set Due Date' 
                            : DateFormat('MMM d, yyyy').format(selectedDate!)),
                        onPressed: isUploading ? null : () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now().subtract(const Duration(days: 365)),
                            lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                          );
                          if (date != null) {
                            setState(() => selectedDate = date);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Assign To:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: -8,
                  children: _boardMembers.map((m) {
                    final uid = m['uid'] as String;
                    final name = m['name'] as String;
                    final isSelected = selectedAssignees.contains(uid);
                    return FilterChip(
                      label: Text(name, style: const TextStyle(fontSize: 12)),
                      selected: isSelected,
                      onSelected: (val) {
                        setState(() {
                          if (val) selectedAssignees.add(uid);
                          else selectedAssignees.remove(uid);
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.attach_file),
                      label: const Text('Attach File'),
                      onPressed: isUploading
                          ? null
                          : () async {
                              final result = await FilePicker.platform
                                  .pickFiles();
                              if (result != null) {
                                setState(() {
                                  pickedFile = result.files.first;
                                });
                              }
                            },
                    ),
                    const SizedBox(width: 8),
                    if (pickedFile != null)
                      Expanded(
                        child: Text(
                          pickedFile!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isUploading ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isUploading
                    ? null
                    : () async {
                        if (titleCtrl.text.isNotEmpty) {
                          setState(() => isUploading = true);
                          String? attachmentUrl;
                          String? attachmentName;

                          if (pickedFile != null && pickedFile!.path != null) {
                            try {
                              final file = File(pickedFile!.path!);
                              final safeName = pickedFile!.name.replaceAll(
                                RegExp(r'[^a-zA-Z0-9.\-_]'),
                                '_',
                              );
                              final ref = FirebaseStorage.instance.ref().child(
                                'boards/${widget.board.id}/tasks/${DateTime.now().millisecondsSinceEpoch}_$safeName',
                              );
                              await ref.putFile(file);
                              attachmentUrl = await ref.getDownloadURL();
                              attachmentName = pickedFile!.name;
                            } catch (e) {
                              print("Error uploading attachment: $e");
                              // Optionally show a snackbar here
                            }
                          }

                          await repo.addTask(
                            uid: widget.board.ownerUid,
                            boardId: widget.board.id,
                            title: titleCtrl.text,
                            columnId: columnId,
                            dueDate: selectedDate,
                            assignees: selectedAssignees,
                            attachmentUrl: attachmentUrl,
                            attachmentName: attachmentName,
                          );

                          if (mounted) Navigator.pop(context);
                        }
                      },
                child: isUploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showInviteDialog() async {
    final code = await repo.getOrGenerateShareCode(widget.uid, widget.board.id);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Invite Member', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share this 6-digit access code with others to collaborate:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SelectableText(
                code,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 6,
                  color: Color(0xFF4C4EA1),
                ),
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
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
            child: Image.asset(
              'assets/images/background.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Back Button & Title
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
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
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
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
                      const Text(
                        'Group Members',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          // Avatars (Overlapping stack to avoid negative width crash)
                          SizedBox(
                            height: 50,
                            // calculate width based on overlapping
                            width:
                                widget.board.memberAvatars.length.clamp(0, 4) *
                                    35.0 +
                                15.0,
                            child: Stack(
                              children: List.generate(
                                widget.board.memberAvatars.length.clamp(0, 4),
                                (i) {
                                  return Positioned(
                                    left: i * 35.0,
                                    child: CircleAvatar(
                                      radius: 25,
                                      backgroundColor: Colors.white,
                                      child: CircleAvatar(
                                        radius: 23,
                                        backgroundImage: widget.board.memberAvatars[i].isNotEmpty
                                            ? NetworkImage(widget.board.memberAvatars[i])
                                            : null,
                                        backgroundColor: Colors.grey[200],
                                        child: widget.board.memberAvatars[i].isEmpty
                                            ? const Icon(Icons.person, color: Colors.grey)
                                            : null,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                          // Invite Button
                          if (widget.board.ownerUid == widget.uid)
                            GestureDetector(
                              onTap: _showInviteDialog,
                            child: Column(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Invite Member',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Columns using Board Stream
                Expanded(
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('boards').doc(widget.board.id).snapshots(),
                    builder: (context, boardSnap) {
                      if (!boardSnap.hasData) return const Center(child: CircularProgressIndicator());
                      
                      final boardData = boardSnap.data!.data() as Map<String, dynamic>? ?? {};
                      final rawCols = boardData['columns'] as List<dynamic>? ?? [{'id': 'todo', 'name': 'To Do'}];
                      final cols = rawCols.map((c) => {'id': c['id'].toString(), 'name': c['name'].toString()}).toList();
                      
                      return StreamBuilder<List<KanbanTask>>(
                        stream: repo.watchTasks(widget.board.ownerUid, widget.board.id),
                        builder: (context, taskSnap) {
                          final tasks = taskSnap.data ?? [];

                          return ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: cols.length + 1, // +1 for Add Column button
                            separatorBuilder: (_, __) => const SizedBox(width: 16),
                            itemBuilder: (context, i) {
                              if (i == cols.length) {
                                return _buildAddColumnButton(cols);
                              }
                              
                              final colName = cols[i]['name']!;
                              final colId = cols[i]['id']!;
                              final colTasks = tasks.where((t) => t.columnId == colId).toList();

                              return _buildColumn(colName, colId, colTasks, cols);
                            },
                          );
                        },
                      );
                    }
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

  Widget _buildColumn(String title, String colId, List<KanbanTask> tasks, List<Map<String, String>> currentCols) {
    return Container(
      width: 300,
      margin: const EdgeInsets.only(bottom: 24), // Space from bottom
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.withOpacity(0.3),
          width: 1,
        ), // Fallback
      ),
      child: Container(
        // Gradient border simulation
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF4C4EA1), Color(0xFFFACD16), Color(0xFFEF3E5F)],
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
                    GestureDetector(
                      onLongPress: () => _showRenameColumnDialog(title, colId, currentCols),
                      child: Text(
                        '$title (${tasks.length})',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
              
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _showAddTaskDialog(colId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4C4EA1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
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

  Widget _buildAddColumnButton(List<Map<String, String>> currentCols) {
    return GestureDetector(
      onTap: () => _showAddColumnDialog(currentCols),
      child: Container(
        width: 300,
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withOpacity(0.5), width: 1, style: BorderStyle.solid),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                 padding: const EdgeInsets.all(12),
                 decoration: BoxDecoration(
                   color: Colors.grey[300],
                   shape: BoxShape.circle,
                 ),
                 child: const Icon(Icons.add, size: 30, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              const Text('Add Column', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddColumnDialog(List<Map<String, String>> currentCols) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New Column'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Column Name'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (ctrl.text.trim().isNotEmpty) {
                 final newCol = {'id': DateTime.now().millisecondsSinceEpoch.toString(), 'name': ctrl.text.trim()};
                 currentCols.add(newCol);
                 await FirebaseFirestore.instance.collection('boards').doc(widget.board.id).update({
                   'columns': currentCols
                 });
                 if (mounted) Navigator.pop(context);
              }
            }, 
            child: const Text('Add')
          ),
        ]
      )
    );
  }
  
  void _showRenameColumnDialog(String oldName, String colId, List<Map<String, String>> currentCols) {
    final ctrl = TextEditingController(text: oldName);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename/Delete Column'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Column Name'), autofocus: true),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
             onPressed: () async {
               // Protect the Todo column from deletion if it's the last one
               if (currentCols.length <= 1) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot delete the last column!')));
                  return;
               }
               currentCols.removeWhere((c) => c['id'] == colId);
               await FirebaseFirestore.instance.collection('boards').doc(widget.board.id).update({
                 'columns': currentCols
               });
               if (mounted) Navigator.pop(context);
             }, 
             child: const Text('Delete', style: TextStyle(color: Colors.red))
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  if (ctrl.text.trim().isNotEmpty) {
                     final index = currentCols.indexWhere((c) => c['id'] == colId);
                     if (index != -1) {
                        currentCols[index]['name'] = ctrl.text.trim();
                        await FirebaseFirestore.instance.collection('boards').doc(widget.board.id).update({
                          'columns': currentCols
                        });
                     }
                     if (mounted) Navigator.pop(context);
                  }
                }, 
                child: const Text('Save')
              ),
            ]
          )
        ]
      )
    );
  }

  void _showEditTaskDialog(KanbanTask task) async {
    final titleCtrl = TextEditingController(text: task.title);
    String selectedCol = task.columnId;
    bool isSaving = false;

    // Fetch columns
    final boardDoc = await FirebaseFirestore.instance.collection('boards').doc(widget.board.id).get();
    if (!boardDoc.exists) return;
    final boardData = boardDoc.data() as Map<String, dynamic>? ?? {};
    final rawCols = boardData['columns'] as List<dynamic>? ?? [{'id': 'todo', 'name': 'To Do'}];
    final cols = rawCols.map((c) => {'id': c['id'].toString(), 'name': c['name'].toString()}).toList();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Edit Task'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Task Title'),
                  enabled: !isSaving,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: cols.any((c) => c['id'] == selectedCol) ? selectedCol : cols.first['id'],
                  decoration: const InputDecoration(labelText: 'Column'),
                  items: cols.map((c) => DropdownMenuItem(value: c['id'], child: Text(c['name']!))).toList(),
                  onChanged: isSaving ? null : (val) => setState(() => selectedCol = val!),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isSaving ? null : () async {
                  if (titleCtrl.text.isNotEmpty) {
                    setState(() => isSaving = true);
                    await repo.updateTask(
                      uid: widget.board.ownerUid,
                      boardId: widget.board.id,
                      taskId: task.id,
                      title: titleCtrl.text,
                      columnId: selectedCol,
                      priority: task.priority,
                      dueDate: task.dueDate,
                      attachmentUrl: task.attachmentUrl,
                      attachmentName: task.attachmentName,
                    );
                    if (mounted) Navigator.pop(context);
                  }
                },
                child: isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showItemOptions(KanbanTask task) {
    repo.markTaskRead(widget.board.id, task.id, widget.uid);
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
                title: const Text('Edit Task'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditTaskDialog(task);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete Task',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await FirebaseFirestore.instance
                      .collection('boards')
                      .doc(widget.board.id)
                      .collection('tasks')
                      .doc(task.id)
                      .delete();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showCommentsSheet(KanbanTask task) {
    repo.markTaskRead(widget.board.id, task.id, widget.uid);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final commentController = TextEditingController();
        bool showMentions = false;
        String mentionQuery = '';
        
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredMembers = showMentions
                ? _boardMembers.where((m) => m['name'].toString().toLowerCase().contains(mentionQuery.toLowerCase())).toList()
                : [];

            return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.6,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Comments',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Divider(),
                Expanded(
                  child: StreamBuilder(
                    stream: repo.watchComments(
                      widget.board.ownerUid,
                      widget.board.id,
                      task.id,
                    ),
                    builder: (context, snap) {
                      if (!snap.hasData)
                        return const Center(child: CircularProgressIndicator());
                      final comments = snap.data!;
                      if (comments.isEmpty)
                        return const Center(child: Text("No comments yet."));
                      return ListView.builder(
                        itemCount: comments.length,
                        // Not reversing visually here, just showing them in standard order:
                        itemBuilder: (context, i) {
                          final c = comments[i];
                          final idx = widget.board.members.indexOf(c.authorId);
                          final avatarUrl = (idx != -1 && idx < widget.board.memberAvatars.length) 
                              ? widget.board.memberAvatars[idx] 
                              : '';
                              
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.grey[300],
                              backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                              child: avatarUrl.isEmpty ? const Icon(Icons.person, size: 16, color: Colors.white) : null,
                            ),
                            title: Text(
                              c.text,
                              style: const TextStyle(fontSize: 14),
                            ),
                            subtitle: Text(
                              DateFormat('MMM d, h:mm a').format(c.createdAt),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                if (showMentions && filteredMembers.isNotEmpty)
                  Container(
                    height: 120,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: ListView.builder(
                      itemCount: filteredMembers.length,
                      itemBuilder: (context, index) {
                        final member = filteredMembers[index];
                        final memberUid = member['uid'];
                        final idx = widget.board.members.indexOf(memberUid);
                        final avatarUrl = (idx != -1 && idx < widget.board.memberAvatars.length) 
                            ? widget.board.memberAvatars[idx] 
                            : '';
                            
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.grey[300],
                            backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                            child: avatarUrl.isEmpty ? const Icon(Icons.person, size: 12, color: Colors.white) : null,
                          ),
                          title: Text(member['name']),
                          onTap: () {
                            final text = commentController.text;
                            final words = text.split(' ');
                            words.removeLast();
                            words.add('@${member['name']} ');
                            commentController.text = words.join(' ');
                            commentController.selection = TextSelection.fromPosition(TextPosition(offset: commentController.text.length));
                            setModalState(() {
                              showMentions = false;
                              mentionQuery = '';
                            });
                          },
                        );
                      },
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: commentController,
                        onChanged: (val) {
                          final lastWord = val.split(' ').last;
                          if (lastWord.startsWith('@')) {
                            setModalState(() {
                              showMentions = true;
                              mentionQuery = lastWord.substring(1);
                            });
                          } else {
                            if (showMentions) setModalState(() => showMentions = false);
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send, color: Color(0xFF4C4EA1)),
                      onPressed: () {
                        final text = commentController.text.trim();
                        if (text.isNotEmpty) {
                          List<String> mentioned = [];
                          for (var member in _boardMembers) {
                            if (text.contains('@${member['name']}')) {
                              mentioned.add(member['uid']);
                            }
                          }
                          repo.addComment(
                            uid: widget.board.ownerUid,
                            boardId: widget.board.id,
                            taskId: task.id,
                            text: text,
                            authorId: widget.uid,
                            mentionedUids: mentioned,
                          );
                          commentController.clear();
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
        });
      },
    );
  }

  Widget _buildTaskCard(KanbanTask task) {
    Color priorityColor = Colors.green;
    if (task.priority == 'high') priorityColor = const Color(0xFFEF3E5F);
    if (task.priority == 'medium') priorityColor = const Color(0xFFFACD16);

    return GestureDetector(
      onLongPress: () => _showItemOptions(task),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (task.unreadBy.contains(widget.uid))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF3E5F),
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      '!', 
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (task.assignees.isNotEmpty)
                  ...task.assignees.take(3).map((assigneeUid) {
                    final idx = widget.board.members.indexOf(assigneeUid);
                    final avatarUrl = (idx != -1 && idx < widget.board.memberAvatars.length) 
                        ? widget.board.memberAvatars[idx] 
                        : '';
                    return Padding(
                      padding: const EdgeInsets.only(right: 4.0),
                      child: CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl.isEmpty ? const Icon(Icons.person, size: 16, color: Colors.white) : null,
                      ),
                    );
                  }).toList()
                else
                  const CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.person_outline, size: 16, color: Colors.white),
                  ),
                const Spacer(),
                if (task.attachmentUrl != null) ...[
                  GestureDetector(
                    onTap: () async {
                      final uri = Uri.parse(task.attachmentUrl!);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    },
                    child: const Icon(
                      Icons.attach_file,
                      size: 22,
                      color: Color(0xFF4C4EA1),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                GestureDetector(
                  onTap: () => _showCommentsSheet(task),
                  child: const Icon(
                    Icons.chat_bubble_outline,
                    size: 22,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${task.commentCount}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (task.dueDate != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFF4C4EA1).withOpacity(0.5),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Due ${DateFormat('d MMM').format(task.dueDate!)}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF4C4EA1),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
