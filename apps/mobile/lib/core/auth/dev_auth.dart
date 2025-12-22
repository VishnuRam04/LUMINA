import 'package:firebase_auth/firebase_auth.dart';

class DevAuth {
  static Future<String> ensureSignedIn() async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser != null) return auth.currentUser!.uid;

    final cred = await auth.signInAnonymously();
    return cred.user!.uid;
  }
}
