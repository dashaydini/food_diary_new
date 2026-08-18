import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  Future<void> createOrUpdateUser(
    User user,
  ) async {
    final ref = firestore.collection('users').doc(user.uid);

    await ref.set(
        {
          'uid': user.uid,
          'name': user.displayName ?? '',
          'email': user.email ?? '',
          'photoUrl': user.photoURL ?? '',
          'lastLogin': FieldValue.serverTimestamp(),
        },
        SetOptions(
          merge: true,
        ));
  }
}
