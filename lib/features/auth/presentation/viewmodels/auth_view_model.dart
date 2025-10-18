import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/user_profile.dart';
import '../../domain/errors/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';

enum AuthOperation {
  login,
  register,
  updateProfile,
  resetPassword,
  logout,
}

class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._repository, this._preferences);

  final AuthRepository _repository;
  final SharedPreferences _preferences;

  static const _rememberKey = 'remember_me';
  static const _rememberEmailKey = 'remember_me_email';

  UserProfile? _user;
  bool _initRequested = false;
  bool _initialized = false;
  String? _errorMessage;
  String? _infoMessage;
  bool _rememberMe = false;
  String? _rememberedEmail;
  StreamSubscription<UserProfile?>? _subscription;
  final Set<AuthOperation> _busy = <AuthOperation>{};

  bool get isInitialized => _initialized;
  bool get isAuthenticated => _user != null;
  UserProfile? get user => _user;
  bool get isAdmin => _user?.isAdmin ?? false;
  String? get errorMessage => _errorMessage;
  String? get infoMessage => _infoMessage;
  bool get rememberMe => _rememberMe;
  String? get rememberedEmail => _rememberedEmail;

  bool isBusy(AuthOperation operation) => _busy.contains(operation);

  Future<void> init() async {
    if (_initRequested) return;
    _initRequested = true;

    _rememberMe = _preferences.getBool(_rememberKey) ?? false;
    _rememberedEmail =
        _rememberMe ? _preferences.getString(_rememberEmailKey) : null;

    _subscription = _repository.userStream().listen(
      (profile) {
        _user = profile;
        _initialized = true;
        notifyListeners();
      },
      onError: (_) {
        _errorMessage = 'Unable to load account information.';
        _initialized = true;
        notifyListeners();
      },
    );
  }

  Future<bool> login(String email, String password,
      {required bool remember}) async {
    _setBusy(AuthOperation.login, true);
    _setError(null);
    try {
      await _repository.login(email.trim(), password.trim());
      await _persistRememberPreference(remember, email.trim());
      _setInfo('Welcome back!');
      return true;
    } on AuthFailure catch (e) {
      _setError(e.message);
      return false;
    } catch (_) {
      _setError('Something went wrong while signing in.');
      return false;
    } finally {
      _setBusy(AuthOperation.login, false);
    }
  }

  Future<bool> register({
    required String fullName,
    required String email,
    required String employeeId,
    required String department,
    required String password,
    String role = 'member',
  }) async {
    _setBusy(AuthOperation.register, true);
    _setError(null);
    try {
      final profile = await _repository.register(
        fullName: fullName.trim(),
        email: email.trim(),
        employeeId: employeeId.trim(),
        department: department.trim(),
        password: password.trim(),
        role: role,
      );
      _user = profile;
      await _persistRememberPreference(true, email.trim());
      _setInfo('Account created successfully.');
      return true;
    } on AuthFailure catch (e) {
      _setError(e.message);
      return false;
    } catch (_) {
      _setError('Unable to create account. Please try again.');
      return false;
    } finally {
      _setBusy(AuthOperation.register, false);
    }
  }

  Future<bool> updateProfile(UserProfile profile) async {
    _setBusy(AuthOperation.updateProfile, true);
    _setError(null);
    try {
      final updated = await _repository.updateProfile(profile);
      _user = updated;
      _setInfo('Profile updated.');
      notifyListeners();
      return true;
    } on AuthFailure catch (e) {
      _setError(e.message);
      return false;
    } catch (_) {
      _setError('Unable to update profile.');
      return false;
    } finally {
      _setBusy(AuthOperation.updateProfile, false);
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    _setBusy(AuthOperation.resetPassword, true);
    _setError(null);
    try {
      await _repository.sendPasswordReset(email.trim());
      _setInfo('Password reset email sent.');
      return true;
    } on AuthFailure catch (e) {
      _setError(e.message);
      return false;
    } catch (_) {
      _setError('Unable to send password reset email.');
      return false;
    } finally {
      _setBusy(AuthOperation.resetPassword, false);
    }
  }

  Future<bool> logout() async {
    _setBusy(AuthOperation.logout, true);
    _setError(null);
    try {
      await _repository.logout();
      _setInfo('Signed out.');
      return true;
    } on AuthFailure catch (e) {
      _setError(e.message);
      return false;
    } catch (_) {
      _setError('Unable to sign out.');
      return false;
    } finally {
      _setBusy(AuthOperation.logout, false);
    }
  }

  void clearMessages() {
    if (_errorMessage != null || _infoMessage != null) {
      _errorMessage = null;
      _infoMessage = null;
      notifyListeners();
    }
  }

  Future<void> setRememberMe(bool value) async {
    _rememberMe = value;
    await _preferences.setBool(_rememberKey, value);
    if (!value) {
      await _preferences.remove(_rememberEmailKey);
      _rememberedEmail = null;
    }
    notifyListeners();
  }

  Future<void> _persistRememberPreference(bool remember, String email) async {
    _rememberMe = remember;
    await _preferences.setBool(_rememberKey, remember);
    if (remember) {
      await _preferences.setString(_rememberEmailKey, email);
      _rememberedEmail = email;
    } else {
      await _preferences.remove(_rememberEmailKey);
      _rememberedEmail = null;
    }
    notifyListeners();
  }

  void _setBusy(AuthOperation operation, bool value) {
    final changed = value ? _busy.add(operation) : _busy.remove(operation);
    if (changed) {
      notifyListeners();
    }
  }

  void _setError(String? message) {
    if (_errorMessage != message) {
      _errorMessage = message;
      notifyListeners();
    }
  }

  void _setInfo(String? message) {
    if (_infoMessage != message) {
      _infoMessage = message;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
