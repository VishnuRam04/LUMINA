import 'package:flutter/material.dart';
import '../../features/calendar/ui/calendar_page.dart';  
import '../../features/subjects/ui/subjects_page.dart';
import '../theme/app_colors.dart';

import '../../features/chat/ui/chat_page.dart';
import '../../features/kanban/ui/kanban_page.dart';  

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 4; // Default to Kanban for review (changed to 2 ideally? No, keep as is unless user asked)

  // Pages
  final List<Widget> _pages = [
    const PlaceholderPage(title: 'Home'),
    const CalendarPage(),
    const ChatPage(), // Replaced Placeholder
    const SubjectsPage(),
    const KanbanPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNavItem(0, Icons.home_outlined, Icons.home_filled, 'Home'),
              _buildNavItem(1, Icons.calendar_today_outlined, Icons.calendar_month, 'Calendar'),
              _buildCenterItem(2),
              _buildNavItem(3, Icons.book_outlined, Icons.book, 'Study'),
              _buildNavItem(4, Icons.view_kanban_outlined, Icons.view_kanban, 'Kanban'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData iconOutlined, IconData iconFilled, String label) {
    final isSelected = _currentIndex == index;
    
    // If selected, we wrap everything in the blue container.
    // If not selected, just the icon and text directly.
    
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: isSelected 
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
            : const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.deepBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? iconFilled : iconOutlined,
              color: isSelected ? Colors.white : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterItem(int index) {
    // The center item 'Lumina' with the star icon
    // For now we'll simulate the star with a custom icon or image.
    // Since we don't have the asset, I'll use a combination of icons or just a colored star.
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
             padding: const EdgeInsets.all(10),
             child: const Icon(
               Icons.star, // Placeholder for the actual Lumina Logo
               color: AppColors.yellow, // Using yellow as base, or maybe multicoloured gradient?
               size: 28,
             ),
          ),
           const SizedBox(height: 4),
          Text(
            'LUMINA',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class PlaceholderPage extends StatelessWidget {
  final String title;
  const PlaceholderPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
