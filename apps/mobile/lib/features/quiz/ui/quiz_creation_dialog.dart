import 'package:flutter/material.dart';
import '../../subjects/domain/subject_file.dart';
import '../data/quiz_repository.dart';
import 'quiz_page.dart';

class QuizCreationDialog extends StatefulWidget {
  final String subjectId;
  final List<SubjectFile> files;
  final List<String> bloomLevels;

  const QuizCreationDialog({super.key, required this.subjectId, required this.files, this.bloomLevels = const []});

  @override
  State<QuizCreationDialog> createState() => _QuizCreationDialogState();
}

class _QuizCreationDialogState extends State<QuizCreationDialog> {
  final Set<String> _selectedFiles = {};
  bool _isGenerating = false;
  final QuizRepository _repo = QuizRepository();

  @override
  void initState() {
    super.initState();
    for (var f in widget.files) {
      _selectedFiles.add(f.name); 
    }
  }

  Future<void> _generate() async {
    if (_selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select at least one chapter")));
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final quiz = await _repo.generateQuiz(
        widget.subjectId, 
        _selectedFiles.toList(), 
        count: 10, 
        bloomLevels: widget.bloomLevels
      );
      
      if (mounted) {
        Navigator.pop(context); 
        Navigator.push(context, MaterialPageRoute(builder: (_) => QuizPage(quiz: quiz)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Create New Quiz"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Select Chapters:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (widget.files.isEmpty) const Text("No files available."),
            ...widget.files.map((file) {
              return CheckboxListTile(
                title: Text(file.name, style: const TextStyle(fontSize: 13)),
                value: _selectedFiles.contains(file.name),
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedFiles.add(file.name);
                    } else {
                      _selectedFiles.remove(file.name);
                    }
                  });
                },
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: const Color(0xFF4C4EA1),
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _isGenerating ? null : () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          onPressed: _isGenerating ? null : _generate,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4C4EA1)),
          child: _isGenerating 
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
              : const Text("Generate", style: TextStyle(color: Colors.white)),
        )
      ],
    );
  }
}
