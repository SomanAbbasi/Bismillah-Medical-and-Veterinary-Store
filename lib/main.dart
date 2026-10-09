import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/database/database_provider.dart';
import 'core/notifications/notification_service.dart';
import 'core/notifications/expiry_reminder_scheduler.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/presentation/app_lock_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enforce preferred portrait orientation on mobile phones
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set up transparent status bar with dark icons
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize notifications subsystem
  final notifService = NotificationService();
  await notifService.initialize();

  runApp(
    const ProviderScope(
      child: BismillahStoreApp(),
    ),
  );
}

class BismillahStoreApp extends ConsumerStatefulWidget {
  const BismillahStoreApp({super.key});

  @override
  ConsumerState<BismillahStoreApp> createState() => _BismillahStoreAppState();
}

class _BismillahStoreAppState extends ConsumerState<BismillahStoreApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reconcileReminders();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reconcileReminders();
    }
  }

  Future<void> _reconcileReminders() async {
    try {
      final db = ref.read(databaseProvider);
      final scheduler = ref.read(expiryReminderSchedulerProvider);
      await scheduler.reconcile(db);
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'BismillahStore',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
      builder: (context, child) {
        return AppLockScreen(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
