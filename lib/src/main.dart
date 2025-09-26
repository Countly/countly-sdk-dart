library sdk_instance_lib;

import 'dart:async';
import 'dart:convert';
import 'metrics/metrics_collector.dart' as metrics_collector;
import 'package:meta/meta.dart';

import 'package:uuid/uuid.dart';

import 'config.dart';
import 'networking.dart';
import 'storage.dart';
import 'migration.dart';
import 'logging_helper.dart';
import 'constants.dart';

part 'modules/events_module.dart';
part 'modules/users_module.dart';
part 'modules/consents_module.dart';
part 'modules/remote_config_module.dart';
part 'modules/views_module.dart';
part 'modules/behavior_module.dart';
part 'modules/sessions_module.dart';
part 'testing_utils.dart';

class CountlyInstance {
  final CountlyConfig config;
  final String instanceKey; // default instance == 'default'.

  final List<Map<String, dynamic>> _eventQueue = [];
  final List<Map<String, dynamic>> _requestQueue = [];
  Map<String, dynamic> _remoteConfigValues = {};
  Map<String, dynamic> _userPropertiesNamedCache = {};
  Map<String, dynamic> _customUserPropertiesCache = {};
  final Set<ConsentType> _grantedConsents = {};

  // Health check counters
  int _logErrorCount = 0;
  int _logWarningCount = 0;
  int? _lastFailedStatusCode;
  String? _lastFailedErrorMessage;
  bool _didSendHealthCheckThisInit = false;

  String? _deviceId;
  int? _deviceIdType;

  Timer? _internalTimer;
  bool _suspended = false; // for request backoff
  DateTime? _suspendUntil;

  static const _sdkVersion = SdkInternal.sdkVersion;
  static const _sdkName = SdkInternal.sdkName;

  late final StorageFacade _storage;
  late NetworkClient _network;
  late final MigrationService _migration;
  late final SdkLogger _logger;
  late final InstanceLogger L;

  EventsModule? _eventsModule;
  UsersModule? _usersModule;
  ConsentsModule? _consentsModule;
  RemoteConfigModule? _remoteConfigModule;
  ViewsModule? _viewsModule;
  BehaviorModule? _sbs;
  SessionsModule? _sessionsModule;

  String? _activeViewName;
  DateTime? _activeViewStart;
  String? _previousEventKey;
  String? _previousViewName;

  CountlyInstance._(this.config, this.instanceKey);

  static Future<CountlyInstance> create(CountlyConfig config, {String instanceKey = 'default'}) async {
    final inst = CountlyInstance._(config, instanceKey);
    await inst._init();
    return inst;
  }

  Future<void> _init() async {
    _logger = config.logger ?? DefaultSdkLogger(config.logLevel);
    L = InstanceLogger(_logger, enabled: config.enableSDKLogs, instanceKey: instanceKey, onLog: (lvl) {
        if (lvl == LogLevel.error)
          _logErrorCount++;
        else if (lvl == LogLevel.warning)
          _logWarningCount++;
      },
    );
    _storage = StorageFacade(config, L: L);
    _network = NetworkClient(config.serverUrl, L: L, customHeaders: config.customRequestHeaders);
    _migration = MigrationService(_storage, enabled: instanceKey == 'default' && config.storageMode == StorageMode.persistent, L: L);

    _sbs = BehaviorModule(this);
    await _sbs!.init();

    L.i('init: instanceKey=[$instanceKey] appKey=[${config.appKey}] serverUrl=[${config.serverUrl}]');
    L.d('config: deviceIdProvided=[${config.deviceId != null}] requiresConsent=[${_sbs?.isConsentRequired ?? false}] giveAllConsents=[${config.giveAllConsents}] initialConsents=[${config.initialEnabledConsents.map((e) => e.name).join(',')}]');
    L.d('config: remoteConfig=[${config.turnOnRemoteConfig}] internalTimerInterval=[${_sbs?.internalTimerInterval}s] eventQueueSize=[${_sbs?.eventQueueSize}] requestQueueSize=[${_sbs?.requestQueueSize}]');
    L.d('config: storageMode=[${config.storageMode.name}] customStorageOverrides=[${config.storageMethods?.hasAny == true}]');
    L.d('config: loggingEnabled=[${config.enableSDKLogs}] logLevel=[${config.logLevel.name}] customLogger=[${config.logger != null}]');

    if (config.requiresConsent) {
      if (config.giveAllConsents) {
        _grantedConsents.addAll(ConsentType.values);
      } else {
        _grantedConsents.addAll(config.initialEnabledConsents);
      }
      L.i('Initial consents: [${_grantedConsents.map((e) => e.name).join(', ')}]');
    }

    _eventsModule = EventsModule(this);
    _usersModule = UsersModule(this);
    _consentsModule = ConsentsModule(this);
    _remoteConfigModule = RemoteConfigModule(this);
    _viewsModule = ViewsModule(this);
    _sessionsModule = SessionsModule(this);

    // Migration only for default instance
    if (instanceKey == 'default') {
      await _migration.migrateIfNeeded();
    }

    await _loadPersistedState();
    await _initializeDeviceId();

    // Initial user properties if any and consent given.
    if (config.userProperties != null && config.userProperties!.isNotEmpty && hasConsentInternal(ConsentType.users)) {
      _ingestUserProperties(config.userProperties!);
      await _enqueueUserPropertiesCache();
    }

    // Fetch remote config if enabled and consent given.
    if (config.turnOnRemoteConfig && hasConsentInternal(ConsentType.remoteConfig)) {
      await _remoteConfigModule!.fetch();
    }

    _startTimer();
    // Record initial consent status if consent required
    if (config.requiresConsent) {
      _recordConsentRequest();
    }
    // Record location request
    _addToRequestQueue(_prepareRequest({'location': ''}));

    L.i('SDK instance initialized successfully');

    // ignore: discarded_futures
    _sbs!.fetchLatest();
    // ignore: discarded_futures
    _attemptHealthCheck();
  }

