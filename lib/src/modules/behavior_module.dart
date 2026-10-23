part of '../main.dart';

class BehaviorModule {
  final CountlyInstance _inst;
  BehaviorModule(this._inst);

  final Map<String, dynamic> _sbs = {};

  /// getters for SBS values to be used in SdkInstance
  bool get trackingEnabled => _sbs['tracking'] as bool? ?? SBSDefaults.tracking;
  bool get networkingEnabled => _sbs['networking'] as bool? ?? SBSDefaults.networking;
  int get eventQueueSize => _sbs['eqs'] as int? ?? SBSDefaults.eqs;
  int get requestQueueSize => _sbs['rqs'] as int? ?? SBSDefaults.rqs;
  int get internalTimerInterval => _sbs['sui'] as int? ?? SBSDefaults.sui;
  // bool get isSessionTrackingAllowed => (_sbs['st'] as bool? ?? true); // default 1 - NOT SUPPORTED
  // bool get isCrashTrackingAllowed => (_sbs['crt'] as bool? ?? true); // default 1 - NOT SUPPORTED
  bool get isLocationTrackingAllowed => _sbs['lt'] as bool? ?? SBSDefaults.lt;
  bool get isViewTrackingAllowed => _sbs['vt'] as bool? ?? SBSDefaults.vt;
  int get keyLengthLimit => _sbs['lkl'] as int? ?? SBSDefaults.lkl;
  int get valueSizeLimit => _sbs['lvs'] as int? ?? SBSDefaults.lvs;
  int get segmentationValuesLimit => _sbs['lsv'] as int? ?? SBSDefaults.lsv;
  // int get breadcrumbCountLimit => _sbs['lbc'] as int; // default 100 - NOT SUPPORTED
  // int get stackTraceLineCountLimit => _sbs['ltlpt'] as int; // default 30 - NOT SUPPORTED
  // int get stackTraceLineLengthLimit => _sbs['ltl'] as int; // default 200 - NOT SUPPORTED
  bool get isCustomEventTrackingAllowed => _sbs['cet'] as bool? ?? SBSDefaults.cet;
  // bool get enterContentZoneAfterInit => (_sbs['ecz'] as bool? ?? false); // default 0 - NOT SUPPORTED
  // int get contentZoneRequestInterval => _sbs['czi'] as int; // default 30 - NOT SUPPORTED
  // bool get isConsentRequired => (_sbs['cr'] as bool? ?? false); // default 0 - NOT SUPPORTED
  int get serverConfigUpdateInterval => _sbs['scui'] as int? ?? SBSDefaults.scui;
  // bool get isRefreshContentZoneAllowed => (_sbs['rcz'] as bool? ?? true); // default 1 - NOT SUPPORTED
  // int get dropOldRequestTime => _sbs['dort'] as int; // default 0 (disabled) - NOT SUPPORTED
  // bool get isBackoffMechanismEnabled => (_sbs['bom'] as bool? ?? true); // default 1 - NOT SUPPORTED
  // int get backoffMechanismAcceptedTimeout => _sbs['bom_at'] as int; // default 10 - NOT SUPPORTED
  // double get backoffMechanismRequestQueuePercent => _sbs['bom_rqp'] as double; // default 0.5 - NOT SUPPORTED
  // int get backoffMechanismRequestAge => _sbs['bom_ra'] as int; // default 24 hours - NOT SUPPORTED
  // int get backoffMechanismDuration => _sbs['bom_d'] as int; // default 60 minutes - NOT SUPPORTED
  int get userPropertiesCacheLimit => _sbs['upcl'] as int? ?? SBSDefaults.upcl;
  List<String> get eventBlacklist => _stringList('eb'); // default []
  List<String> get userPropertiesBlacklist => _stringList('upb'); // default []
  List<String> get segmentationBlacklist => _stringList('sb'); // default []
  Map<String, dynamic> get eventSegmentationBlacklist => _sbs['esb'] as Map<String, dynamic>? ?? const {};
  List<String> get eventWhitelist => _stringList('ew'); // default []
  List<String> get userPropertiesWhitelist => _stringList('upw'); // default []
  List<String> get segmentationWhitelist => _stringList('sw'); // default []
  Map<String, dynamic> get eventSegmentationWhitelist => _sbs['esw'] as Map<String, dynamic>? ?? const {};
  @visibleForTesting
  Map<String, dynamic> get sbsSnapshot => Map.unmodifiable(_sbs);

  List<String> _stringList(String key) {
    final v = _sbs[key];
    if (v is List) {
      return v.map((e) => e.toString()).toList();
    }
    return const <String>[];
  }

  @visibleForTesting
  void debugApplyOverrides(Map<String, dynamic> overrides) => _applyOverrides(overrides, source: 'debug');

  Future<void> init() async {
    _initDefaults();
    await _loadPersisted();
  }

