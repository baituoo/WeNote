import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../l10n/app_localizations.dart';
import '../providers/app_providers.dart';
import '../widgets/session_list.dart';
import '../widgets/chat_view.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 600) {
            return const _DesktopLayout();
          }
          return const _MobileLayout();
        },
      ),
    );
  }
}

class _DesktopLayout extends ConsumerWidget {
  const _DesktopLayout();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.loc;

    return Row(
      children: [
        SizedBox(
          width: 320,
          child: Material(
            elevation: 1,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      children: [
                        const Icon(Icons.chat_bubble_rounded, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            loc.appTitle,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SettingsScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.settings_rounded),
                          tooltip: loc.settings,
                        ),
                        IconButton(
                          onPressed: () {
                            final current =
                                ref.read(themeModeProvider);
                            ref.read(themeModeProvider.notifier).state =
                                current == ThemeMode.dark
                                    ? ThemeMode.light
                                    : ThemeMode.dark;
                          },
                          icon: Icon(
                            ref.watch(themeModeProvider) == ThemeMode.dark
                                ? Icons.light_mode_rounded
                                : Icons.dark_mode_rounded,
                          ),
                          tooltip: loc.toggleTheme,
                        ),
                      ],
                    ),
                  ),
                ),
                const Expanded(child: SessionList()),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        const Expanded(child: ChatView()),
      ],
    );
  }
}

class _MobileLayout extends ConsumerWidget {
  const _MobileLayout();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSessionId = ref.watch(currentSessionIdProvider);
    final loc = ref.loc;

    if (currentSessionId != null) {
      return const ChatView();
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                const Icon(Icons.chat_bubble_rounded, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    loc.appTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.settings_rounded),
                  tooltip: loc.settings,
                ),
                IconButton(
                  onPressed: () {
                    final current = ref.read(themeModeProvider);
                    ref.read(themeModeProvider.notifier).state =
                        current == ThemeMode.dark
                            ? ThemeMode.light
                            : ThemeMode.dark;
                  },
                  icon: Icon(
                    ref.watch(themeModeProvider) == ThemeMode.dark
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                  ),
                  tooltip: loc.toggleTheme,
                ),
              ],
            ),
          ),
        ),
        const Expanded(child: SessionList()),
      ],
    );
  }
}
