import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/main_scaffold.dart';
import '../data/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'register_page.dart';
import '../../admin/ui/admin_auth_page.dart';


class AuthPage extends StatefulWidget {
  final VoidCallback? onAuthpagepressed;

  const AuthPage({super.key, this.onAuthpagepressed});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final _authRepository = AuthRepository();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleForgotPassword() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email address first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await _authRepository.sendPasswordReset(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset email sent to $email'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, 
      body: Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/login_backg.png',
            fit: BoxFit.cover,
          ),
        ),
        Align(
          alignment: const Alignment(0, -1.15), 
          child: Column(
            mainAxisSize: MainAxisSize.min, 
            children: [
              Image.asset(
                'assets/images/luminalogo.png',
                height: 300,
                width: 300,
              ),
              const SizedBox(height: 20),
              const Text(
                'Welcome Student', 
                style: TextStyle(
                  color: Colors.black, 
                  fontSize: 18,
                  fontWeight: FontWeight.bold
                )
              ),
              const Text(
                'Sign in to continue your learning journey', 
                style: TextStyle(
                  color: Colors.grey, 
                  fontSize: 11,
                  fontWeight: FontWeight.w200
                )
              ),
            const SizedBox(height: 20),

              SizedBox(
                width: 346,
                height: 50,
                child: TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                    prefixIcon: Icon(Icons.email),
                    hintText: 'Email',
                    fillColor: const Color(0xFFEFF4F8),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                ),
                ),
          ),
            const SizedBox(height: 10),

              SizedBox(
                width: 346,
                height: 50,
                child: TextField(
                controller: passwordController,
                keyboardType: TextInputType.visiblePassword,
                obscureText: true,
                decoration: InputDecoration(
                    prefixIcon: Icon(Icons.lock),
                    hintText: 'Password',
                    fillColor: const Color(0xFFEFF4F8),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                ),
                ),
          ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: 346,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: _handleForgotPassword,
                            child: const Text(
                              'Forgot Password ?', 
                              style: TextStyle(
                                color: Color(0xFF4C4EA1), 
                                fontSize: 12,
                                fontWeight: FontWeight.w200
                              )
                            ),
                          ),
                        ),
                      ),
              const SizedBox(height: 20),
              SizedBox(
                width: 346,
                height: 50,
                child: ElevatedButton(
                onPressed: () async {
                  try {
                    await _authRepository.signIn(
                      emailController.text.trim(),
                      passwordController.text.trim(),
                    );
                    
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                         MaterialPageRoute(builder: (_) => const MainScaffold()),
                         (route) => false,
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString()),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                child: const Text('Sign In',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold
                ),
                
                ),
              ),  
              ),
              const SizedBox(height: 20),
            RichText(
            text: TextSpan(
                style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: Colors.grey,
                ),
                children: [
                const TextSpan(
                    text: "Don't have an account? ",
                ),
                TextSpan(
                    text: 'Register Now',
                    style: const TextStyle(
                    color: Color(0xFF4C4EA1), 
                    fontWeight: FontWeight.w400,
                    ),
                    recognizer: TapGestureRecognizer()
                    ..onTap = () {
                    Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => RegisterPage()),
                  );                    },
                ),
                ],
            ),
            ),

              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminAuthPage()));
                },
                icon: const Icon(Icons.admin_panel_settings, color: Colors.grey),
                label: const Text('Admin Portal Login', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            ],
          ),
        ),
      ],
      ),
    );
  }
}