  void _initDefaults() {
    _sbs.clear();
    _sbs.addAll({
      'tracking': SBSDefaults.tracking,
      'networking': SBSDefaults.networking,
      'eqs': SBSDefaults.eqs,
      'rqs': SBSDefaults.rqs,
      'sui': SBSDefaults.sui,
      // 'st': SBSDefaults.st, // NOT SUPPORTED
      // 'crt': SBSDefaults.crt, // NOT SUPPORTED
      'lt': SBSDefaults.lt,
      'vt': SBSDefaults.vt,
      'lkl': SBSDefaults.lkl,
      'lvs': SBSDefaults.lvs,
      'lsv': SBSDefaults.lsv,
      // 'lbc': SBSDefaults.lbc, // NOT SUPPORTED
      // 'ltlpt': SBSDefaults.ltlpt, // NOT SUPPORTED
      // 'ltl': SBSDefaults.ltl, // NOT SUPPORTED
      'cet': SBSDefaults.cet,
      // 'ecz': SBSDefaults.ecz, // NOT SUPPORTED
      // 'czi': SBSDefaults.czi, // NOT SUPPORTED
      // 'cr': _inst.config.requiresConsent, // NOT SUPPORTED
      'scui': SBSDefaults.scui,
      // 'rcz': SBSDefaults.rcz, // NOT SUPPORTED
      // 'dort': SBSDefaults.dort, // NOT SUPPORTED
      // 'bom': SBSDefaults.bom, // NOT SUPPORTED
      // 'bom_at': SBSDefaults.bom_at, // NOT SUPPORTED
      // 'bom_rqp': SBSDefaults.bom_rqp, // NOT SUPPORTED
      // 'bom_ra': SBSDefaults.bom_ra, // NOT SUPPORTED
      // 'bom_d': SBSDefaults.bom_d, // NOT SUPPORTED
      'upcl': SBSDefaults.upcl,
      'eb': SBSDefaults.eb,
      'upb': SBSDefaults.upb,
      'sb': SBSDefaults.sb,
      'esb': SBSDefaults.esb,
      'ew': SBSDefaults.ew,
      'upw': SBSDefaults.upw,
      'sw': SBSDefaults.sw,
      'esw': SBSDefaults.esw,
    });
    _inst.L.d('BehaviorModule: defaults initialized');
  }

  /// Load persisted SBS object and apply any overrides.
  Future<void> _loadPersisted() async {
    final cfg = _inst.config;
    if (cfg.storageMode != StorageMode.persistent && !(cfg.storageMethods?.hasAny ?? false) && cfg.sbs.isEmpty) return;
    final stored = await _inst._storage.readJson<Map<String, dynamic>>(StorageSubKeys.behavior);
    if (stored == null) {
      final configOverrides = cfg.sbs['c'] as Map<String, dynamic>?;
      if (cfg.sbs.isNotEmpty && configOverrides != null) {
        _inst.L.i('BehaviorModule: loaded given SBS object=[${cfg.sbs.toString()}]');
        _applyOverrides(configOverrides, source: 'config');
      }
      return;
    }
    _inst.L.i('BehaviorModule: loaded stored SBS object=[${stored.toString()}]');
    final overrides = stored['c'];
    if (overrides is Map<String, dynamic>) {
      _applyOverrides(overrides, source: 'stored');
    }
  }

  /// Apply overrides from given map, log applied ones.
  /// Ignores unknown keys.
  void _applyOverrides(Map<String, dynamic> overrides, {required String source}) {
    int applied = 0;
    _inst.L.d('BehaviorModule: applying overrides from [$source]');
    overrides.forEach((k, v) {
      _inst.L.v('BehaviorModule: for key[$k] value[$v]');
      if (_sbs.containsKey(k)) {
        _sbs[k] = v;
        applied++;
        _inst.L.d('BehaviorModule override ($source): [$k]=[$v]');
      } else {
        _inst.L.w('BehaviorModule: unknown SBS key [$k], ignoring');
      }
    });
    if (applied > 0) _inst.L.i('BehaviorModule: applied [$applied] overrides from [$source]');
  }

  /// Fetch latest SBS from server and apply any overrides.
  /// Persists the full response for future use.
  Future<void> fetchAndApply() async {
    if (_inst._guardDisposed('behaviorModule.fetchLatest')) return;
    if (_inst._isInUnknownConsentState) {
      _inst.L.v('In unknown consent state, skipping fetching SBS from server');
      return;
    }
    try {
      final data = _inst._prepareRequest({});
      if (data == null) return;
      data['method'] = 'sc';
      final resp = await _inst._network.makeRequest(data, Endpoints.sdk);
      if (_inst._network.isResponseValid(resp, acceptJSON: true)) {
        final decoded = jsonDecode(resp.body);
        _inst.L.d('BehaviorModule: fetched latest SBS values:[${resp.body}]');
        if (decoded is Map<String, dynamic>) {
          await _inst._storage.writeJson(StorageSubKeys.behavior, decoded);
          final overrides = decoded['c'];
          if (overrides is Map<String, dynamic>) {
            _applyOverrides(overrides, source: 'server');
          } else {
            _inst.L.w('BehaviorModule: server response missing "c" map');
          }
        } else {
          _inst.L.w('BehaviorModule: unexpected JSON type ${decoded.runtimeType}');
        }
      } else {
        _inst.L.w('BehaviorModule: fetch invalid response');
      }
    } catch (e, st) {
      _inst.L.e('BehaviorModule: fetch error', error: e, stack: st);
    }
  }
}
