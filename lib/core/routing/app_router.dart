import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/profile_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/viewmodels/auth_view_model.dart';
import '../../features/bookings/presentation/pages/booking_list_page.dart';
import '../../features/bookings/presentation/pages/new_booking_page.dart';
import '../../features/bookings/presentation/viewmodels/booking_view_model.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/rooms/presentation/pages/room_list_page.dart';
import '../../features/splash/splash_page.dart';
import '../database/database_sync_manager.dart';
import '../database/local_database.dart';

class AppRouter {
  AppRouter(this._authViewModel);

  final AuthViewModel _authViewModel;

  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  late final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: _authViewModel,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final initialized = _authViewModel.isInitialized;
      final signedIn = _authViewModel.isAuthenticated;
      final isAuthRoute = location == '/auth/login' || location == '/auth/register';

      if (!initialized) {
        return location == '/splash' ? null : '/splash';
      }

      if (!signedIn && !isAuthRoute) {
        return '/auth/login';
      }

      if (signedIn && (isAuthRoute || location == '/splash')) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/auth/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/auth/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomePage(),
        routes: [
          GoRoute(
            path: 'rooms',
            builder: (context, state) => const RoomListPage(),
          ),
          GoRoute(
            path: 'bookings',
            builder: (context, state) => const BookingListPage(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) {
                  final extra = state.extra;
                  if (extra is BookingViewModel) {
                    return ChangeNotifierProvider<BookingViewModel>.value(
                      value: extra,
                      child: const NewBookingPage(),
                    );
                  }
                  return ChangeNotifierProvider<BookingViewModel>(
                    create: (context) => BookingViewModel(
                      syncManager: context.read<DatabaseSyncManager>(),
                      localDatabase: context.read<LocalDatabase>(),
                      currentUserId: () => context.read<AuthViewModel>().user?.uid,
                    )..load(),
                    child: const NewBookingPage(),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: 'profile',
            builder: (context, state) => const ProfilePage(),
          ),
        ],
      ),
    ],
  );
}
