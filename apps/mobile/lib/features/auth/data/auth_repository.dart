import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream of auth state changes (used by StreamBuilder in main.dart)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Current User
  User? get currentUser => _auth.currentUser;

  // Sign In with Email & Password
  Future<UserCredential> signIn(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        throw 'User not found';
      } else if (e.code == 'wrong-password') {
        throw 'Incorrect password';
      } else if (e.code == 'invalid-email') {
        throw 'Invalid email address';
      }
      throw e.message ?? 'Login failed';
    }
  }

  // Register with Email, Password & Name
  Future<UserCredential> signUp({
    required String email, 
    required String password,
    required String name
  }) async {
    try {
      // 1. Create Auth User
      print('DEBUG: Starting signUp for $email...');
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password
      );
      print('DEBUG: User created: ${cred.user?.uid}');

      // 2. Save User Data to Firestore
      if (cred.user != null) {
        try {
          print('DEBUG: Writing to Firestore...');
          await _firestore.collection('users').doc(cred.user!.uid).set({
            'uid': cred.user!.uid,
            'email': email,
            'name': name,
            'createdAt': FieldValue.serverTimestamp(),
          }).timeout(const Duration(seconds: 10)); // Timeout after 10s if stuck
          print('DEBUG: Firestore write complete');
        } catch (e) {
          print('DEBUG: Firestore error: $e');
          // Don't fail the whole registration if just Firestore fails, but good to know
          // Ideally we should handle this, but for now we proceed
        }

        // 3. Update Display Name
        await cred.user!.updateDisplayName(name);
        print('DEBUG: Profile updated');
      }
      
      return cred;
    } on FirebaseAuthException catch (e) {
      print('DEBUG: Auth error: ${e.code}');
      throw e.message ?? 'Registration failed';
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
