import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../data/flashcard_repository.dart';
import '../domain/flashcard.dart';

class FlashcardStudyPage extends StatefulWidget {
  final List<Flashcard> cards;
  final int totalCardsInDeck;

  const FlashcardStudyPage({super.key, required this.cards, required this.totalCardsInDeck});

  @override
  State<FlashcardStudyPage> createState() => _FlashcardStudyPageState();
}

class _FlashcardStudyPageState extends State<FlashcardStudyPage> {
  late List<Flashcard> _studyCards;
  int _currentIndex = 0;
  bool _isFlipped = false;
  final FlashcardRepository _repo = FlashcardRepository();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _studyCards = List.from(widget.cards);
  }

  void _handleRating(int rating) async {
    setState(() => _isLoading = true);
    try {
      final card = _studyCards[_currentIndex];
      
      // API Update (optimistic)
      await _repo.reviewCard(card.id, rating);
      
      // Logic: If Again/Hard, re-queue this card for this session
      if (rating < 4) {
        // Re-add to end of list to see it again
        setState(() {
          _studyCards.add(card);
        });
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("Card re-queued for this session"), duration: Duration(milliseconds: 500))
        );
      }
      
      if (_currentIndex < _studyCards.length - 1) {
        setState(() {
          _currentIndex++;
          _isFlipped = false;
          _isLoading = false;
        });
      } else {
         // Finished
         Navigator.pop(context);
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Session Complete! 🎉")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_studyCards.isEmpty) return const Scaffold(body: Center(child: Text("No cards.")));
    
    final card = _studyCards[_currentIndex];
    final progress = (_currentIndex + 1) / _studyCards.length;

    return Scaffold(
      backgroundColor: Colors.white, // Should be lightly gray maybe?
      appBar: AppBar(
        title: const Text("Flash Card", style: TextStyle(color: Colors.grey, fontSize: 16)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text("Chapter 3 - Derivatives", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            const SizedBox(height: 4),
            Container(height: 3, width: 100, color: AppColors.deepBlue),
            const SizedBox(height: 24),
            
            // The Card
            GestureDetector(
              onTap: () => setState(() => _isFlipped = !_isFlipped),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 400,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.deepBlue,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: AppColors.deepBlue.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))
                  ]
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                      child: Text(_isFlipped ? "Answer" : "Front", style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const Spacer(),
                    Text(
                      _isFlipped ? card.back : card.front,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    if (!_isFlipped)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white, 
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.yellow, width: 2)
                        ),
                        child: const Text("Tap to see Answer", style: TextStyle(fontSize: 12)),
                      )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            // Buttons
            if (_isFlipped)
              Row(
                children: [
                   _buildSimpsonsButton("Again", "❌", Colors.red, 1),
                   const SizedBox(width: 8),
                   _buildSimpsonsButton("Hard", "😐", Colors.orange, 3),
                   const SizedBox(width: 8),
                   _buildSimpsonsButton("Good", "🙂", Colors.blue, 4),
                   const SizedBox(width: 8),
                   _buildSimpsonsButton("Easy", "😎", Colors.green, 5),
                ],
              )
            else
              ElevatedButton(
                onPressed: () => setState(() => _isFlipped = true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepBlue,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                ),
                child: const Text("Show Answer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              
             const SizedBox(height: 24),
             
             // Progress
             LinearProgressIndicator(value: progress, color: AppColors.deepBlue, backgroundColor: Colors.grey.shade200),
             const SizedBox(height: 8),
             Text(
               "Queue: ${_currentIndex + 1} / ${_studyCards.length}  (Deck: ${widget.totalCardsInDeck})", 
               style: const TextStyle(color: Colors.grey, fontSize: 12)
             ),
          ],
        ),
      ),
    );
  }
  Widget _buildSimpsonsButton(String label, String emoji, Color color, int rating) {
    return Expanded(
      child: InkWell(
        onTap: _isLoading ? null : () => _handleRating(rating),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.5), width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 4),
              )
            ]
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}
