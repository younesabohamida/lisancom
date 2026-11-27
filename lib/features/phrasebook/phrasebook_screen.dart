import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors.dart';
import '../../core/l10n.dart';
import '../../core/languages.dart';
import '../../core/settings.dart';
import '../tts/tts_service.dart';

class PhraseCategory {
  const PhraseCategory(this.icon, this.titles, this.phrases);
  final String icon;
  final Map<String, String> titles;
  final List<Map<String, String>> phrases;
}

List<PhraseCategory> parsePhrasebook(String json) => [
      for (final c in (jsonDecode(json)['categories'] as List).cast<Map<String, dynamic>>())
        PhraseCategory(
          c['icon'] as String,
          (c['title'] as Map).cast<String, String>(),
          [for (final p in c['phrases'] as List) (p as Map).cast<String, String>()],
        ),
    ];

final phrasebookProvider = FutureProvider<List<PhraseCategory>>((ref) async =>
    parsePhrasebook(await rootBundle.loadString('assets/phrasebooks/phrases.json')));

class PhrasebookScreen extends ConsumerWidget {
  const PhrasebookScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = S.of(context).lang;
    final data = ref.watch(phrasebookProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('nav_phrasebook'))),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(context.tr('err_generic'))),
        data: (cats) => ListView(children: [
          Padding(
              padding: const EdgeInsets.all(16), child: Text(context.tr('phrase_tap'))),
          for (final c in cats)
            ExpansionTile(
              leading: Text(c.icon, style: const TextStyle(fontSize: 26)),
              title: Text(c.titles[ui] ?? c.titles['de']!,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              children: [
                for (final p in c.phrases)
                  ListTile(
                    title: Text(p['ar']!, textDirection: TextDirection.rtl),
                    subtitle: Text(p['de']!, textDirection: TextDirection.ltr),
                    onTap: () => _show(context, ref, p),
                  ),
              ],
            ),
        ]),
      ),
    );
  }

  void _show(BuildContext context, WidgetRef ref, Map<String, String> p) {
    Future<void> say(AppLang l) async {
      try {
        await ref
            .read(ttsProvider)
            .speak(p[l.code]!, l, rate: ref.read(settingsProvider).speechRate);
      } on AppFailure catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(context.tr(e.key))));
        }
      }
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final l in AppLang.values) ...[
              Text(p[l.code]!,
                  textDirection: l.direction,
                  textAlign: TextAlign.center,
                  style: Theme.of(ctx).textTheme.headlineMedium),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                  onPressed: () => say(l),
                  icon: const Icon(Icons.volume_up),
                  label: Text(l.nativeName)),
              const SizedBox(height: 20),
            ],
          ]),
        ),
      ),
    );
  }
}
