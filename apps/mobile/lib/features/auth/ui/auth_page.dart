import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/main_scaffold.dart';


class AuthPage extends StatefulWidget {
  final VoidCallback? onAuthpagepressed;

  const AuthPage({super.key, this.onAuthpagepressed});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Wait, if the image covers it, this is fine
      body: Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/login_backg.png',
            fit: BoxFit.cover,
          ),
        ),
        Align(
          alignment: const Alignment(0, -1.15), // 0 is center, -0.2 moves it up ~10% of screen
          child: Column(
            mainAxisSize: MainAxisSize.min, // Shrink to fit content so Align works
            children: [
              Image.asset(
                'assets/images/luminalogo.png',
                height: 300,
                width: 300,
              ),
              const SizedBox(height: 20),
              // Use explicit style to ensure visibility against background
              const Text(
                'Welcome Student', 
                style: TextStyle(
                  color: Colors.black, // Changed to black/dark blue to be visible on white bg 
                  fontSize: 18,
                  fontWeight: FontWeight.bold
                )
              ),
              const Text(
                'Sign in to continue your learning journey', 
                style: TextStyle(
                  color: Colors.grey, // Changed to black/dark blue to be visible on white bg 
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
                            onTap: () {
                              // TODO: Implement Forgot Password
                            },
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
                onPressed: () {
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
                    color: Color(0xFF4C4EA1), // darker color
                    fontWeight: FontWeight.w400,
                    ),
                    // recognizer: TapGestureRecognizer()
                    // ..onTap = () {
                    //     // navigate to Register page later
                    // },
                ),
                ],
            ),
            ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const MainScaffold()),
                  );
                },
                child: const Text('Bypass Auth (Test)'),
              ),
            ],
          ),
        ),
      ],
      ),
    );
  }
}
