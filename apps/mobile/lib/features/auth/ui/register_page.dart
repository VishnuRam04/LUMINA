import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/main_scaffold.dart';
import '../data/auth_repository.dart';


class RegisterPage extends StatefulWidget {
  final VoidCallback? onAuthpagepressed;

  const RegisterPage({super.key, this.onAuthpagepressed});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
final new_nameController = TextEditingController();
final new_emailController = TextEditingController();
final new_passwordController = TextEditingController();
final new_password2Controller = TextEditingController();
bool _isLoading = false;


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
                          const Text(
                'Come Join Us Today', 
                style: TextStyle(
                  color: Colors.black, // Changed to black/dark blue to be visible on white bg 
                  fontSize: 18,
                  fontWeight: FontWeight.bold
                )
              ),
              const Text(
                'Your AI powered education journey starts here', 
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
                  controller: new_nameController,
                  keyboardType: TextInputType.name,
                  decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.person),
                      hintText: 'Name',
                      fillColor: const Color(0xFFEFF4F8),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                  ),
                ),
              ),
            const SizedBox(height: 20),

              SizedBox(
                width: 346,
                height: 50,
                child: TextField(
                  controller: new_emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.email),
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
              const SizedBox(height: 20),

              SizedBox(
                width: 346,
                height: 50,
                child: TextField(
                  controller: new_passwordController,
                  keyboardType: TextInputType.visiblePassword,
                  obscureText: true,
                  decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock),
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
                const SizedBox(height: 20),

              SizedBox(
                width: 346,
                height: 50,
                child: TextField(
                  controller: new_password2Controller,
                  keyboardType: TextInputType.visiblePassword,
                  obscureText: true,
                  decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock),
                      hintText: 'Confirm Password',
                      fillColor: const Color(0xFFEFF4F8),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                  ),
                ),
              ),
                const SizedBox(height: 20),
              SizedBox(
                width: 346,
                height: 50,
                child: ElevatedButton(
                onPressed: _isLoading ? null : () async {
                  if (new_passwordController.text != new_password2Controller.text) {
                     ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Passwords do not match")),
                    );
                    return;
                  }
                  
                  setState(() => _isLoading = true);

                  try {
                    // Using the AuthRepository we created
                    // Ensure to import it at the top
                    final authRepo = AuthRepository(); 
                    await authRepo.signUp(
                      email: new_emailController.text.trim(),
                      password: new_passwordController.text.trim(),
                      name: new_nameController.text.trim(),
                    );
                    
                    if (context.mounted) {
                      // Navigate directly to MainScaffold and remove all previous routes
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const MainScaffold()),
                        (route) => false,
                      );
                    }
                  } catch (e) {
                     if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                        );
                        setState(() => _isLoading = false);
                     }
                  }
                },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                child: _isLoading 
                  ? const SizedBox(
                      width: 20, 
                      height: 20, 
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    )
                  : const Text('Register Now',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold
                    ),
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











