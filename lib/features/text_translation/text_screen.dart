import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors.dart';
import '../../core/l10n.dart';
import '../../core/languages.dart';
import '../../core/settings.dart';
import '../conversation/widgets.dart';
import '../translation/critical_info_guard.dart';
import '../translation/translation_provider.dart';
import '../tts/tts_service.dart';

class TextScreen extends ConsumerStatefulWidget {
  const TextScreen({super.key});
  @override
  ConsumerState<TextScreen> createState() => _TextScreenState();
}

class _TextScreenState extends ConsumerState<TextScreen> {
  final _input = TextEditingController();
  AppLang _from = AppLang.ar;
  String _result = '';
  GuardResult _guard = const GuardResult();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _translate() async {
    final text = _input.text.trim();
    if (text.isEmpty || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await ref.read(translationProvider).translate(text, _from, _from.other);
      if (!mounted) return;
      setState(() {
        _result = r;
        _guard = CriticalInfoGuard.check(text, r);
      });
    } on AppFailure catch (e) {
      if (mounted) setState(() => _error = e.key);
    } catch (_) {
      if (mounted) setState(() => _error = 'err_translate');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _speak(String text, AppLang lang) async {
    try {
      await ref
          .read(ttsProvider)
          .speak(text, lang, rate: ref.read(settingsProvider).speechRate);
    } on AppFailure catch (e) {
      if (mounted) setState(() => _error = e.key);
    }
  }

  void _swap() => setState(() {
        _from = _from.other;
        if (_result.isNotEmpty) {
          _input.text = _result;
          _result = '';
          _guard = const GuardResult();
        }
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('nav_text'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          Expanded(
              child: Text(_from.nativeName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium)),
          IconButton.filledTonal(
              onPressed: _busy ? null : _swap,
              icon: const Icon(Icons.swap_horiz),
              tooltip: context.tr('swap')),
          Expanded(
              child: Text(_from.other.nativeName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium)),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _input,
          minLines: 3,
          maxLines: 8,
          textDirection: _from.direction,
          style: const TextStyle(fontSize: 20),
          decoration: InputDecoration(
              border: const OutlineInputBorder(), hintText: context.tr('input_hint')),
        ),
        const SizedBox(height: 8),
        Row(children: [
          IconButton(
              onPressed: () => _speak(_input.text, _from),
              icon: const Icon(Icons.volume_up_outlined),
              tooltip: context.tr('speak_source')),
          const Spacer(),
          FilledButton.icon(
              onPressed: _busy ? null : _translate,
              icon: const Icon(Icons.translate),
              label: Text(context.tr('translate'))),
        ]),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) ...[
          const SizedBox(height: 8),
          MessageBar(textKey: _error!, onClose: () => setState(() => _error = null)),
        ],
        if (_result.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                LangText(_result, _from.other,
                    style: Theme.of(context).textTheme.headlineSmall),
                GuardWarnings(_guard),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  IconButton(
                      onPressed: () => _speak(_result, _from.other),
                      icon: const Icon(Icons.volume_up),
                      tooltip: context.tr('speak_target')),
                  IconButton(
                      onPressed: () => copyText(context, _result),
                      icon: const Icon(Icons.copy),
                      tooltip: context.tr('copy')),
                ]),
              ]),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text(context.tr('disclaimer'), style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}
