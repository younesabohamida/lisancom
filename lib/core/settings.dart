import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SttEngine { whisper, native }

class AppSettings {
  const AppSettings({
    this.uiLocale,
    this.seniorMode = false,
    this.themeMode = ThemeMode.system,
    this.speechRate = 0.45,
    this.autoSpeak = true,
    this.sttEngine = SttEngine.whisper,
    this.whisperModelId = 'whisper-base',
    this.offlineOnly = true,
  });

  final String? uiLocale; // null = follow device
  final bool seniorMode;
  final ThemeMode themeMode;
  final double speechRate;
  final bool autoSpeak;
  final SttEngine sttEngine;
  final String whisperModelId;
  /// Privacy by default: nothing leaves the device.
  final bool offlineOnly;

  AppSettings copyWith({
    Object? uiLocale = _keep,
    bool? seniorMode,
    ThemeMode? themeMode,
    double? speechRate,
    bool? autoSpeak,
    SttEngine? sttEngine,
    String? whisperModelId,
    bool? offlineOnly,
  }) =>
      AppSettings(
        uiLocale: identical(uiLocale, _keep) ? this.uiLocale : uiLocale as String?,
        seniorMode: seniorMode ?? this.seniorMode,
        themeMode: themeMode ?? this.themeMode,
        speechRate: speechRate ?? this.speechRate,
        autoSpeak: autoSpeak ?? this.autoSpeak,
        sttEngine: sttEngine ?? this.sttEngine,
        whisperModelId: whisperModelId ?? this.whisperModelId,
        offlineOnly: offlineOnly ?? this.offlineOnly,
      );
}

const _keep = Object();

final prefsProvider = Provider<SharedPreferences>(
    (ref) => throw UnimplementedError('override in main()'));

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

class SettingsNotifier extends Notifier<AppSettings> {
  SharedPreferences get _p => ref.read(prefsProvider);

  @override
  AppSettings build() {
    final p = ref.read(prefsProvider);
    return AppSettings(
      uiLocale: p.getString('uiLocale'),
      seniorMode: p.getBool('seniorMode') ?? false,
      themeMode: ThemeMode.values[p.getInt('themeMode') ?? 0],
      speechRate: p.getDouble('speechRate') ?? 0.45,
      autoSpeak: p.getBool('autoSpeak') ?? true,
      sttEngine: SttEngine.values[p.getInt('sttEngine') ?? 0],
      whisperModelId: p.getString('whisperModelId') ?? 'whisper-base',
      offlineOnly: p.getBool('offlineOnly') ?? true,
    );
  }

  void update(AppSettings s) {
    state = s;
    if (s.uiLocale == null) {
      _p.remove('uiLocale');
    } else {
      _p.setString('uiLocale', s.uiLocale!);
    }
    _p
      ..setBool('seniorMode', s.seniorMode)
      ..setInt('themeMode', s.themeMode.index)
      ..setDouble('speechRate', s.speechRate)
      ..setBool('autoSpeak', s.autoSpeak)
      ..setInt('sttEngine', s.sttEngine.index)
      ..setString('whisperModelId', s.whisperModelId)
      ..setBool('offlineOnly', s.offlineOnly);
  }
}
