import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../auth/ui/auth_page.dart';
import 'admin_users_page.dart';
import 'admin_logs_page.dart';

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Admin Features', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const AuthPage()), (r) => false);
            },
          )
        ],
      ),
      body: Stack(
        children: [
          Positioned(
            bottom: -50,
            left: -50,
            child: Opacity(
              opacity: 0.1,
              child: Image.asset('assets/images/background.png', width: 300),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            child: Column(
              children: [
                _buildAdminTile(
                  context,
                  title: 'View All Users',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminUsersPage())),
                ),
                const SizedBox(height: 16),
                _buildAdminTile(
                  context,
                  title: 'System Logs',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminLogsPage())),
                ),

              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminTile(BuildContext context, {required String title, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Icon(Icons.arrow_forward_ios, color: Colors.black, size: 24),
          ],
        ),
      ),
    );
  }
}
