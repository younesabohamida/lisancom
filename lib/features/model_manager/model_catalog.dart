import 'dart:convert';

class ModelFile {
  const ModelFile(this.role, this.url, this.sha256);
  final String role; // encoder | decoder | tokens
  final String url;
  final String sha256; // optional expected hash ('' = unknown, computed on install)
}

class WhisperModelSpec {
  const WhisperModelSpec({
    required this.id,
    required this.name,
    required this.approxMB,
    required this.keepBothLanguagesLoaded,
    required this.license,
    required this.files,
  });

  final String id;
  final String name;
  final int approxMB;
  final bool keepBothLanguagesLoaded;
  final String license;
  final List<ModelFile> files;

  String fileName(String role) => switch (role) {
        'tokens' => 'tokens.txt',
        _ => '$role.onnx',
      };
}

class ModelCatalog {
  const ModelCatalog(this.whisper);
  final List<WhisperModelSpec> whisper;

  WhisperModelSpec? byId(String id) {
    for (final w in whisper) {
      if (w.id == id) return w;
    }
    return null;
  }

  static ModelCatalog parse(String jsonText) {
    final j = jsonDecode(jsonText) as Map<String, dynamic>;
    final list = (j['whisper'] as List).cast<Map<String, dynamic>>();
    return ModelCatalog([
      for (final w in list)
        WhisperModelSpec(
          id: w['id'] as String,
          name: w['name'] as String,
          approxMB: (w['approxMB'] as num).toInt(),
          keepBothLanguagesLoaded: w['keepBothLanguagesLoaded'] as bool? ?? false,
          license: w['license'] as String? ?? '',
          files: [
            for (final e in (w['files'] as Map<String, dynamic>).entries)
              ModelFile(
                e.key,
                (e.value as Map)['url'] as String,
                ((e.value as Map)['sha256'] as String?) ?? '',
              ),
          ],
        ),
    ]);
  }
}
