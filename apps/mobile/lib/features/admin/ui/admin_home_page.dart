import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/ui/auth_page.dart';
import 'admin_logs_page.dart';
import 'admin_users_page.dart';

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});

  Future<int> _countDocs(String collectionId) async {
    final snapshot = await FirebaseFirestore.instance
        .collectionGroup(collectionId)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthPage()),
                  (r) => false,
                );
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned(
            bottom: -50,
            left: -50,
            child: Opacity(
              opacity: 0.08,
              child: Image.asset('assets/images/background.png', width: 300),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Overview',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Track content volume and AI-related activity across the platform.',
                    style: TextStyle(color: Colors.black54, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCountCard(
                          future: _countDocs('files'),
                          title: 'Total Notes Uploaded',
                          color: AppColors.deepBlue,
                          icon: Icons.note_alt_outlined,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildCountCard(
                          future: _countDocs('flashcards'),
                          title: 'Total Flashcards',
                          color: AppColors.yellow,
                          icon: Icons.style_outlined,
                          textColor: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCountCard(
                          future: _countDocs('quizzes'),
                          title: 'Total Quizzes',
                          color: AppColors.pink,
                          icon: Icons.quiz_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Management',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  _buildAdminTile(
                    context,
                    title: 'View All Users',
                    subtitle: 'Inspect and manage registered user accounts.',
                    icon: Icons.people_alt_outlined,
                    color: AppColors.deepBlue,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminUsersPage()),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildAdminTile(
                    context,
                    title: 'System Logs',
                    subtitle: 'Review recent platform events and audit activity.',
                    icon: Icons.receipt_long_outlined,
                    color: AppColors.pink,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminLogsPage()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountCard({
    required Future<int> future,
    required String title,
    required Color color,
    required IconData icon,
    Color textColor = Colors.white,
  }) {
    return FutureBuilder<int>(
      future: future,
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final hasError = snapshot.hasError;
        final count = snapshot.data ?? 0;

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.18),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: textColor, size: 28),
              const SizedBox(height: 18),
              if (isLoading)
                SizedBox(
                  height: 32,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(textColor),
                      ),
                    ),
                  ),
                )
              else if (hasError)
                Text(
                  '--',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                )
              else
                Text(
                  NumberFormat.decimalPattern().format(count),
                  style: TextStyle(
                    color: textColor,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.92),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAdminTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.black54, height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.arrow_forward_ios, color: Colors.black45, size: 18),
          ],
        ),
      ),
    );
  }
}
