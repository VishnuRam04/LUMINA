import 'package:flutter/material.dart';

import 'package:intl/intl.dart';

import '../domain/task.dart';



class TaskCard extends StatefulWidget {
  final TaskItem task;
  final ValueChanged<bool> onToggle;

  const TaskCard({super.key, required this.task, required this.onToggle});

  @override
  State<TaskCard> createState() => _TaskCardState();
}
class _TaskCardState extends State<TaskCard> {
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _isCompleted = widget.task.status == TaskStatus.done;
  }

  @override
  void didUpdateWidget(TaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.status != widget.task.status) {
      _isCompleted = widget.task.status == TaskStatus.done;
    }
  }

  void _handleTap() {
    final newState = !_isCompleted;
    setState(() => _isCompleted = newState);

    if (newState) {
      Future.delayed(const Duration(milliseconds: 600), () {
        widget.onToggle(newState);
      });
    } else {
      widget.onToggle(newState);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    
    final Color barColor = const Color(0xFFEF3E5F);
    
    Color tagBgColor;
    Color tagTextColor;
    String priorityLabel;

    switch (t.priority) {
      case TaskPriority.high:
        tagBgColor = Colors.red.shade50;
        tagTextColor = Colors.red.shade800;
        priorityLabel = 'High';
        break;
      case TaskPriority.medium:
        tagBgColor = Colors.orange.shade50;
        tagTextColor = Colors.orange.shade900;
        priorityLabel = 'Medium';
        break;
      case TaskPriority.low:
      default:
        tagBgColor = Colors.green.shade50;
        tagTextColor = Colors.green.shade800;
        priorityLabel = 'Low';
        break;
    }

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
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _handleTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: barColor, width: 2),
                      color: _isCompleted ? barColor : Colors.transparent,
                    ),
                    child: _isCompleted
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 300),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _isCompleted ? Colors.grey : Colors.black,
                          decoration: _isCompleted
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                        child: Text(t.title),
                      ),
                      const SizedBox(height: 4),
                      if (t.dueDate != null)
                        Text(
                          DateFormat('dd/MM hh:mm a').format(t.dueDate!),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      if (t.description.isNotEmpty)
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                            decoration: _isCompleted
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                          child: Text(
                            t.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: tagBgColor, 
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: tagTextColor.withOpacity(0.3)), 
                  ),
                  child: Text(
                    priorityLabel,
                    style: TextStyle(
                      color: tagTextColor, 
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}