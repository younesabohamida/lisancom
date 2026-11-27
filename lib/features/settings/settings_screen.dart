import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/settings.dart';
import '../conversation/widgets.dart';
import '../model_manager/model_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    void up(AppSettings n) => ref.read(settingsProvider.notifier).update(n);
    final catalog = ref.watch(catalogProvider).value;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('nav_settings'))),
      body: ListView(children: [
        ListTile(
          leading: const Icon(Icons.download_for_offline),
          title: Text(context.tr('open_models')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => openModelManager(context),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.language),
          title: Text(context.tr('settings_ui_lang')),
          trailing: DropdownButton<String?>(
            value: s.uiLocale,
            onChanged: (v) => up(s.copyWith(uiLocale: v)),
            items: [
              DropdownMenuItem(value: null, child: Text(context.tr('settings_system'))),
              const DropdownMenuItem(value: 'ar', child: Text('العربية')),
              const DropdownMenuItem(value: 'de', child: Text('Deutsch')),
            ],
          ),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.elderly),
          title: Text(context.tr('settings_senior')),
          subtitle: Text(context.tr('settings_senior_sub')),
          value: s.seniorMode,
          onChanged: (v) => up(s.copyWith(seniorMode: v)),
        ),
        ListTile(
          leading: const Icon(Icons.dark_mode_outlined),
          title: Text(context.tr('settings_theme')),
          trailing: DropdownButton<ThemeMode>(
            value: s.themeMode,
            onChanged: (v) => up(s.copyWith(themeMode: v)),
            items: [
              DropdownMenuItem(value: ThemeMode.system, child: Text(context.tr('theme_system'))),
              DropdownMenuItem(value: ThemeMode.light, child: Text(context.tr('theme_light'))),
              DropdownMenuItem(value: ThemeMode.dark, child: Text(context.tr('theme_dark'))),
            ],
          ),
        ),
        const Divider(),
        SwitchListTile(
          secondary: const Icon(Icons.record_voice_over_outlined),
          title: Text(context.tr('settings_autospeak')),
          value: s.autoSpeak,
          onChanged: (v) => up(s.copyWith(autoSpeak: v)),
        ),
        ListTile(
          leading: const Icon(Icons.speed),
          title: Text(context.tr('settings_rate')),
          subtitle: Slider(
            value: s.speechRate,
            min: 0.2,
            max: 0.8,
            divisions: 6,
            label: s.speechRate.toStringAsFixed(1),
            onChanged: (v) => up(s.copyWith(speechRate: v)),
          ),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.mic_none),
          title: Text(context.tr('settings_stt')),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<SttEngine>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: SttEngine.whisper, label: Text(context.tr('stt_whisper'))),
              ButtonSegment(value: SttEngine.native, label: Text(context.tr('stt_native'))),
            ],
            selected: {s.sttEngine},
            onSelectionChanged: (v) => up(s.copyWith(sttEngine: v.first)),
          ),
        ),
        if (s.sttEngine == SttEngine.whisper && catalog != null)
          ListTile(
            title: Text(context.tr('settings_whisper_model')),
            trailing: DropdownButton<String>(
              value: catalog.byId(s.whisperModelId) != null ? s.whisperModelId : null,
              onChanged: (v) => up(s.copyWith(whisperModelId: v)),
              items: [
                for (final w in catalog.whisper)
                  DropdownMenuItem(value: w.id, child: Text(w.name)),
              ],
            ),
          ),
        SwitchListTile(
          secondary: const Icon(Icons.shield_outlined),
          title: Text(context.tr('settings_offline_only')),
          subtitle: Text(context.tr('settings_offline_only_sub')),
          value: s.offlineOnly,
          onChanged: (v) => up(s.copyWith(offlineOnly: v)),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: Text(context.tr('settings_privacy')),
          subtitle: Text(context.tr('privacy_text')),
        ),
        ListTile(
          leading: const Icon(Icons.info_outline),
          subtitle: Text(context.tr('disclaimer')),
        ),
      ]),
    );
  }
}