  /// Checks storage for data from previous runs and loads into memory.
  Future<void> _loadPersistedState() async {
    if (config.storageMode != StorageMode.persistent && !(config.storageMethods?.hasAny ?? false)) {
      L.v('No storage, skipping checking for stored data');
      return;
    }
    final rq = await _storage.readJson<List<dynamic>>(StorageSubKeys.requestQueue);
    if (rq is List) {
      L.v('Loading persisted request queue with [${rq.length}] items');
      for (final item in rq) {
        if (item is Map<String, dynamic>)
          _requestQueue.add(item);
        else if (item is String) {
          try {
            final d = jsonDecode(item);
            if (d is Map<String, dynamic>) _requestQueue.add(d);
          } catch (_) {}
        }
      }
    } else {
      L.v('No persisted request queue found');
    }
    final eq = await _storage.readJson<List<dynamic>>(StorageSubKeys.eventQueue);
    if (eq is List) {
      L.v('Loading persisted event queue with ${eq.length} items');
      for (final item in eq) {
        if (item is Map<String, dynamic>)
          _eventQueue.add(item);
        else if (item is String) {
          try {
            final d = jsonDecode(item);
            if (d is Map<String, dynamic>) _eventQueue.add(d);
          } catch (_) {}
        }
      }
    } else {
      L.v('No persisted event queue found');
    }
    final rc = await _storage.readJson<Map<String, dynamic>>(StorageSubKeys.remoteConfig);
    if (rc is Map<String, dynamic>) _remoteConfigValues = rc;
  }

  /// Initializes device id: loads from storage if any, else uses provided or generates new.
  Future<void> _initializeDeviceId() async {
    if (config.storageMode == StorageMode.persistent || (config.storageMethods?.hasAny ?? false)) {
      final stored = await _storage.readString(StorageSubKeys.deviceId);
      final storedType = await _storage.readString(StorageSubKeys.deviceIdType);
      if (stored != null) {
        L.d('Loaded deviceId from storage: [$stored], type: [$storedType]');
        _deviceId = stored;
        _deviceIdType = int.tryParse(storedType ?? '') ?? DeviceIdType.provided;
        return;
      }
    }
    if (config.deviceId != null) {
      _deviceId = config.deviceId;
      _deviceIdType = DeviceIdType.provided;
      L.d('Using provided deviceId: [$_deviceId]');
    } else {
      _deviceId = const Uuid().v4();
      _deviceIdType = DeviceIdType.generated;
      L.d('Generated new deviceId: [$_deviceId]');
    }

    /// Save device id if storage enabled.
    if (config.storageMode == StorageMode.memory && !(config.storageMethods?.hasAny ?? false)) return;
    if (_deviceId != null) {
      await _storage.writeString(StorageSubKeys.deviceId, _deviceId!);
      await _storage.writeString(StorageSubKeys.deviceIdType, _deviceIdType.toString());
    }
  }

