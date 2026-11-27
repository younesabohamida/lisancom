import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/languages.dart';
import '../../core/settings.dart';
import 'conversation_controller.dart';
import 'widgets.dart';

class ConversationScreen extends ConsumerWidget {
  const ConversationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(conversationProvider);
    final ctrl = ref.read(conversationProvider.notifier);
    final senior = ref.watch(settingsProvider.select((s) => s.seniorMode));

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('app_name')),
        actions: [
          if (st.phase == ConvPhase.speaking)
            IconButton(
                onPressed: ctrl.stopSpeaking,
                icon: const Icon(Icons.volume_off),
                tooltip: context.tr('stop')),
          if (st.entries.isNotEmpty)
            IconButton(
                onPressed: ctrl.clear,
                icon: const Icon(Icons.delete_sweep_outlined),
                tooltip: context.tr('clear')),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          const ReadinessBanner(),
          Expanded(
            child: st.entries.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(context.tr('tap_to_start'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge),
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: st.entries.length,
                    itemBuilder: (_, i) => _EntryCard(
                        st.entries[st.entries.length - 1 - i],
                        onReplay: ctrl.replay),
                  ),
          ),
          if (st.phase == ConvPhase.listening ||
              st.phase == ConvPhase.recognizing ||
              st.phase == ConvPhase.translating)
            _LiveStrip(st),
          if (st.errorKey != null)
            MessageBar(textKey: st.errorKey!, onClose: ctrl.dismissMessage)
          else if (st.infoKey != null)
            MessageBar(textKey: st.infoKey!, isError: false, onClose: ctrl.dismissMessage),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(children: [
              for (final l in AppLang.values) ...[
                Expanded(child: _TalkButton(lang: l, state: st, senior: senior)),
                if (l != AppLang.values.last) const SizedBox(width: 12),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

class _TalkButton extends ConsumerWidget {
  const _TalkButton({required this.lang, required this.state, required this.senior});
  final AppLang lang;
  final ConvState state;
  final bool senior;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listeningHere = state.phase == ConvPhase.listening && state.active == lang;
    final enabled = !state.busy &&
        !(state.phase == ConvPhase.listening && state.active != lang);
    final label = listeningHere
        ? context.tr('stop')
        : context.tr(lang == AppLang.ar ? 'talk_ar' : 'talk_de');
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        height: senior ? 128 : 96,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: listeningHere
                ? cs.error
                : (lang == AppLang.ar ? cs.primary : cs.tertiary),
            foregroundColor: listeningHere
                ? cs.onError
                : (lang == AppLang.ar ? cs.onPrimary : cs.onTertiary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
          onPressed:
              enabled ? () => ref.read(conversationProvider.notifier).toggle(lang) : null,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(listeningHere ? Icons.stop_rounded : Icons.mic_rounded,
                size: senior ? 44 : 36),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                textDirection: lang.direction,
                style: TextStyle(fontSize: senior ? 22 : 18)),
          ]),
        ),
      ),
    );
  }
}

class _LiveStrip extends StatelessWidget {
  const _LiveStrip(this.st);
  final ConvState st;

  @override
  Widget build(BuildContext context) {
    final key = switch (st.phase) {
      ConvPhase.listening => 'listening',
      ConvPhase.recognizing => 'recognizing',
      _ => 'translating',
    };
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.graphic_eq),
          const SizedBox(width: 8),
          Expanded(
              child: Text(context.tr(key),
                  style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 8),
        LinearProgressIndicator(
            value: st.phase == ConvPhase.listening ? st.level : null, minHeight: 6),
        if (st.partial.isNotEmpty && st.active != null) ...[
          const SizedBox(height: 8),
          Text('${context.tr('partial')}:',
              style: Theme.of(context).textTheme.labelMedium),
          // Interim text is visually distinct (italic) from final results.
          Text(st.partial,
              textDirection: st.active!.direction,
              style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 18)),
        ],
      ]),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard(this.e, {required this.onReplay});
  final ConvEntry e;
  final void Function(ConvEntry) onReplay;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${e.from.nativeName} → ${e.to.nativeName}', style: t.labelMedium),
          const SizedBox(height: 4),
          LangText(e.original, e.from, style: t.bodyLarge),
          const Divider(height: 20),
          LangText(e.translated, e.to,
              style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
          GuardWarnings(e.guard),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton.icon(
                onPressed: () => onReplay(e),
                icon: const Icon(Icons.replay),
                label: Text(context.tr('replay'))),
            TextButton.icon(
                onPressed: () => copyText(context, e.translated),
                icon: const Icon(Icons.copy),
                label: Text(context.tr('copy'))),
          ]),
        ]),
      ),
    );
  }
}
