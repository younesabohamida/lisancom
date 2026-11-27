import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/languages.dart';
import '../../core/settings.dart';
import 'model_service.dart';

class ModelManagerScreen extends ConsumerWidget {
  const ModelManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packs = ref.watch(modelServiceProvider);
    final svc = ref.read(modelServiceProvider.notifier);
    final catalog = ref.watch(catalogProvider).value;
    final selected = ref.watch(settingsProvider.select((s) => s.whisperModelId));

    String langName(String code) => switch (code) {
          'ar' => AppLang.ar.nativeName,
          'de' => AppLang.de.nativeName,
          _ => 'English',
        };

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('models_title')),
        actions: [
          IconButton(
              onPressed: svc.refresh,
              icon: const Icon(Icons.refresh),
              tooltip: context.tr('refresh')),
        ],
      ),
      body: packs.isEmpty || catalog == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.only(bottom: 24), children: [
              Padding(
                  padding: const EdgeInsets.all(16), child: Text(context.tr('models_intro'))),
              for (final c in ModelService.mlkitCodes)
                _PackTile(
                  state: packs[mlkitPackId(c)]!,
                  title: c == 'en'
                      ? context.tr('pack_translation_en')
                      : context.tr('pack_translation', {'lang': langName(c)}),
                  icon: Icons.translate,
                ),
              const Divider(),
              for (final w in catalog.whisper)
                if (packs[w.id] != null)
                  _PackTile(
                    state: packs[w.id]!,
                    title: context.tr('pack_whisper', {'name': w.name}),
                    subtitle: w.id == selected ? '✓ ${context.tr('settings_whisper_model')}' : null,
                    icon: Icons.mic,
                    canVerify: true,
                  ),
              const Divider(),
              for (final l in AppLang.values)
                ListTile(
                  leading: const Icon(Icons.record_voice_over),
                  title: Text(context.tr('pack_tts', {'lang': l.nativeName})),
                  subtitle: Text(context.tr(
                      (packs[ttsPackId(l)]?.installed ?? false)
                          ? 'tts_installed_offline'
                          : 'tts_missing')),
                  trailing: Icon((packs[ttsPackId(l)]?.installed ?? false)
                      ? Icons.check_circle
                      : Icons.help_outline),
                ),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(context.tr('tts_hint'),
                      style: Theme.of(context).textTheme.bodySmall)),
            ]),
    );
  }
}

class _PackTile extends ConsumerWidget {
  const _PackTile({
    required this.state,
    required this.title,
    required this.icon,
    this.subtitle,
    this.canVerify = false,
  });

  final PackState state;
  final String title;
  final String? subtitle;
  final IconData icon;
  final bool canVerify;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svc = ref.read(modelServiceProvider.notifier);
    final status = state.downloading
        ? context.tr('downloading')
        : context.tr(state.installed ? 'installed' : 'not_installed');
    final size = state.approxMB == null
        ? ''
        : ' · ${context.tr('size_mb', {'mb': '${state.approxMB}'})}';

    Future<void> confirmDownload() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.tr('confirm_download_title')),
          content: Text(ctx.tr('confirm_download_body', {'mb': '${state.approxMB ?? '?'}'})),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('cancel'))),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.tr('download'))),
          ],
        ),
      );
      if (ok == true) await svc.download(state.id);
    }

    Future<void> verify() async {
      final ok = await svc.verify(state.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr(ok ? 'verify_ok' : 'verify_bad'))));
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text([
          '$status$size',
          if (subtitle != null) subtitle!,
          if (state.errorKey != null) context.tr(state.errorKey!),
        ].join('\n')),
        isThreeLine: subtitle != null || state.errorKey != null,
        trailing: state.downloading
            ? (state.kind == PackKind.whisper
                ? IconButton(
                    onPressed: () => svc.cancel(state.id),
                    icon: const Icon(Icons.close),
                    tooltip: context.tr('cancel'))
                : null)
            : state.installed
                ? PopupMenuButton<String>(
                    onSelected: (v) => v == 'delete' ? svc.delete(state.id) : verify(),
                    itemBuilder: (ctx) => [
                      if (canVerify)
                        PopupMenuItem(value: 'verify', child: Text(ctx.tr('verify'))),
                      PopupMenuItem(value: 'delete', child: Text(ctx.tr('delete'))),
                    ],
                  )
                : FilledButton.tonal(
                    onPressed: confirmDownload,
                    child: Text(context.tr(state.hasPartial ? 'resume' : 'download'))),
      ),
      if (state.downloading)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LinearProgressIndicator(value: state.progress),
        ),
    ]);
  }
}
