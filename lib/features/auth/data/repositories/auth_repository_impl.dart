import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/user_profile.dart';
import '../../domain/errors/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote);

  final AuthRemoteDataSource _remote;

  @override
  Stream<UserProfile?> userStream() {
    return _remote.authStateChanges().asyncMap((user) async {
      if (user == null) return null;
      final data = await _remote.fetchUserProfile(user.uid) ?? {};
      return UserProfile.fromMap(
        user.uid,
        data,
        email: user.email ?? '',
      );
    });
  }

  @override
  Future<void> login(String email, String password) async {
    try {
      await _remote.signIn(email, password);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_mapAuthCode(e.code));
    }
  }

  @override
  Future<UserProfile> register({
    required String fullName,
    required String email,
    required String employeeId,
    required String department,
    required String password,
    String role = 'member',
  }) async {
    try {
      final credential = await _remote.signUp(email, password);
      final user = credential.user;
      if (user == null) {
        throw const AuthFailure('Account creation failed.');
      }

      final profile = UserProfile(
        uid: user.uid,
        fullName: fullName,
        email: email,
        employeeId: employeeId,
        department: department,
        role: role,
      );

      await _remote.saveUserProfile(user.uid, profile.toMap());
      await _remote.updateDisplayName(fullName);
      return profile;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_mapAuthCode(e.code));
    }
  }

  @override
  Future<UserProfile> updateProfile(UserProfile profile) async {
    final uid = _remote.currentUserId();
    if (uid == null) {
      throw const AuthFailure('No authenticated user.');
    }
    final normalized = profile.copyWith(uid: uid);
    try {
      await _remote.saveUserProfile(uid, normalized.toMap());
      await _remote.updateDisplayName(normalized.fullName);
      return normalized;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_mapAuthCode(e.code));
    } catch (_) {
      throw const AuthFailure('Unable to update profile.');
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _remote.sendPasswordReset(email);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_mapAuthCode(e.code));
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _remote.signOut();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_mapAuthCode(e.code));
    }
  }

  String _mapAuthCode(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Email address is invalid.';
      case 'email-already-in-use':
        return 'Email already in use. Try signing in instead.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      default:
        return 'Authentication error ($code). Please try again.';
    }
  }
}