  /// Starts the internal timer for periodic processing.
  void _startTimer() {
    _internalTimer?.cancel();
    final interval = _sbs?.internalTimerInterval ?? SdkBehaviorSettingsDefaults.sui;
    _internalTimer = Timer.periodic(Duration(seconds: interval), (_) async {
      L.d('Internal timer tick: processing events and requests');
      await processEventsAndRequests();
      _sessionsModule?.sessionUpdate();
    });
  }

  /// Flushes events to request queue then attempts sending.
  Future<void> processEventsAndRequests() async {
    L.d('Triggered processing event and request queues');
    _bundleEventQueue();
    if ((_userPropertiesNamedCache.isNotEmpty || _customUserPropertiesCache.isNotEmpty) && hasConsentInternal(ConsentType.users)) {
      L.d('Enqueuing user properties request cache: named=${_userPropertiesNamedCache.keys.length} custom=${_customUserPropertiesCache.keys.length}');
      await _enqueueUserPropertiesCache();
    }
    await _processRequestQueue();
  }

  /// Persists event queue to storage if enabled.
  void _persistEventQueue() {
    _storage.writeJson(StorageSubKeys.eventQueue, _eventQueue);
  }

  /// Persists request queue to storage if enabled.
  void _persistRequestQueue() {
    _storage.writeJson(StorageSubKeys.requestQueue, _requestQueue);
  }

  /// Converts batched events into a request and sends to request queue.
  void _bundleEventQueue() {
    if (_eventQueue.isEmpty) {
      L.v('Event Bundler: No events to bundle');
      return;
    }
    final batch = List<Map<String, dynamic>>.from(_eventQueue);
    _eventQueue.clear();
    _persistEventQueue();

    final payload = jsonEncode(batch);
    final request = _prepareRequest({'events': payload});
    L.d('Event Bundler: Flushed events to request queue');
    _addToRequestQueue(request);
  }

  /// Adds necessary common fields to request data.
  Map<String, dynamic> _prepareRequest(Map<String, dynamic> data) {
    if (_deviceId == null) {
      L.e('prepareRequest called with null deviceId, this should not happen');
    }
    if (config.appKey.isEmpty) {
      L.e('prepareRequest called with empty appKey, this should not happen');
    }
    return {
      'app_key': config.appKey,
      'device_id': _deviceId,
      'sdk_version': _sdkVersion,
      'sdk_name': _sdkName,
      'av': SdkInternal.appVersion,
      ...data,
    };
  }

  /// Attach time and optionally rr
  void _attachDynamicRequestMeta(Map<String, dynamic> req, {bool includeRR = false}) {
    final now = DateTime.now();
    req['timestamp'] = now.millisecondsSinceEpoch;
    req['hour'] = now.hour;
    req['dow'] = now.weekday % 7;
    req['tz'] = now.timeZoneOffset.inMinutes;
    if (includeRR) {
      req['rr'] = _requestQueue.length;
    }
  }

  /// Adds a request to the request queue with overflow handling.
  /// If sending nested data, ensure to use Map<String, dynamic> copies to avoid mutation issues.
  /// example:
  ///
  /// ```dart
  /// final inner = <String,dynamic>{'name': 'Alice'};
  /// final req = _prepareRequest({'user_details': inner});
  /// ```
  void _addToRequestQueue(Map<String, dynamic> request) {
    final max = _sbs?.requestQueueSize ?? SdkBehaviorSettingsDefaults.rqs;
    if (_requestQueue.length >= max) {
      L.w('Request queue full, removing oldest request');
      _requestQueue.removeAt(0);
    }
    L.d('To request queue: Enqueuing request');
    _requestQueue.add(request);
    _persistRequestQueue();
  }

  /// Adds an event to the event queue with bundling handling.
  void _addToEventQueue(Map<String, dynamic> event) {
    if (!(_sbs?.trackingEnabled ?? true)) {
      L.d('Tracking disabled (SBS), dropping event');
      return;
    }
    final max = _sbs?.eventQueueSize ?? SdkBehaviorSettingsDefaults.eqs;
    if (_eventQueue.length >= max) {
      L.d('Event queue full, bundling events');
      _bundleEventQueue();
    }
    L.d('To event queue: Enqueuing event');
    _eventQueue.add(event);
    _persistEventQueue();
  }

