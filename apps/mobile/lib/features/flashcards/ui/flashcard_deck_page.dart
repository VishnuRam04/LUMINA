import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../data/flashcard_repository.dart';
import '../domain/flashcard.dart';
import 'flashcard_study_page.dart';

class FlashcardDeckPage extends StatelessWidget {
  final String subjectId;
  final String subjectName;
  final String? fileId;
  final String? chapterName;
  final FlashcardRepository repo = FlashcardRepository();

  FlashcardDeckPage({
    super.key, 
    required this.subjectId, 
    required this.subjectName,
    this.fileId,
    this.chapterName
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(chapterName ?? subjectName, style: const TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<List<Flashcard>>(
        stream: repo.watchCards(subjectId, fileId: fileId),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final cards = snapshot.data!;
          final mastered = cards.where((c) => c.status == 'mastered').length;
          final learning = cards.where((c) => c.status == 'learning').length;
          final newCards = cards.where((c) => c.status == 'new').length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProgressCard(cards.length, mastered, learning, newCards),
                const SizedBox(height: 24),
                _buildActionButtons(context, cards),
                const SizedBox(height: 24),
                const Text("Card Preview List", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                _buildCardList(cards),
                const SizedBox(height: 24),
                _buildBottomButtons(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgressCard(int total, int mastered, int learning, int newCards) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(chapterName ?? subjectName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis)),
              if (chapterName != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.deepBlue),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(subjectName, style: const TextStyle(fontSize: 10, color: AppColors.deepBlue)),
                )
            ],
          ),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerLeft, child: Text("$total Cards", style: const TextStyle(fontSize: 12, color: Colors.grey))),
          const SizedBox(height: 12),
          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                if (mastered > 0) Expanded(flex: mastered, child: Container(height: 10, color: AppColors.deepBlue)),
                if (learning > 0) Expanded(flex: learning, child: Container(height: 10, color: AppColors.yellow)),
                if (newCards > 0) Expanded(flex: newCards, child: Container(height: 10, color: AppColors.pink)),
                if (total == 0) Expanded(child: Container(height: 10, color: Colors.grey.shade300)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _legendItem(AppColors.deepBlue, "Mastered: $mastered"),
              _legendItem(AppColors.yellow, "Learning: $learning"),
              _legendItem(AppColors.pink, "New: $newCards"),
            ],
          )
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String text) {
    return Row(
      children: [
        CircleAvatar(backgroundColor: color, radius: 4),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, List<Flashcard> cards) {
    final now = DateTime.now();
    final studyCards = cards.where((c) {
      if (c.status == 'new') return true;
      if (c.status == 'learning') return true; // Always study learning cards unless handled strictly by review time
      return c.nextReview.isBefore(now);
    }).toList();

    return Row(
      children: [
        Expanded(child: _actionButton(context, "Study Now", Icons.play_arrow_outlined, AppColors.deepBlue, 
          () => _navigateToStudy(context, studyCards, cards.length))), // Study Due + New
        const SizedBox(width: 12),
        Expanded(child: _actionButton(context, "Review Mistake", Icons.error_outline, AppColors.yellow, 
          () => _navigateToStudy(context, cards.where((c) => c.status == 'learning').toList(), cards.length))),
        const SizedBox(width: 12),
        Expanded(child: _actionButton(context, "Shuffle Now", Icons.shuffle, AppColors.pink, 
          () => _navigateToStudy(context, cards..shuffle(), cards.length))), // Shuffle ignores schedule, brute force review
      ],
    );
  }

  Widget _actionButton(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 3))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  void _navigateToStudy(BuildContext context, List<Flashcard> studySet, int totalDeckCount) {
    if (studySet.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No cards to study in this queue!")));
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => FlashcardStudyPage(cards: studySet, totalCardsInDeck: totalDeckCount)));
  }

  Widget _buildCardList(List<Flashcard> cards) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final card = cards[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Container(
                     padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                     decoration: BoxDecoration(
                       border: Border.all(color: Colors.grey),
                       borderRadius: BorderRadius.circular(8)
                     ),
                     child: const Text("Front", style: TextStyle(fontSize: 10)),
                   ),
                   Icon(Icons.auto_awesome, size: 14, color: Colors.primaries[index % Colors.primaries.length])
                ],
              ),
              const SizedBox(height: 4),
              Text(card.front, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Container(
                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                     decoration: BoxDecoration(border: Border.all(color: AppColors.deepBlue), borderRadius: BorderRadius.circular(12)),
                     child: const Text("From Notes", style: TextStyle(fontSize: 10)),
                   ),
                   Container(
                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                     decoration: BoxDecoration(
                       color: card.status == 'mastered' ? AppColors.deepBlue : (card.status == 'learning' ? AppColors.yellow : AppColors.pink), 
                       borderRadius: BorderRadius.circular(12)
                     ),
                     child: Text(card.status.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                   ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => _showAddCardDialog(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.deepBlue, 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size(0, 50)
            ),
            child: const Text("Add Flash Card", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 16),
        // Auto Generate
         Expanded(
          child: OutlinedButton.icon(
            onPressed: () { 
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Auto Generate triggered (Mock)")));
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.pink, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size(0, 50)
            ),
            icon: const Icon(Icons.auto_awesome, color: AppColors.pink),
            label: const Text("Auto Generate", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  void _showAddCardDialog(BuildContext context) {
    final frontCtrl = TextEditingController();
    final backCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add New Card"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: frontCtrl, decoration: const InputDecoration(labelText: "Front (Question)")),
            const SizedBox(height: 12),
            TextField(controller: backCtrl, decoration: const InputDecoration(labelText: "Back (Answer)")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (frontCtrl.text.isNotEmpty && backCtrl.text.isNotEmpty) {
                 Navigator.pop(context);
                 await repo.addCard(subjectId, frontCtrl.text, backCtrl.text, fileId: fileId);
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Card added!")));
              }
            }, 
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.deepBlue),
            child: const Text("Add", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }
}
