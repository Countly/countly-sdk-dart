import 'dart:async';
import 'package:meta/meta.dart';
import 'package:countly_sdk_dart/src/constants.dart';

/// Storage mode for the SDK. Persistent uses platform storage, memory is ephemeral.
enum StorageMode { persistent, memory }

/// Logging levels ordered by verbosity.
enum LogLevel { error, warning, info, debug, verbose }

/// User provided custom storage method signatures.
typedef StorageReadFn = FutureOr<String?> Function(String key);
typedef StorageWriteFn = FutureOr<void> Function(String key, String value);
typedef StorageRemoveFn = FutureOr<void> Function(String key);
typedef StorageKeysFn = FutureOr<List<String>> Function();

/// Wrapper of custom storage methods.
class CustomStorageMethods {
  final StorageReadFn? read;
  final StorageWriteFn? write;
  final StorageRemoveFn? remove;
  final StorageKeysFn? keys;

  const CustomStorageMethods({this.read, this.write, this.remove, this.keys});

  bool get hasAny => read != null || write != null || remove != null || keys != null;
}

/// Immutable configuration for an SDK instance.
@immutable
class CountlyConfig {
  /// Application key (mandatory)
  final String appKey;

  /// Base server URL without trailing slash. (mandatory)
  final String serverUrl;

  /// Optional device id.
  final String? deviceId;

  /// Optional initial user properties.
  final Map<String, dynamic>? userProperties;

  /// Storage mode selection (persistent by default).
  final StorageMode storageMode;

  /// Custom storage overrides (optional).
  final CustomStorageMethods? storageMethods;

  /// Logging level (verbose by default).
  final LogLevel logLevel;

  /// Optional custom logger implementing [SdkLogger] interface.
  final SdkLogger? logger;

  /// SDK internal logging. (disabled by default)
  final bool enableSDKLogs;

  /// If true, consent will be given to SDK to enable features requiring consent. (default: false)
  final bool giveConsent;

  /// Optional custom request headers to be applied to every network request.
  /// Header names are case-insensitive per HTTP spec. Values must be String.
  /// SDK will merge these with its own required headers (Content-Type, Accept)
  /// with custom values taking precedence if they collide (except Content-Type
  /// which will only be overridden if explicitly provided).
  final Map<String, String>? customRequestHeaders;

  /// Optional override for SDK detected device metrics.
  final Map<String, dynamic>? deviceMetricOverrides;

  /// If true, automatically restarts the last
  /// view with the same name in bg -> fg. (default: true)
  final bool autoRestartViews;

  /// SBS data to be used in first init.
  final Map<String, dynamic> sbs;

  const CountlyConfig._({
    required this.appKey,
    required this.serverUrl,
    required this.deviceId,
    required this.userProperties,
    required this.storageMode,
    required this.storageMethods,
    required this.logLevel,
    required this.logger,
    required this.giveConsent,
    required this.enableSDKLogs,
    required this.customRequestHeaders,
    required this.deviceMetricOverrides,
    required this.autoRestartViews,
    required this.sbs,
  });

  factory CountlyConfig({
    required String appKey,
    required String serverUrl,
    String? deviceId,
    Map<String, dynamic>? userProperties,
    StorageMode storageMode = StorageMode.persistent,
    CustomStorageMethods? storageMethods,
    LogLevel logLevel = LogLevel.verbose,
    Map<String, dynamic>? deviceMetricOverrides,
    SdkLogger? logger,
    bool enableSDKLogs = false,
    bool giveConsent = false,
    Map<String, String>? customRequestHeaders,
    bool autoRestartViews = true,
    Map<String, dynamic> sbs = const {},
  }) {
    if (appKey.isEmpty) {
      throw ArgumentError('app_key cannot be empty');
    }
    if (serverUrl.isEmpty) {
      throw ArgumentError('server_url cannot be empty');
    }
    if (!serverUrl.startsWith('http://') && !serverUrl.startsWith('https://')) {
      /// TODO: too strict?
      throw ArgumentError('server_url must start with http:// or https://');
    }
    if (customRequestHeaders != null) {
      for (final e in customRequestHeaders.entries) {
        if (e.key.trim().isEmpty) {
          throw ArgumentError('customRequestHeaders contains empty header name');
        }
        if (e.value.trim().isEmpty) {
          throw ArgumentError('customRequestHeaders header [${e.key}] has empty value');
        }
      }
    }

    /// remove trailing slashes
    final normalized = serverUrl.replaceFirst(RegExp(r'/+$'), '');

    return CountlyConfig._(
        appKey: appKey,
        serverUrl: normalized,
        deviceId: deviceId,
        userProperties: userProperties == null ? null : Map.unmodifiable(Map.of(userProperties)),
        storageMode: storageMode,
        storageMethods: storageMethods,
        logLevel: logLevel,
        logger: logger,
        giveConsent: giveConsent,
        enableSDKLogs: enableSDKLogs,
        customRequestHeaders: customRequestHeaders == null ? null : Map.unmodifiable(Map.of(customRequestHeaders)),
        deviceMetricOverrides: deviceMetricOverrides == null ? null : Map.unmodifiable(Map.of(deviceMetricOverrides)),
        autoRestartViews: autoRestartViews,
        sbs: Map.of(sbs));
  }
}

abstract class SdkLogger {
  bool isEnabled(LogLevel level);
  void log(LogLevel level, String message, {Object? error, StackTrace? stack});
}

class DefaultSdkLogger implements SdkLogger {
  final LogLevel level;
  DefaultSdkLogger(this.level);
  @override
  bool isEnabled(LogLevel l) => l.index <= level.index;
  @override
  void log(LogLevel level, String message, {Object? error, StackTrace? stack}) {
    if (!isEnabled(level)) return;
    final prefix = level.name.toUpperCase();
    final buffer = StringBuffer('[c][$prefix] $message');
    if (error != null) buffer.write(' | error=$error');
    if (stack != null) buffer.write('\n$stack');
    // ignore: avoid_print
    print(buffer.toString());
  }
}
