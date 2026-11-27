import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lisancom/core/l10n.dart';
import 'package:lisancom/features/conversation/widgets.dart';
import 'package:lisancom/features/translation/critical_info_guard.dart';

Widget _app(Locale l, Widget child) => MaterialApp(
      locale: l,
      supportedLocales: S.supported,
      localizationsDelegates: const [
        SDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('guard warnings render localized, RTL for Arabic', (t) async {
    const g = GuardResult(missingNumbers: ['3'], negationLost: true);
    await t.pumpWidget(_app(const Locale('ar'), const GuardWarnings(g)));
    expect(find.textContaining('3'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsNWidgets(2));
    final dir = Directionality.of(t.element(find.byType(GuardWarnings)));
    expect(dir, TextDirection.rtl);

    await t.pumpWidget(_app(const Locale('de'), const GuardWarnings(g)));
    await t.pumpAndSettle();
    expect(find.textContaining('Verneinung'), findsOneWidget);
  });

  testWidgets('no warnings -> renders nothing', (t) async {
    await t.pumpWidget(_app(const Locale('de'), const GuardWarnings(GuardResult())));
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
  });
}
