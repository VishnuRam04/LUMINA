import 'package:flutter/material.dart';
import '../domain/quiz_model.dart';
import '../data/quiz_repository.dart';

class QuizPage extends StatefulWidget {
  final Quiz quiz;

  const QuizPage({super.key, required this.quiz});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  late PageController _pageController;
  int _currentIndex = 0;
  final QuizRepository _repo = QuizRepository();
  
  // State for Open Ended
  final TextEditingController _answerController = TextEditingController();
  bool _isChecking = false;
  
  // Feedback Data
  Map<String, dynamic> _feedback = {}; // {questionId: GradeResponse or correct/incorrect}
  Map<String, String> _userAnswers = {}; 

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  void _nextPage() {
    if (_currentIndex < widget.quiz.questions.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() {
        _currentIndex++;
        _answerController.clear();
      });
    } else {
      // Finish
      Navigator.pop(context);
    }
  }

  Future<void> _checkMCQ(QuizQuestion q, String selectedOption) async {
    setState(() {
      _userAnswers[q.id] = selectedOption;
      // Pre-calculated feedback since we know correct answer
      bool isCorrect = selectedOption == q.correctAnswer;
       _feedback[q.id] = {
         'is_correct': isCorrect,
         'explanation': q.explanation,
         'correct_answer': q.correctAnswer
       };
    });
  }

  Future<void> _checkOpenEnded(QuizQuestion q) async {
    if (_answerController.text.isEmpty) return;
    
    setState(() => _isChecking = true);
    try {
      final result = await _repo.gradeAnswer(q.question, _answerController.text, "");
      setState(() {
        _userAnswers[q.id] = _answerController.text;
        _feedback[q.id] = result; 
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.quiz.title, style: const TextStyle(color: Colors.black, fontSize: 16)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          // Progress Bar
          LinearProgressIndicator(
            value: (_currentIndex + 1) / widget.quiz.questions.length,
            backgroundColor: Colors.grey[200],
            color: const Color(0xFF4C4EA1),
          ),
          
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.quiz.questions.length,
              itemBuilder: (context, index) {
                return _buildQuestionCard(widget.quiz.questions[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(QuizQuestion q) {
    bool isAnswered = _feedback.containsKey(q.id);
    dynamic feedback = _feedback[q.id];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Question Box
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF4C4EA1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text(
                  q.question,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                // Image placeholder if we had images
              ],
            ),
          ),
          const SizedBox(height: 32),

          if (q.type == 'multiple_choice')
            ...q.options.asMap().entries.map((entry) {
              int idx = entry.key;
              String option = entry.value;
              List<Color> colors = [Colors.pinkAccent, Colors.amber, Colors.orangeAccent, Colors.lightBlue];
              
              bool isSelected = _userAnswers[q.id] == option;
              bool isCorrect = isAnswered && feedback['is_correct'] && isSelected;
              bool isWrong = isAnswered && !feedback['is_correct'] && isSelected;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: isAnswered ? null : () => _checkMCQ(q, option),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSelected 
                          ? (isCorrect ? Colors.green : (isWrong ? Colors.red : colors[idx % colors.length]))
                          : colors[idx % colors.length],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.white24,
                          child: Text(String.fromCharCode(65 + idx), style: const TextStyle(color: Colors.white)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: Text(option, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                ),
              );
            }),

          if (q.type == 'open_ended') ...[
             TextField(
               controller: _answerController,
               maxLines: 4,
               decoration: InputDecoration(
                 hintText: 'Type your answer here...',
                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                 filled: true,
                 fillColor: Colors.grey[50]
               ),
               enabled: !isAnswered,
             ),
             const SizedBox(height: 16),
             if (!isAnswered)
               SizedBox(
                 width: double.infinity,
                 child: ElevatedButton(
                   onPressed: _isChecking ? null : () => _checkOpenEnded(q),
                   style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4C4EA1), padding: const EdgeInsets.all(16)),
                   child: _isChecking ? const CircularProgressIndicator(color: Colors.white) : const Text('Submit Answer', style: TextStyle(color: Colors.white)),
                 ),
               )
          ],

          // Feedback Section
          if (isAnswered) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: feedback['is_correct'] == true ? Colors.green : Colors.red, width: 2),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        feedback['is_correct'] == true ? Icons.check_circle : Icons.cancel, 
                        color: feedback['is_correct'] == true ? Colors.green : Colors.red
                      ),
                      const SizedBox(width: 8),
                      Text(
                        feedback['is_correct'] == true ? "Correct!" : "Incorrect",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(feedback['explanation'] ?? feedback['feedback'] ?? "No explanation.", style: const TextStyle(fontSize: 14)),
                  
                  if (feedback['is_correct'] != true && feedback['improvement_tip'] != null) ...[
                     const SizedBox(height: 8),
                     Text("Tip: ${feedback['improvement_tip']}", style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey)),
                  ]
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 120,
              child: ElevatedButton(
                onPressed: _nextPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white, 
                  side: const BorderSide(color: Colors.black),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                ),
                child: const Text("Next", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            )
          ]
        ],
      ),
    );
  }
}
