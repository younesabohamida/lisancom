/// Typed failures. `key` is a localization key shown to the user.
class AppFailure implements Exception {
  const AppFailure(this.key, [this.detail]);
  final String key;
  final Object? detail;
  @override
  String toString() => 'AppFailure($key)';
}

class ModelMissingFailure extends AppFailure {
  const ModelMissingFailure([Object? detail]) : super('err_model_missing', detail);
}
