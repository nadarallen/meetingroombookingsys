import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/database/database_sync_manager.dart';
import 'core/database/firestore_service.dart';
import 'core/database/local_database.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_notifier.dart';
import 'features/auth/data/datasources/auth_remote_datasource.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/presentation/viewmodels/auth_view_model.dart';
import 'shared/services/notification_service.dart';
import 'shared/services/ai/ai_chat_service.dart';
import 'shared/services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService.instance.initialize();
  final prefs = await SharedPreferences.getInstance();

  final authRepository = AuthRepositoryImpl(AuthRemoteDataSource());
  final localDatabase = LocalDatabase.instance;
  final firestoreService = FirestoreService();
  final storageService = StorageService();
  final aiChatService = AiChatService();
  final syncManager = DatabaseSyncManager(
    localDatabase: localDatabase,
    remoteService: firestoreService,
  );

  try {
    await syncManager.initialize();
    await syncManager.pushPendingChanges();
  } catch (_) {
    // Offline mode: pending changes remain queued locally.
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier(prefs)..load()),
        ChangeNotifierProvider(
            create: (_) => AuthViewModel(authRepository, prefs)..init()),
        Provider<DatabaseSyncManager>.value(value: syncManager),
        Provider<LocalDatabase>.value(value: localDatabase),
        Provider<FirestoreService>.value(value: firestoreService),
        Provider<StorageService>.value(value: storageService),
        Provider<AiChatService>.value(value: aiChatService),
      ],
      child: const MeetingRoomApp(),
    ),
  );
}

class MeetingRoomApp extends StatefulWidget {
  const MeetingRoomApp({super.key});

  @override
  State<MeetingRoomApp> createState() => _MeetingRoomAppState();
}

class _MeetingRoomAppState extends State<MeetingRoomApp> {
  GoRouter? _router;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _router ??= AppRouter(context.read<AuthViewModel>()).router;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeNotifier>();
    final router = _router;

    return MaterialApp.router(
      title: 'Meeting Room Booking',
      debugShowCheckedModeBanner: false,
      themeMode: theme.themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
