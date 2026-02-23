import '../config.dart';
import '../platform_environment.dart';

class InstanceLogger {
  final SdkLogger _sdkLogger;
  final bool _enabled;
  final bool _enableVisualWarnings;
  final CountlyWarningPresenter _warningPresenter;
  final String instanceKey;
  final void Function(LogLevel level)? onLog;

  InstanceLogger(this._sdkLogger,
      {required bool enabled,
      required bool enableVisualWarnings,
      required CountlyWarningPresenter warningPresenter,
      required this.instanceKey,
      this.onLog})
      : _enabled = enabled,
        _enableVisualWarnings = enableVisualWarnings,
        _warningPresenter = warningPresenter;

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
      if ((level == LogLevel.error || level == LogLevel.warning) &&
          _enableVisualWarnings &&
          _warningPresenter.isAvailable) {
        try {
          _warningPresenter.showWarning(message);
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
