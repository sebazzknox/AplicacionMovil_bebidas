import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> ensureSignedInAndPromoteToAdmin() async {
  final auth = FirebaseAuth.instance;
  // 1) iniciar sesión si no hay
  if (auth.currentUser == null) {
    await auth.signInAnonymously(); // o signInWithEmailAndPassword(...)
  }
  final uid = auth.currentUser!.uid;

  // 2) marcar rol=admin en /users/{uid}
  await FirebaseFirestore.instance.collection('users').doc(uid).set(
    {
      'role': 'admin',
      'updatedAt': FieldValue.serverTimestamp(),
    },
    SetOptions(merge: true),
  );
}