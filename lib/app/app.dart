import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../features/conversation/conversation_screen.dart';
import '../features/phrasebook/phrasebook_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/text_translation/text_screen.dart';

class LisancomApp extends ConsumerWidget {
  const LisancomApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    return MaterialApp(
      onGenerateTitle: (c) => c.tr('app_name'),
      debugShowCheckedModeBanner: false,
      locale: s.uiLocale == null ? null : Locale(s.uiLocale!),
      supportedLocales: S.supported,
      localizationsDelegates: const [
        SDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Device language on first run; German as fallback.
      localeResolutionCallback: (device, supported) =>
          supported.firstWhere((l) => l.languageCode == device?.languageCode,
              orElse: () => S.fallback),
      themeMode: s.themeMode,
      theme: buildTheme(Brightness.light, highContrast: s.seniorMode),
      darkTheme: buildTheme(Brightness.dark, highContrast: s.seniorMode),
      builder: (context, child) {
        if (!s.seniorMode) return child!;
        final mq = MediaQuery.of(context);
        final scale = (mq.textScaler.scale(1) * 1.3).clamp(1.0, 2.2);
        return MediaQuery(
            data: mq.copyWith(textScaler: TextScaler.linear(scale)), child: child!);
      },
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  static const _pages = [
    ConversationScreen(),
    TextScreen(),
    PhrasebookScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: _index, children: _pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            NavigationDestination(
                icon: const Icon(Icons.forum_outlined),
                selectedIcon: const Icon(Icons.forum),
                label: context.tr('nav_conversation')),
            NavigationDestination(
                icon: const Icon(Icons.text_fields),
                label: context.tr('nav_text')),
            NavigationDestination(
                icon: const Icon(Icons.menu_book_outlined),
                selectedIcon: const Icon(Icons.menu_book),
                label: context.tr('nav_phrasebook')),
            NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings),
                label: context.tr('nav_settings')),
          ],
        ),
      );
}
