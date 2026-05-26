import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_home_page.dart';

class AdminAuthPage extends StatelessWidget {
  const AdminAuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    final emailController = TextEditingController(text: 'admin@lumina.com');
    final passwordController = TextEditingController(text: 'admin123');

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Portal Login', style: TextStyle(color: Colors.black))),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.admin_panel_settings, size: 80, color: Color(0xFF4C4EA1)),
            const SizedBox(height: 32),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Admin Email', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Admin Password', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  try {
                    await FirebaseAuth.instance.signInWithEmailAndPassword(
                      email: emailController.text.trim(),
                      password: passwordController.text.trim(),
                    );
                    if (context.mounted) {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminHomePage()));
                    }
                  } on FirebaseAuthException catch (e) {
                    if (e.code == 'invalid-credential' || e.code == 'user-not-found') {
                      try {
                        final creds = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                          email: emailController.text.trim(),
                          password: passwordController.text.trim(),
                        );
                        // Make sure we create the global users document so queries don't break
                        await FirebaseFirestore.instance.collection('users').doc(creds.user!.uid).set({
                          'name': 'System Admin',
                          'email': emailController.text.trim(),
                        });
                        if (context.mounted) {
                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminHomePage()));
                        }
                      } catch (regError) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(regError.toString())));
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${e.code}: ${e.message}')));
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4C4EA1)),
                child: const Text('Admin Login', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            )
          ],
        ),
      ),
    );
  }
}
