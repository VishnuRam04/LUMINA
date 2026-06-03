import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/api/api_client.dart';
class AdminManageUserPage extends StatelessWidget {
  final String userId;
  final Map<String, dynamic> userData;

  const AdminManageUserPage({super.key, required this.userId, required this.userData});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>? ?? userData;
        final name = data['name'] ?? 'Unknown User';
        final email = data['email'] ?? 'No email';
        final isSuspended = data['is_suspended'] == true;

        return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Manage Users', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black87),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(email, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  const Text('Update Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    isSuspended ? 'Reinstate\nUser' : 'Suspend\nUser', 
                    const Color(0xFFEF3E5F), 
                    () async {
                      await FirebaseFirestore.instance.collection('users').doc(userId).update({
                        'is_suspended': !isSuspended,
                      });
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isSuspended ? 'User Reinstated Successfully' : 'User Suspended Successfully')));
                      }
                    }
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    'Change\nPassword', 
                    const Color(0xFF4C4EA1), 
                    () async {
                      try {
                        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password Reset Email Sent!')));
                        }
                      } catch (e) {
                         if (context.mounted) {
                           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                         }
                      }
                    }
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    'Delete\nUser', 
                    const Color(0xFFFACD16), 
                    () async {
                      try {
                        await ApiClient().deleteUser(userId);
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User Profile Deleted')));
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete user: $e')));
                        }
                      }
                    }
                  ),
                ),
              ],
            ),
          ]
        ),
      ),
    );
      },
    );
  }

  Widget _buildActionButton(String title, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 80,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          title, 
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}