  /// Attempts sending requests in the request queue with backoff handling.
  Future<void> _processRequestQueue() async {
    // Backoff check.
    if (_suspended) {
      if (_suspendUntil != null && DateTime.now().isAfter(_suspendUntil!)) {
        L.i('Resuming request processing after suspension');
        _suspended = false;
      } else {
        L.i('Request processing suspended until [$_suspendUntil]');
        return;
      }
    }

    if (!(_sbs?.networkingEnabled ?? true)) {
      L.d('Networking disabled (SBS), skipping request processing');
      return;
    }

    if (_requestQueue.isEmpty) {
      L.d('No requests to send');
      return;
    }

    // Iterate snapshot to avoid mutation issues while sending.
    final rqSnapshot = List<Map<String, dynamic>>.from(_requestQueue);
    for (final req in rqSnapshot) {
      final ok = await _sendRequest(req);
      if (!ok) {
        L.w('Request failed, backing off for 60 seconds'); // TODO: hardcoded
        _suspended = true;
        _suspendUntil = DateTime.now().add(const Duration(seconds: 60));
        break;
      } else {
        L.i('Request sent successfully, removing from queue');
        _requestQueue.removeAt(0);
        _persistRequestQueue();
      }
    }
  }

  /// Sends a single request and returns true if successful.
  Future<bool> _sendRequest(Map<String, dynamic> req) async {
    try {
      _attachDynamicRequestMeta(req, includeRR: true);
      final resp = await _network.makeSelectiveRequest(req);
      L.i('Received response: status=[${resp.statusCode}], body=[${resp.body}]');
      final ok = _network.isResponseValid(resp, acceptJSON: false);
      if (!ok) {
        _lastFailedStatusCode = resp.statusCode;
        _lastFailedErrorMessage = 'HTTP ${resp.statusCode}';
      }
      return ok;
    } catch (e, st) {
      L.e('Request failed', error: e, stack: st);
      return false; // Network / other error.
    }
  }

  // --- For Test (read-only) ---
  @visibleForTesting
  List<Map<String, dynamic>> get debugEventQueueSnapshot => List.unmodifiable(_eventQueue);

  @visibleForTesting
  List<Map<String, dynamic>> get debugRequestQueueSnapshot => List.unmodifiable(_requestQueue);

  @visibleForTesting
  int get debugEventQueueLength => _eventQueue.length;

  @visibleForTesting
  int get debugRequestQueueLength => _requestQueue.length;

  @visibleForTesting
  set debugOverrideNetworkClient(NetworkClient client) {
    _network.close();
    _network = client; // ignore: invalid_use_of_visible_for_testing_member
  }

  @visibleForTesting
  bool get isTimerActive => _internalTimer?.isActive == true;

  /// Exposes current device id (read-only public accessor).
  String? get deviceId => _deviceId;
  int? get deviceIdType => _deviceIdType;

  /// Helper guarding public calls after disposal.
  bool _guardDisposed(String action) {
    if (_disposed) {
      L.w('Action ["$action"] ignored: instance disposed key=[$instanceKey]');
      return true;
    }
    return false;
  }

  /// Checks if consent of given type is granted.
  bool hasConsentInternal(ConsentType type) {
    if (!config.requiresConsent) {
      L.d('Consent not required, treating as granted for type [${type.name}]');
      return true;
    }
    if (_disposed) {
      L.w('Instance disposed, treating consent as not granted for type [${type.name}]');
      return false;
    }
    if (_grantedConsents.contains(type)) {
      L.d('Consent granted for type [${type.name}]');
      return true;
    }
    return false;
  }

  /// Bundles event queue and then adds user properties request to request queue if any.
  Future<void> _enqueueUserPropertiesCache() async {
    if (_userPropertiesNamedCache.isEmpty && _customUserPropertiesCache.isEmpty) {
      L.v('User properties cache empty, skipping enqueue');
      return;
    }
    final userDetails = <String, dynamic>{};
    if (_userPropertiesNamedCache.isNotEmpty) userDetails.addAll(_userPropertiesNamedCache);
    if (_customUserPropertiesCache.isNotEmpty) userDetails['custom'] = Map<String, dynamic>.from(_customUserPropertiesCache);
    final request = _prepareRequest({'user_details': userDetails});
    _addToRequestQueue(request);
    L.d('Enqueued user properties request: named=${_userPropertiesNamedCache.keys.length} custom=${_customUserPropertiesCache.keys.length}');
    _userPropertiesNamedCache.clear();
    _customUserPropertiesCache.clear();
  }

