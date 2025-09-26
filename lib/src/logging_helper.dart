import 'config.dart';

class InstanceLogger {
  final SdkLogger _sdkLogger;
  final bool _enabled;
  final String instanceKey;
  final void Function(LogLevel level)? onLog;

  InstanceLogger(this._sdkLogger, {required bool enabled, required this.instanceKey, this.onLog}) : _enabled = enabled;

  void e(String message, {Object? error, StackTrace? stack}) => _log(LogLevel.error, message, error: error, stack: stack);
  void w(String message, {Object? error, StackTrace? stack}) => _log(LogLevel.warning, message, error: error, stack: stack);
  void i(String message, {Object? error, StackTrace? stack}) => _log(LogLevel.info, message, error: error, stack: stack);
  void d(String message, {Object? error, StackTrace? stack}) => _log(LogLevel.debug, message, error: error, stack: stack);
  void v(String message, {Object? error, StackTrace? stack}) => _log(LogLevel.verbose, message, error: error, stack: stack);

  void _log(LogLevel level, String message, {Object? error, StackTrace? stack}) {
    final shouldEmit = _enabled && _sdkLogger.isEnabled(level);
    if (shouldEmit) {
      _sdkLogger.log(level, '[${instanceKey.substring(0, 3)}] $message', error: error, stack: stack);
    }
    if (onLog != null) {
      try {
        onLog!(level);
      } catch (_) {}
    }
  }
}
