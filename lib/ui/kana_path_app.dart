import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'library_screen.dart';
import 'settings_screen.dart';
import 'theme.dart';
import 'ui_contract.dart';

class KanaPathApp extends StatelessWidget {
  const KanaPathApp({super.key, required this.controller});

  final LearningController controller;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Kana Path',
    debugShowCheckedModeBanner: false,
    theme: kanaTheme(Brightness.light),
    darkTheme: kanaTheme(Brightness.dark),
    themeMode: ThemeMode.system,
    home: _AppShell(controller: controller),
  );
}

class _AppShell extends StatefulWidget {
  const _AppShell({required this.controller});
  final LearningController controller;

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      if (controller.loading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Text(
                  'あ',
                  style: TextStyle(color: Colors.white, fontSize: 22),
                ),
              ),
              const SizedBox(width: 11),
              const Text(
                'Kana Path',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Tooltip(
                message: 'Your progress stays on this device',
                child: Icon(
                  Icons.shield_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              if (controller.error != null)
                MaterialBanner(
                  content: Text(controller.error!),
                  leading: const Icon(Icons.info_outline),
                  actions: [
                    TextButton(
                      onPressed: controller.clearError,
                      child: const Text('Dismiss'),
                    ),
                  ],
                ),
              Expanded(
                child: IndexedStack(
                  index: _tab,
                  children: [
                    HomeScreen(controller: controller),
                    LibraryScreen(controller: controller),
                    SettingsScreen(controller: controller),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (index) => setState(() => _tab = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore),
              label: 'Learn',
            ),
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view_rounded),
              label: 'Library',
            ),
            NavigationDestination(
              icon: Icon(Icons.tune_outlined),
              selectedIcon: Icon(Icons.tune),
              label: 'Settings',
            ),
          ],
        ),
      );
    },
  );
}
