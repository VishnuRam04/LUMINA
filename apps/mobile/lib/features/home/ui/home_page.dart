import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class HomePage extends StatefulWidget {
  final VoidCallback? onAskLuminaPressed;

  const HomePage({super.key, this.onAskLuminaPressed});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
           // Background decorative shapes if any (similar to ChatPage)
           Positioned(
            top: 0,
            right: 0,
            child: Image.asset(
              'assets/images/background.png', // Assuming this exists as used in ChatPage, or just shapes
              width: 150,
              color: AppColors.deepBlue.withOpacity(0.8), // Tint it
              colorBlendMode: BlendMode.srcIn,
            ),
          ),
          
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App Bar / Title
                  const Text(
                    'Dash',
                    style: TextStyle(
                      fontSize: 16, 
                      color: Colors.grey, 
                      fontWeight: FontWeight.w500
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 1. Weekly Calendar Card
                  _buildWeeklyCalendar(),

                  const SizedBox(height: 24),

                  // 2. Suggested Tasks
                  _buildSectionHeader('Suggested Tasks', '4 Tasks Pending'),
                  const SizedBox(height: 12),
                  _buildSuggestedTasksList(),

                  const SizedBox(height: 24),

                  // 3. Ask Lumina Banner
                  _buildAskLuminaBanner(),

                  const SizedBox(height: 24),

                  // 4. Reminders
                  _buildSectionHeader('Reminders', '10 Reminders'),
                  const SizedBox(height: 12),
                  _buildRemindersList(),
                  
                  // Bottom padding for nav bar overlap safety
                  const SizedBox(height: 80), 
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  // --- 1. Calendar Widget ---
  Widget _buildWeeklyCalendar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Days Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDayItem('Su', '15', false),
              _buildDayItem('Mo', '16', false),
              _buildDayItem('Tu', '17', true), // Active
              _buildDayItem('We', '18', false),
              _buildDayItem('Th', '19', false),
              _buildDayItem('Fr', '20', false),
              _buildDayItem('Sa', '21', false),
            ],
          ),
          const SizedBox(height: 16),
          // Timeline
          const Divider(),
          const SizedBox(height: 16),
          _buildTimelineItem('10.00 AM - 11.30 AM', 'Calculus II', 'BM 1-2-3', AppColors.deepBlue),
          const SizedBox(height: 12),
          _buildTimelineItem('12.00 PM - 1.30 PM', 'Software Project Management', 'BM 1-2-3', AppColors.pink),
          const SizedBox(height: 12),
          _buildTimelineItem('2.00 PM - 4.30 PM', 'Requirement Engineering', 'BM 1-2-3', AppColors.yellow),
        ],
      ),
    );
  }

  Widget _buildDayItem(String day, String date, bool isActive) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: isActive 
        ? BoxDecoration(color: AppColors.deepBlue, borderRadius: BorderRadius.circular(12))
        : null,
      child: Column(
        children: [
          Text(day, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isActive ? Colors.white : Colors.black)),
          const SizedBox(height: 4),
          Text(date, style: TextStyle(fontSize: 12, color: isActive ? Colors.white : Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(String time, String title, String loc, Color color) {
    return Row(
      children: [
        Container(
          width: 4, 
          height: 40, 
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.access_time, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Text(time, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Text(loc, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            )
          ],
        )
      ],
    );
  }

  // --- 2. Suggested Tasks ---
  Widget _buildSuggestedTasksList() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none, // Allow shadows to paint outside
      child: Row(
        children: [
           _buildTaskCard(
             'Calculus Flash Cards', 
             0.5, 
             '50%', 
             'Due: 5.00PM',
           ),
           const SizedBox(width: 16),
           _buildTaskCard(
             'Complete SPM Quiz', 
             0.8, 
             '80%', 
             'Due: 5.00PM',
           ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(String title, double progress, String percent, String due) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 50, height: 50,
                    child: CircularProgressIndicator(
                      value: progress, 
                      backgroundColor: AppColors.lightBlue,
                      color: AppColors.deepBlue,
                      strokeWidth: 6,
                    ),
                  ),
                  Text(percent, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
              ElevatedButton(
                onPressed: () {}, 
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  minimumSize: const Size(60, 36),
                ),
                child: const Text('Go !', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 8),
          Text(due, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  // --- 3. Ask Lumina ---
  Widget _buildAskLuminaBanner() {
    return GestureDetector(
      onTap: widget.onAskLuminaPressed,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.transparent),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepBlue.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            )
          ]
        ),
        // Use a gradient border via a stack? Or simpler: CustomPaint. 
        // Simplest: Container with Gradient, holding a smaller white container.
        child: Stack(
          children: [
            // Gradient Border simulator
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: const LinearGradient(
                  colors: [AppColors.deepBlue, AppColors.pink, AppColors.yellow, AppColors.deepBlue],
                ),
              ),
            ),
            // White Content
            Container(
              margin: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(27),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome, color: AppColors.deepBlue), // Star
                  SizedBox(width: 2),
                  // Multicolored Text? Or just Black "ASK LUMINA"
                  Text(
                    ' ASK LUMINA', 
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.w900, 
                      letterSpacing: 2
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // --- 4. Reminders ---
  Widget _buildRemindersList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildReminderItem('Software Project Management Assignment 1', 'Due : 17/9 11.59PM', AppColors.pink),
          Divider(color: Colors.grey[200]),
          _buildReminderItem('Lab Report Submission Calculus II', 'Due : 22/9 11.59PM', AppColors.pink),
          Divider(color: Colors.grey[200]),
          _buildReminderItem('FYP Milestone 1 Submission', 'Due : 22/9 11.59PM', AppColors.pink),
        ],
      ),
    );
  }
  
  Widget _buildReminderItem(String title, String due, Color tagColor) {
    return Row(
      children: [
        // Radio circle
        Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.deepBlue, width: 2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text(due, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: tagColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text('High', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
        )
      ],
    );
  }
}