  /// Sends user properties to correct cache (named/custom) based on keys
  void _ingestUserProperties(Map<String, dynamic> props) {
    const named = {NamedUserProperty.name, NamedUserProperty.username, NamedUserProperty.email, NamedUserProperty.organization, NamedUserProperty.phone, NamedUserProperty.picture, NamedUserProperty.gender, NamedUserProperty.byear};
    props.forEach((k, v) {
      if (named.contains(k)) {
        _userPropertiesNamedCache[k] = v;
      } else {
        _customUserPropertiesCache[k] = v;
      }
    });
  }

  /// HC request
  Future<void> _attemptHealthCheck() async {
    if (_didSendHealthCheckThisInit) return;
    _didSendHealthCheckThisInit = true;
    try {
      final hc = <String, dynamic>{'el': _logErrorCount, 'wl': _logWarningCount, 'sc': _lastFailedStatusCode ?? "", 'em':  _lastFailedErrorMessage ?? ""};
      final metrics = {'_app_version': SdkInternal.appVersion};
      final req = _prepareRequest({'hc': hc, 'metrics': metrics});
      _attachDynamicRequestMeta(req);
      final resp = await _network.makeRequest(req, Endpoints.events);
      final ok = _network.isResponseValid(resp, acceptJSON: false);
      if (ok) {
        _logErrorCount = 0;
        _logWarningCount = 0;
        _lastFailedStatusCode = null;
        _lastFailedErrorMessage = null;
        L.i('Health check request sent successfully and counters reset');
      } else {
        L.w('Health check failed');
      }
    } catch (e, st) {
      L.w('Health check request attempt error:', error: e, stack: st);
    }
  }

  void _recordConsentRequest() {
    final consentMap = <String, bool>{};
    for (final c in ConsentType.values) {
      consentMap[c.name] = _grantedConsents.contains(c);
    }
    final req = _prepareRequest({'consent': consentMap});
    _addToRequestQueue(req);
    L.d('Recorded consent request:[$consentMap]');
  }

  bool _disposed = false;

  /// Disposes this instance: cancels timer, optionally flushes pending events & requests, closes network client.
  Future<void> dispose({bool flush = true}) async {
    if (_disposed) return;
    _internalTimer?.cancel();
    _internalTimer = null;

    // End active view before flushing so duration is captured.
    try {
      _viewsModule?.endIfActive();
    } catch (_) {}
    if (flush) {
      try {
        // Ensure any remaining events & user properties become requests.
        await processEventsAndRequests();
      } catch (e, st) {
        L.e('Dispose flush failed', error: e, stack: st);
      }
    }
    _disposed = true;
    try {
      _network.close();
    } catch (e, st) {
      L.e('Network client close failed', error: e, stack: st);
    }
    L.i('Disposed SDK instance key=[$instanceKey]');
  }

  /// Helper guarding public calls after disposal.
  bool get isDisposed => _disposed;

  // Namespaced public accessors
  EventsModule get events => _eventsModule ??= EventsModule(this);
  UsersModule get users => _usersModule ??= UsersModule(this);
  ConsentsModule get consents => _consentsModule ??= ConsentsModule(this);
  RemoteConfigModule get remoteConfig => _remoteConfigModule ??= RemoteConfigModule(this);
  ViewsModule get views => _viewsModule ??= ViewsModule(this);
  SessionsModule get sessions => _sessionsModule ??= SessionsModule(this);
}

/// Global manager for multi-instance support with dispose handling.
class Countly {
  static final Map<String, CountlyInstance> _instances = {};

  /// Returns default instance if already initialized, else null.
  static CountlyInstance? get defaultInstance => _instances['default'];

  /// TODO: If instance exists it is replaced safely. Should not?
  static Future<CountlyInstance> init(CountlyConfig config, {String instanceKey = 'default'}) async {
    final inst = await CountlyInstance.create(config, instanceKey: instanceKey);
    _instances[instanceKey] = inst;
    return inst;
  }

  static CountlyInstance? instance(String key) => _instances[key];

  /// Disposes a specific instance by key; returns true if disposed.
  static Future<bool> disposeInstance(String key, {bool flush = true}) async {
    final inst = _instances.remove(key);
    if (inst == null) return false;
    await inst.dispose(flush: flush);
    return true;
  }

  /// Disposes all instances.
  static Future<void> disposeAll({bool flush = true}) async {
    final entries = List<MapEntry<String, CountlyInstance>>.from(_instances.entries);
    _instances.clear();
    for (final e in entries) {
      await e.value.dispose(flush: flush);
    }
  }
}
