import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'providers/app_providers.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  debugPrint('═══════════════════════════════════════════');
  debugPrint('[main] WeNote starting...');
  debugPrint('[main] Flutter binding init...');
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('[main] Window manager init...');
  await windowManager.ensureInitialized();
  await windowManager.setMinimumSize(const Size(800, 600));
  await windowManager.setSize(const Size(1100, 750));
  await windowManager.setTitle('微记');
  await windowManager.center();
  await windowManager.show();
  debugPrint('[main] Window ready');

  debugPrint('[main] Running app...');
  runApp(const ProviderScope(child: NoteChatApp()));
}

class NoteChatApp extends ConsumerStatefulWidget {
  const NoteChatApp({super.key});

  @override
  ConsumerState<NoteChatApp> createState() => _NoteChatAppState();
}

class _NoteChatAppState extends ConsumerState<NoteChatApp> {
  @override
  void initState() {
    super.initState();
    debugPrint('[WeNoteApp] initState — scheduling settings load...');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('[WeNoteApp] postFrameCallback — calling loadSettings...');
      _initSettings();
    });
  }

  Future<void> _initSettings() async {
    try {
      await loadSettings(ref);
    } catch (e, stack) {
      debugPrint('[WeNoteApp] _initSettings threw: $e');
      debugPrint('[WeNoteApp] Stack: $stack');
      ref.read(initErrorProvider.notifier).state =
          'Unexpected init error: $e';
      ref.read(settingsLoadedProvider.notifier).state = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final themeColor = ref.watch(themeColorProvider);
    final settingsLoaded = ref.watch(settingsLoadedProvider);
    final initError = ref.watch(initErrorProvider);

    final lightTheme = AppTheme.light(themeColor);
    final darkTheme = AppTheme.dark(themeColor);

    return MaterialApp(
      title: 'WeNote',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      builder: (context, child) {
        final textTheme = Theme.of(context).textTheme;
        return DefaultTextStyle(
          style: textTheme.bodyMedium!.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
          child: child!,
        );
      },
      home: settingsLoaded
          ? (initError != null ? _ErrorScreen(error: initError) : const HomeScreen())
          : _SplashScreen(error: initError),
    );
  }
}

/// Shown while the app is initializing.
class _SplashScreen extends StatelessWidget {
  final String? error;
  const _SplashScreen({this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (error == null) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                'Loading...',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Check terminal for debug output',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            ] else ...[
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shown when init succeeded but an error was recorded.
class _ErrorScreen extends StatelessWidget {
  final String error;
  const _ErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              Text(
                'App started with errors',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  // Allow the user to proceed anyway
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                  );
                },
                child: const Text('Continue anyway'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
