import 'config.dart';

class InstanceLogger {
  final SdkLogger _inner;
  final bool _enabled;
  final String instanceKey;

  InstanceLogger(this._inner, {required bool enabled, required this.instanceKey}) : _enabled = enabled;

  void e(String message, {Object? error, StackTrace? stack}) => _log(LogLevel.error, message, error: error, stack: stack);
  void w(String message, {Object? error, StackTrace? stack}) => _log(LogLevel.warning, message, error: error, stack: stack);
  void i(String message, {Object? error, StackTrace? stack}) => _log(LogLevel.info, message, error: error, stack: stack);
  void d(String message, {Object? error, StackTrace? stack}) => _log(LogLevel.debug, message, error: error, stack: stack);
  void v(String message, {Object? error, StackTrace? stack}) => _log(LogLevel.verbose, message, error: error, stack: stack);

  void _log(LogLevel level, String message, {Object? error, StackTrace? stack}) {
    if (!_enabled) return;
    if (!_inner.isEnabled(level)) return;
    _inner.log(level, '[inst:$instanceKey] $message', error: error, stack: stack);
  }
}
