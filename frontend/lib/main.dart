import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_social_media/core/router/app_router.dart';
import 'package:campus_social_media/core/theme/app_theme.dart';
import 'package:campus_social_media/features/auth/presentation/auth_provider.dart';
import 'package:campus_social_media/core/services/error_service.dart';
import 'package:media_kit/media_kit.dart';

void main() {
  print('-------- APP STARTING --------');
  try {
    WidgetsFlutterBinding.ensureInitialized();
    MediaKit.ensureInitialized();
    
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      print('FLUTTER ERROR: ${details.exception}');
      print('STACK TRACE: ${details.stack}');
    };
    
    runApp(
      const ProviderScope(
        child: CampusSocialMediaApp(),
      ),
    );
  } catch (e, stack) {
    print('CRITICAL STARTUP ERROR: $e');
    print('STACK: $stack');
  }
}

class CampusSocialMediaApp extends ConsumerWidget {
  const CampusSocialMediaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    
    // Check auth on startup
    ref.listen(authStateProvider, (_, __) {}); // Keep provider alive?
    
    // Trigger initial auth check
    // We can use a FutureProvider or just call it in initState of a wrapper, 
    // but doing it here might be called multiple times. 
    // Best place is in the main function or a startup provider.
    
    // Actually, let's use a specialized provider/widget for initialization
    return const AppInitializer();
  }
}

class AppInitializer extends ConsumerStatefulWidget {
  const AppInitializer({super.key});

  @override
  ConsumerState<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends ConsumerState<AppInitializer> {
  @override
  void initState() {
    super.initState();
    // Perform initial auth check
    // Auth check is now handled by SplashScreen
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   ref.read(authStateProvider.notifier).checkAuth();
    // });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Campus Social',
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
