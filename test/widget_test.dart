import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meeting_room_booking/core/theme/theme_notifier.dart';
import 'package:meeting_room_booking/features/auth/domain/entities/user_profile.dart';
import 'package:meeting_room_booking/features/auth/domain/repositories/auth_repository.dart';
import 'package:meeting_room_booking/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:meeting_room_booking/main.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Splash screen renders while auth initializes', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final fakeRepo = _FakeAuthRepository();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeNotifier(prefs)..load()),
          ChangeNotifierProvider(
              create: (_) => AuthViewModel(fakeRepo, prefs)..init()),
        ],
        child: const MeetingRoomApp(),
      ),
    );

    await tester.pump();

    expect(find.byType(FlutterLogo), findsOneWidget);
  });
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository() {
    // Emit unauthenticated state once listeners attach.
    Future<void>.microtask(() => _controller.add(null));
  }

  final StreamController<UserProfile?> _controller =
      StreamController<UserProfile?>.broadcast();

  @override
  Stream<UserProfile?> userStream() => _controller.stream;

  @override
  Future<void> login(String email, String password) =>
      throw UnimplementedError();

  @override
  Future<UserProfile> register({
    required String fullName,
    required String email,
    required String employeeId,
    required String department,
    required String password,
    String role = 'member',
  }) =>
      throw UnimplementedError();

  @override
  Future<UserProfile> updateProfile(UserProfile profile) =>
      throw UnimplementedError();

  @override
  Future<void> sendPasswordReset(String email) => throw UnimplementedError();

  @override
  Future<void> logout() => throw UnimplementedError();
}
