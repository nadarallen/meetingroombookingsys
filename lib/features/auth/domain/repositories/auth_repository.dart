import '../entities/user_profile.dart';

abstract class AuthRepository {
  Stream<UserProfile?> userStream();

  Future<void> login(String email, String password);

  Future<UserProfile> register({
    required String fullName,
    required String email,
    required String employeeId,
    required String department,
    required String password,
    String role = 'member',
  });

  Future<UserProfile> updateProfile(UserProfile profile);

  Future<void> sendPasswordReset(String email);

  Future<void> logout();
}
