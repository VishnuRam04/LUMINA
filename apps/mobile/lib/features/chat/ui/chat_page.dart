import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../subjects/data/file_repository.dart';
import '../../calendar/data/event_repository.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../../../core/api/api_client.dart';

class ChatPage extends StatefulWidget {
  final VoidCallback? onBackPressed;
  const ChatPage({super.key, this.onBackPressed});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  static final List<Map<String, String>> _messages = []; 
  bool _isLoading = false;

  File? _selectedImage;
  String? _imageBase64;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _selectedImage = File(picked.path);
        _imageBase64 = base64Encode(bytes);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_messages.isNotEmpty && _scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: Opacity(
              opacity: 0.3,
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return _buildChatBubble(msg['role'] == 'user', msg);
                    },
                  ),
                ),


                if (_isLoading)
                   const Padding(
                     padding: EdgeInsets.all(8.0),
                     child: CircularProgressIndicator(),
                   ),

                _buildInputArea(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const SizedBox(height: 10),
        Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
                  onPressed: widget.onBackPressed ?? () => Navigator.pop(context),
                ),
              ),
            ),
            const Text(
              'LUMINA AI',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
          ],
        ),
        const SizedBox(height: 20),
        
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF4C4EA1), width: 2), 
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4C4EA1).withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: [
              
               Container(
                 width: 60, height: 60,
                 decoration: BoxDecoration(
                   shape: BoxShape.circle,
                   border: Border.all(color: const Color(0xFF4C4EA1)),
                 ),
                 child: const Icon(Icons.auto_awesome, color: Colors.amber, size: 36),
               ),
               const SizedBox(width: 16),
               const Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text("Hi, I'm LUMINA.", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                     SizedBox(height: 4),
                     Text("Ask Me anything about your notes, tasks, quizzes, or subjects.", style: TextStyle(fontSize: 12, height: 1.4)),
                   ],
                 ),
               ),
               IconButton(
                 icon: const Icon(Icons.delete_outline, color: Colors.red),
                 onPressed: () {
                   setState(() {
                     _messages.clear();
                   });
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(
                       content: Text("Chat history cleared. Start a new conversation!"),
                       duration: Duration(seconds: 2),
                     ),
                   );
                 },
                 tooltip: "Clear Chat History",
               )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChatBubble(bool isUser, Map<String, String> msg) {
    String message = msg['content']!;
    final attachmentLabel = msg['attachment'];
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          color: isUser ? Colors.white : const Color(0xFF4C4EA1), 
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
            bottomRight: isUser ? Radius.zero : const Radius.circular(16),
          ),
          border: isUser ? Border.all(color: Colors.grey.shade300) : null,
          boxShadow: [
             BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser)...[
              const Text('Lumina AI', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 4),
            ],
            if (attachmentLabel != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isUser
                      ? const Color(0xFFF3F4F8)
                      : Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isUser
                        ? Colors.grey.shade300
                        : Colors.white.withValues(alpha: 0.24),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.image_outlined,
                      size: 14,
                      color: isUser ? Colors.black54 : Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      attachmentLabel,
                      style: TextStyle(
                        color: isUser ? Colors.black87 : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (message.trim().isNotEmpty)
              MarkdownBody(
                data: message,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    color: isUser ? Colors.black87 : Colors.white,
                    height: 1.4,
                    fontSize: 16,
                  ),
                  strong: TextStyle(
                    color: isUser ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  listBullet: TextStyle(
                    color: isUser ? Colors.black87 : Colors.white,
                  ),
                  tableHead: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  tableBody: const TextStyle(color: Colors.white),
                  h1: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  h2: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  h3: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            if (!isUser && msg.containsKey('event_data')) ...[
               const SizedBox(height: 12),
               _buildEventCard(msg['event_data']!),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(String eventJson) {
     Map<String, dynamic> data = jsonDecode(eventJson);
     String title = data['title'] ?? 'New Event';
     String dateStr = data['date'] ?? '';
     return Container(
       padding: const EdgeInsets.all(12),
       decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(12)),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Row(children: [const Icon(Icons.event, color: Color(0xFF4C4EA1)), const SizedBox(width:8), Expanded(child: Text(title, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)))]),
           const SizedBox(height: 4),
           Text(dateStr, style: const TextStyle(color: Colors.black54, fontSize: 12)),
           const SizedBox(height: 8),
           SizedBox(width: double.infinity, height: 32, child: ElevatedButton(
             style: ElevatedButton.styleFrom(
               backgroundColor: const Color(0xFF4C4EA1),
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
             ),
             onPressed: () async {
                try {
                  DateTime dt = DateTime.parse(dateStr);
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  if (uid != null) {
                    await EventRepository(FirebaseFirestore.instance).addEvent(
                      uid: uid,
                      title: title,
                      location: '',
                      startTime: dt,
                      endTime: dt.add(const Duration(hours: 2)),
                      subjectId: null,
                      isRecurring: false
                    );
                    final reminderTime = dt.subtract(const Duration(hours: 1));
                    if (reminderTime.isAfter(DateTime.now())) {
                      NotificationService().scheduleNotification(
                        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
                        title: 'Upcoming Event: $title',
                        body: 'Starts at ${DateFormat('h:mm a').format(dt)}',
                        scheduledTime: reminderTime,
                      );
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Date added to calendar')),
                    );
                  }
                } catch(e) {
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding event: $e')));
                }
             },
             child: const Text('Add to Calendar', style: TextStyle(fontSize: 12, color: Colors.white)),
           ))
         ]
       )
     );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedImage != null)
             Stack(children: [
               Container(margin: const EdgeInsets.only(bottom: 8), height: 60, width: 60, child: Image.file(_selectedImage!, fit: BoxFit.cover)),
               Positioned(right: 0, top: 0, child: InkWell(onTap: () => setState((){_selectedImage = null; _imageBase64 = null;}), child: Container(color: Colors.white70, child: const Icon(Icons.close, size: 16))))
             ]),
          Row(
            children: [
              InkWell(
                onTap: _pickImage,
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFE0E0E0),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: const Icon(Icons.camera_alt, color: Colors.black54),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: const InputDecoration(
                            hintText: 'Ask anything',
                            border: InputBorder.none,
                          ),
                          onSubmitted: (val) => _handleSend(val),
                        ),
                      ),
                      InkWell(
                        onTap: () => _handleSend(_controller.text),

                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                          child: const Icon(Icons.send, color: Colors.white, size: 16)
                        )
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      )
    );
  }

  Future<void> _handleSend(String text) async {
    final trimmedText = text.trim();
    final selectedImage = _selectedImage;
    final imageBase64 = _imageBase64;
    final hasImage = selectedImage != null && imageBase64 != null;

    if (trimmedText.isEmpty && !hasImage) return;

    _controller.clear();
    setState(() {
      _messages.add({
        'role': 'user',
        'content': trimmedText.isEmpty ? ' ' : trimmedText,
        if (hasImage) 'attachment': 'Image attached',
      });
      _selectedImage = null;
      _imageBase64 = null;
      _isLoading = true;
    });
    
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent, 
        duration: const Duration(milliseconds: 300), 
        curve: Curves.easeOut
      );
    });

    try {
    
      final history = _messages
          .where((m) => m['role'] != null && m['content'] != null)
          .map((m) => {'role': m['role']!, 'content': m['content']!})
          .toList();
          

      if (history.isNotEmpty) {
          history.removeLast(); 
      }

      final response = await ApiClient().chat(
        trimmedText,
        history: history,
        imageBase64: imageBase64,
      );
      final answer = response['answer']?.toString() ?? "I didn't get an answer.";
      
      Map<String, dynamic>? eventData;
      if (response['event_data'] != null) {
        eventData = response['event_data'] as Map<String, dynamic>;
      }
      
      setState(() {
        _messages.add({
          'role': 'gemini', 
          'content': answer, 
          if (eventData != null) 'event_data': jsonEncode(eventData)
        });
      });
    } catch (e) {
      setState(() {
         _messages.add({'role': 'gemini', 'content': "Error: $e"});
      });
    } finally {
      setState(() => _isLoading = false);
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent, 
            duration: const Duration(milliseconds: 300), 
            curve: Curves.easeOut
          );
        }
      });
    }
  }
}
