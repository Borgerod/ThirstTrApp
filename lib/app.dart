import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/providers.dart';
import 'features/home/home_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/tasks/tasks_screen.dart';
import 'services/notification_service.dart';

/// Brand seed — a leafy green.
const _seed = Color(0xFF2E7D52);

class ThirstTrApp extends ConsumerStatefulWidget {
  const ThirstTrApp({super.key});
  @override
  ConsumerState<ThirstTrApp> createState() => _ThirstTrAppState();
}

class _ThirstTrAppState extends ConsumerState<ThirstTrApp> {
  @override
  void initState() {
    super.initState();
    // Route notification confirm/postpone presses into the tasks controller.
    NotificationService.instance.onAction = (action) {
      ref.read(tasksProvider.notifier).handleAction(action);
    };
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ThirstTrApp',
      debugShowCheckedModeBanner: false,
      // Activate Norwegian (Bokmål) across Material widgets, date pickers, etc.
      locale: const Locale('nb'),
      supportedLocales: const [Locale('nb'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _seed),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const RootShell(),
    );
  }
}

/// Bottom-nav shell: Plants / Tasks / Settings.
class RootShell extends ConsumerStatefulWidget {
  const RootShell({super.key});
  @override
  ConsumerState<RootShell> createState() => _RootShellState();
}

class _RootShellState extends ConsumerState<RootShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final dueCount = ref.watch(tasksProvider.notifier).dueSoon
        .where((t) => t.isOverdue || t.isDueWithin(const Duration(days: 1)))
        .length;

    final pages = const [HomeScreen(), TasksScreen(), SettingsScreen()];

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(
              icon: Icon(Icons.local_florist_outlined),
              selectedIcon: Icon(Icons.local_florist),
              label: 'Planter'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: dueCount > 0,
              label: Text('$dueCount'),
              child: const Icon(Icons.task_alt_outlined),
            ),
            selectedIcon: const Icon(Icons.task_alt),
            label: 'Oppgaver',
          ),
          const NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Innstillinger'),
        ],
      ),
    );
  }
}
