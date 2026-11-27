import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/languages.dart';
import '../model_manager/model_manager_screen.dart';
import '../model_manager/model_service.dart';
import '../translation/critical_info_guard.dart';

/// Offline readiness indicator; never relies on colour alone (icon + text).
class ReadinessBanner extends ConsumerWidget {
  const ReadinessBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = ref.watch(offlineReadyProvider);
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: ready ? cs.secondaryContainer : cs.tertiaryContainer,
      child: InkWell(
        onTap: ready ? null : () => openModelManager(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Icon(ready ? Icons.cloud_off : Icons.download_for_offline),
            const SizedBox(width: 12),
            Expanded(
              child: Text(context.tr(ready ? 'ready_offline' : 'not_ready_offline'),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            if (!ready) const Icon(Icons.chevron_right),
          ]),
        ),
      ),
    );
  }
}

void openModelManager(BuildContext context) => Navigator.of(context)
    .push(MaterialPageRoute<void>(builder: (_) => const ModelManagerScreen()));

class GuardWarnings extends StatelessWidget {
  const GuardWarnings(this.guard, {super.key});
  final GuardResult guard;

  @override
  Widget build(BuildContext context) {
    if (!guard.hasWarnings) return const SizedBox.shrink();
    final style = TextStyle(color: Theme.of(context).colorScheme.error);
    Widget row(String text) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.warning_amber_rounded, size: 20, color: style.color),
            const SizedBox(width: 6),
            Expanded(child: Text(text, style: style)),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (guard.missingNumbers.isNotEmpty)
        row(context.tr('warn_numbers', {'nums': guard.missingNumbers.join(', ')})),
      if (guard.negationLost) row(context.tr('warn_negation')),
    ]);
  }
}

Future<void> copyText(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.tr('copied'))));
  }
}

class LangText extends StatelessWidget {
  const LangText(this.text, this.lang, {super.key, this.style});
  final String text;
  final AppLang lang;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => SelectableText(
        text,
        textDirection: lang.direction,
        textAlign: lang.rtl ? TextAlign.right : TextAlign.left,
        style: style,
      );
}

class MessageBar extends StatelessWidget {
  const MessageBar({super.key, required this.textKey, this.isError = true, this.onClose});
  final String textKey;
  final bool isError;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: isError ? cs.errorContainer : cs.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
        child: Row(children: [
          Icon(isError ? Icons.error_outline : Icons.info_outline,
              color: isError ? cs.onErrorContainer : null),
          const SizedBox(width: 12),
          Expanded(
            child: Text(context.tr(textKey),
                style: TextStyle(color: isError ? cs.onErrorContainer : null)),
          ),
          if (textKey == 'err_model_missing')
            TextButton(
                onPressed: () => openModelManager(context),
                child: Text(context.tr('open_models'))),
          if (onClose != null)
            IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip),
        ]),
      ),
    );
  }
}
