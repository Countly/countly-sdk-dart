import '../config.dart';
import 'toast_stub.dart' if (dart.library.ui) 'toast_flutter.dart';

class InstanceLogger {
  final SdkLogger _sdkLogger;
  final bool _enabled;
  final String instanceKey;
  final void Function(LogLevel level)? onLog;

  InstanceLogger(this._sdkLogger, {required bool enabled, required this.instanceKey, this.onLog}) : _enabled = enabled;

  void e(String message, {Object? error, StackTrace? stack}) =>
      _log(LogLevel.error, message, error: error, stack: stack);
  void w(String message, {Object? error, StackTrace? stack}) =>
      _log(LogLevel.warning, message, error: error, stack: stack);
  void i(String message, {Object? error, StackTrace? stack}) =>
      _log(LogLevel.info, message, error: error, stack: stack);
  void d(String message, {Object? error, StackTrace? stack}) =>
      _log(LogLevel.debug, message, error: error, stack: stack);
  void v(String message, {Object? error, StackTrace? stack}) =>
      _log(LogLevel.verbose, message, error: error, stack: stack);

  void _log(LogLevel level, String message, {Object? error, StackTrace? stack}) {
    final shouldEmit = _enabled && _sdkLogger.isEnabled(level);
    if (shouldEmit) {
      if (level == LogLevel.error || level == LogLevel.warning) {
        message = '!!!!!\n $message';
      }
      // trimmed instance key for brevity (to first 3 chars or less)
      final formatted = '[${instanceKey.substring(0, instanceKey.length > 3 ? 3 : instanceKey.length)}] $message';
      _sdkLogger.log(level, formatted, error: error, stack: stack);
      if ((level == LogLevel.error || level == LogLevel.warning) && sdkToastAvailable) {
        try {
          showSdkToast(message);
        } catch (_) {}
      }
    }
    if (onLog != null) {
      try {
        onLog!(level);
      } catch (_) {}
    }
  }
}
