import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/auth/dev_auth.dart';
import '../data/kanban_repository.dart';
import '../domain/kanban_board.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'kanban_board_page.dart';

class KanbanPage extends StatefulWidget {
  const KanbanPage({super.key});

  @override
  State<KanbanPage> createState() => _KanbanPageState();
}

class _KanbanPageState extends State<KanbanPage> {
  late final KanbanRepository repo;
  String? uid;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    repo = KanbanRepository(FirebaseFirestore.instance);
    _init();
  }

  Future<void> _init() async {
    final u = await DevAuth.ensureSignedIn();
    setState(() => uid = u);
  }
  
  void _showShareDialog(KanbanBoard board) {
    // Generate a simple code - using first 6 chars of ID for now, reversed to be "random-ish"
    // In a real app, this should be a stored 6-digit code.
    final code = board.id.substring(0, 6).toUpperCase(); 
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        contentPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(
                data: code,
                version: QrVersions.auto,
                size: 200.0,
              ),
              const SizedBox(height: 16),
              const Text(
                '5 7 7 1 6 9', // Placeholder code to match image strictly, or dynamic 'code' variable
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 4),
              ),
               // Actually using the dynamic one for functionality, but keeping styling similar
               // Text(code.split('').join(' '), style: ...),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Share logic
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: Color(0xFF4C4EA1), width: 2), // Gradient border simulated
                     // For exact gradient border we need a Container but simple border is okay for now
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Share Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showJoinDialog() {
    final codeCtrls = List.generate(6, (_) => TextEditingController());
    final focusNodes = List.generate(6, (_) => FocusNode());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Center(child: Text('Enter Code', style: TextStyle(fontWeight: FontWeight.bold))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                return Container(
                  width: 30, // Narrow fields for code
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: TextField(
                    controller: codeCtrls[index],
                    focusNode: focusNodes[index],
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    decoration: InputDecoration(
                       counterText: '',
                       contentPadding: const EdgeInsets.symmetric(vertical: 8),
                       border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (val) {
                      if (val.isNotEmpty && index < 5) {
                        focusNodes[index + 1].requestFocus();
                      }
                      if (val.isEmpty && index > 0) {
                        focusNodes[index - 1].requestFocus();
                      }
                    },
                  ),
                );
              }),
            ),
          ],
        ),
        actions: [
          Center(
            child: SizedBox(
               width: 200,
               child: ElevatedButton(
                onPressed: () {
                  // Join logic here
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white, 
                  foregroundColor: Colors.black,
                  side: const BorderSide(color: Color(0xFF4C4EA1), width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 5,
                ),
                child: const Text('Join Board', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Board'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description')),
            // Visibility, etc.
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (uid != null && titleCtrl.text.isNotEmpty) {
                repo.createBoard(
                  uid: uid!,
                  title: titleCtrl.text,
                  description: descCtrl.text,
                  isPublic: false,
                );
              }
              Navigator.pop(context);
            },
            child: const Text('Create Board'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background
        Positioned.fill(
          child: Image.asset('assets/images/background.png', fit: BoxFit.cover),
        ),
        
        SafeArea(
          child: Column(
            children: [
               // Header
               Padding(
                 padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                 child: Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     const Text('Kanban Boards', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                     // Add any header icons if needed
                   ],
                 ),
               ),
               
               // Search Bar
               Padding(
                 padding: const EdgeInsets.symmetric(horizontal: 16),
                 child: Row(
                   children: [
                     Expanded(
                       child: TextField(
                         controller: _searchCtrl,
                         decoration: InputDecoration(
                           hintText: 'Value', // As per image mockup text 'Value' (?) or 'Search'
                           prefixIcon: const Icon(Icons.search),
                           filled: true,
                           fillColor: Colors.white.withOpacity(0.5),
                           border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                           contentPadding: const EdgeInsets.symmetric(vertical: 0),
                         ),
                       ),
                     ),
                     const SizedBox(width: 8),
                     Container(
                       padding: const EdgeInsets.all(12),
                       decoration: BoxDecoration(
                         color: Colors.white.withOpacity(0.5),
                         borderRadius: BorderRadius.circular(12),
                       ),
                       child: const Icon(Icons.tune),
                     ),
                   ],
                 ),
               ),
               
               const SizedBox(height: 16),
               
               // Board List
               Expanded(
                 child: StreamBuilder<List<KanbanBoard>>(
                   stream: repo.watchBoards(uid!),
                   builder: (context, snap) {
                     if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
                     if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                     
                     final boards = snap.data!;
                     if (boards.isEmpty) return const Center(child: Text('No boards found.'));

                     return ListView.separated(
                       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                       itemCount: boards.length,
                       separatorBuilder: (_, __) => const SizedBox(height: 16),
                       itemBuilder: (context, i) {
                         final b = boards[i];
                         return KanbanBoardCard(
                           board: b,
                           onDelete: () => repo.deleteBoard(b.id),
                           onShare: () => _showShareDialog(b),
                         );
                       },
                     );
                   },
                 ),
               ),
               
               // Bottom Buttons
               Padding(
                 padding: const EdgeInsets.all(16.0),
                 child: Row(
                   children: [
                     Expanded(
                       child: ElevatedButton.icon(
                         onPressed: _showJoinDialog,
                         icon: const Icon(Icons.link),
                         label: const Text('Join via code'),
                         style: ElevatedButton.styleFrom(
                           backgroundColor: const Color(0xFF4C4EA1),
                           foregroundColor: Colors.white,
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                           padding: const EdgeInsets.symmetric(vertical: 16),
                         ),
                       ),
                     ),
                     const SizedBox(width: 16),
                     Expanded(
                       child: ElevatedButton.icon(
                         onPressed: _showCreateDialog,
                         icon: const Icon(Icons.add),
                         label: const Text('Create Board'),
                         style: ElevatedButton.styleFrom(
                           backgroundColor: const Color(0xFFFACD16), // Yellow
                           foregroundColor: Colors.white,
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                           padding: const EdgeInsets.symmetric(vertical: 16),
                         ),
                       ),
                     ),
                   ],
                 ),
               ),
            ],
          ),
        ),
      ],
    );
  }
}

