import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../subjects/data/file_repository.dart';
import '../../../../core/api/api_client.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  // STATIC to persist across page switches
  static final List<Map<String, String>> _messages = []; 
  bool _isLoading = false;

  List<String> _allFiles = [];
  List<String> _filteredFiles = [];
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _fetchFiles();
    _controller.addListener(_onTextChanged);
    
    // Scroll to bottom if messages exist
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_messages.isNotEmpty && _scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _fetchFiles() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
        final repo = FileRepository(FirebaseFirestore.instance, FirebaseStorage.instance);
        final files = await repo.getAllUserFiles(uid);
        setState(() => _allFiles = files);
    }
  }

  void _onTextChanged() {
      final text = _controller.text;
      if (text.startsWith('@Summarise ')) {
          final query = text.substring('@Summarise '.length).toLowerCase();
          setState(() {
              _filteredFiles = _allFiles.where((f) => f.toLowerCase().contains(query)).toList();
              _showSuggestions = true;
          });
      } else {
          if (_showSuggestions) setState(() => _showSuggestions = false);
      }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background Elements (corner shapes matching design)
          Positioned(
            top: 0,
            left: 0,
            child: Opacity(
              opacity: 0.3,
              child: Image.asset('assets/images/background.png', width: 150), 
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(),
                
                // Chat Area
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return _buildChatBubble(msg['role'] == 'user', msg['content']!);
                    },
                  ),
                ),

                // Suggestions Overlay
                if (_showSuggestions)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, -2))],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _filteredFiles.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final file = _filteredFiles[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 20),
                          title: Text(file, style: const TextStyle(fontSize: 14)),
                          onTap: () {
                            // Helper to set text and move cursor to end
                            final newText = '@Summarise $file';
                            _controller.text = newText;
                            _controller.selection = TextSelection.fromPosition(TextPosition(offset: newText.length));
                            setState(() => _showSuggestions = false);
                            // Optional: Automatically send? User might want to add more instructions.
                            // Let's keep it in input for user to review.
                          },
                        );
                      },
                    ),
                  ),
                
                if (_isLoading)
                   const Padding(
                     padding: EdgeInsets.all(8.0),
                     child: CircularProgressIndicator(),
                   ),

                // Input Area
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
        const Text(
          'LUMINA AI',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        const SizedBox(height: 20),
        
        // "Hi I'm LUMINA" Card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF4C4EA1), width: 2), // Blue/Purple border
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
               // Lumina Star Icon
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
               // Clear Chat Button
               IconButton(
                 icon: const Icon(Icons.delete_outline, color: Colors.grey),
                 onPressed: () {
                   setState(() {
                     _messages.clear();
                   });
                 },
                 tooltip: "Clear Chat",
               )
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Suggestion Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildChip('Summarise', Colors.amber),
              const SizedBox(width: 12),
              _buildChip('Make a Quiz', const Color(0xFF4C4EA1)), // Blue/Purple
              const SizedBox(width: 12),
              _buildChip('Explanation ?', const Color(0xFFEF3E5F)), // Red
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChip(String label, Color color) {
    return ActionChip(
      label: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      backgroundColor: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
      onPressed: () {
        if (label == 'Summarise') {
          _controller.text = '@Summarise ';
          _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
          // Listener will pick this up and show suggestions
        } else {
          _handleSend(label);
        }
      },
    );
  }

  Widget _buildChatBubble(bool isUser, String message) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          color: isUser ? Colors.white : const Color(0xFF4C4EA1), // White for user, Purple for AI
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
          ],
        ),
      ),
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
      child: Row(
        children: [
          Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFE0E0E0),
            ),
            padding: const EdgeInsets.all(10),
            child: const Icon(Icons.add, color: Colors.black54),
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
                  InkWell(onTap: () {}, child: const Icon(Icons.mic, color: Colors.black54)),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _handleSend(_controller.text),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle),
                        child: const Icon(Icons.graphic_eq, color: Colors.white, size: 16)
                    )
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSend(String text) async {
    if (text.trim().isEmpty) return;
    
    _controller.clear();
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isLoading = true;
    });
    
    // Scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent, 
        duration: const Duration(milliseconds: 300), 
        curve: Curves.easeOut
      );
    });

    try {
      // Get last 6 messages as history (exclude current user message which is appended locally but not yet in loop if we wanted)
      // Actually, we just added the new user message to _messages.
      // So let's take everything valid.
      final history = _messages
          .where((m) => m['role'] != null && m['content'] != null)
          .map((m) => {'role': m['role']!, 'content': m['content']!})
          .toList();
          
      // Remove the last message (which is the current query we just added) to avoid duplication if the backend appends it, 
      // BUT for simplicity, let's just pass the previous history.
      // Actually, standard practice: History = [Old Msg 1, Old Msg 2]. Query = "New Msg".
      if (history.isNotEmpty) {
          history.removeLast(); 
      }

      final response = await ApiClient().chat(text, history: history);
      final answer = response['answer']?.toString() ?? "I didn't get an answer.";
      
      setState(() {
        _messages.add({'role': 'gemini', 'content': answer});
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
