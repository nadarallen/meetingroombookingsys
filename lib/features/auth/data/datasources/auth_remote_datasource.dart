import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/constants/firebase_paths.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<UserCredential> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<UserCredential> signUp(String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  Future<void> signOut() => _auth.signOut();

  Future<void> updateDisplayName(String fullName) async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.updateDisplayName(fullName);
    }
  }

  Future<void> saveUserProfile(String uid, Map<String, dynamic> data) {
    return _firestore
        .collection(FirebasePaths.users)
        .doc(uid)
        .set(data, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> fetchUserProfile(String uid) async {
    final doc = await _firestore.collection(FirebasePaths.users).doc(uid).get();
    return doc.data();
  }

  String? currentUserId() => _auth.currentUser?.uid;
}