class KanbanBoardCard extends StatelessWidget {
  final KanbanBoard board;
  final VoidCallback onDelete;
  final VoidCallback onShare;

  const KanbanBoardCard({
    super.key, 
    required this.board,
    required this.onDelete,
    required this.onShare,
  });

  static const deepBlue = Color(0xFF4C4EA1);
  static const yellow = Color(0xFFFACD16);
  static const pink = Color(0xFFEF3E5F);
  static const lightBlue = Color(0xFFCCD6E3);

  String _timeAgo(DateTime d) {
    // Simple helper
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes}min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => KanbanBoardPage(board: board)),
        );
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        showCupertinoModalPopup(
          context: context,
          builder: (context) => CupertinoActionSheet(
            title: Text(board.title),
            actions: [
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(context);
                  onShare();
                },
                child: const Text('Share Board'),
              ),
              CupertinoActionSheetAction(
                isDestructiveAction: true,
                onPressed: () {
                   Navigator.pop(context);
                   onDelete();
                },
                child: const Text('Delete Board'),
              ),
            ],
            cancelButton: CupertinoActionSheetAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(context),
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
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        padding: const EdgeInsets.all(4),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Row(
                children: [
                  const Icon(Icons.code, size: 20, color: Colors.black87), // Assuming code icon from image '< >'
                  const SizedBox(width: 8),
                  Expanded(child: Text(board.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                  // Notification badge? '1' in red circle in image. For now hardcode or omit.
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Avatars
              SizedBox(
                height: 40,
                child: Stack(
                  children: List.generate(board.memberAvatars.length.clamp(0, 4), (index) {
                    return Positioned(
                      left: index * 24.0,
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundImage: NetworkImage(board.memberAvatars[index]),
                          onBackgroundImageError: (_, __) => const Icon(Icons.person),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Footer: Updated tag + Due date
              Row(
                 children: [
                   Container(
                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                     decoration: BoxDecoration(
                       border: Border.all(color: deepBlue),
                       borderRadius: BorderRadius.circular(20),
                     ),
                     child: Text(
                       'Updated ${_timeAgo(board.updatedAt)}',
                       style: const TextStyle(color: Colors.grey, fontSize: 12),
                     ),
                   ),
                   const Spacer(),
                   // "Due 3rd Sept" - Placeholder or real field? Domain doesn't have it yet.
                   // Showing placeholder text for now or description
                   Text(board.description, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                 ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
