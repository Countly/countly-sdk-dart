part of sdk_instance_lib;

class BehaviorModule {
  final CountlyInstance _inst;
  BehaviorModule(this._inst);

  final Map<String, dynamic> _sbs = {};

  /// getters for SBS values to be used in SdkInstance
  bool get trackingEnabled => _sbs['tracking'] as bool; // default true
  bool get networkingEnabled => _sbs['networking'] as bool; // default true
  int get eventQueueSize => _sbs['eqs'] as int; // default 100
  int get requestQueueSize => _sbs['rqs'] as int; // default 50
  int get internalTimerInterval => _sbs['sui'] as int; // default 60
  // bool get isSessionTrackingAllowed => (_sbs['st'] as bool? ?? true); // default 1 - NOT SUPPORTED
  // bool get isCrashTrackingAllowed => (_sbs['crt'] as bool? ?? true); // default 1 - NOT SUPPORTED
  bool get isLocationTrackingAllowed => (_sbs['lt'] as bool? ?? true); // default 1
  bool get isViewTrackingAllowed => (_sbs['vt'] as bool? ?? true); // default 1
  int get keyLengthLimit => _sbs['lkl'] as int; // default 128
  int get valueSizeLimit => _sbs['lvs'] as int; // default 256
  int get segmentationValuesLimit => _sbs['lsv'] as int; // default 100
  int get breadcrumbCountLimit => _sbs['lbc'] as int; // default 100
  int get stackTraceLineCountLimit => _sbs['ltlpt'] as int; // default 30
  int get stackTraceLineLengthLimit => _sbs['ltl'] as int; // default 200
  bool get isCustomEventTrackingAllowed => (_sbs['cet'] as bool? ?? true); // default 1
  bool get enterContentZoneAfterInit => (_sbs['ecz'] as bool? ?? false); // default 0
  int get contentZoneRequestInterval => _sbs['czi'] as int; // default 30
  // bool get isConsentRequired => (_sbs['cr'] as bool? ?? false); // default 0 - NOT SUPPORTED
  int get serverConfigUpdateInterval => _sbs['scui'] as int; // default 4 hours
  bool get isRefreshContentZoneAllowed => (_sbs['rcz'] as bool? ?? true); // default 1
  int get dropOldRequestTime => _sbs['dort'] as int; // default 0 (disabled)
  bool get isBackoffMechanismEnabled => (_sbs['bom'] as bool? ?? true); // default 1
  int get backoffMechanismAcceptedTimeout => _sbs['bom_at'] as int; // default 10
  double get backoffMechanismRequestQueuePercent => _sbs['bom_rqp'] as double; // default 0.5
  int get backoffMechanismRequestAge => _sbs['bom_ra'] as int; // default 24 hours
  int get backoffMechanismDuration => _sbs['bom_d'] as int; // default 60
  int get userPropertiesCacheLimit => _sbs['upcl'] as int; // default 100
  List get eventBlacklist => _sbs['eb'] as List; // default []
  List get userPropertiesBlacklist => _sbs['upb'] as List; // default []
  List get segmentationBlacklist => _sbs['sb'] as List; // default []
  Map get eventSegmentationBlacklist => _sbs['esb'] as Map; // default {}
  List get eventWhitelist => _sbs['ew'] as List; // default []
  List get userPropertiesWhitelist => _sbs['upw'] as List; // default []
  List get segmentationWhitelist => _sbs['sw'] as List; // default []
  Map get eventSegmentationWhitelist => _sbs['esw'] as Map; // default {}

  @visibleForTesting
  Map<String, dynamic> get snapshot => Map.unmodifiable(_sbs);

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
      'lbc': SBSDefaults.lbc,
      'ltlpt': SBSDefaults.ltlpt,
      'ltl': SBSDefaults.ltl,
      'cet': SBSDefaults.cet,
      'ecz': SBSDefaults.ecz,
      'czi': SBSDefaults.czi,
      // 'cr': _inst.config.requiresConsent, // NOT SUPPORTED
      'scui': SBSDefaults.scui,
      'rcz': SBSDefaults.rcz,
      'dort': SBSDefaults.dort,
      'bom': SBSDefaults.bom,
      'bom_at': SBSDefaults.bom_at,
      'bom_rqp': SBSDefaults.bom_rqp,
      'bom_ra': SBSDefaults.bom_ra,
      'bom_d': SBSDefaults.bom_d,
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
      if (cfg.sbs.isNotEmpty && cfg.sbs['c'] is Map<String, dynamic>) {
        _inst.L.i('BehaviorModule: loaded given SBS object=[${cfg.sbs.toString()}]');
        _applyOverrides(cfg.sbs['c'], source: 'config');
      }
      return;
    }
    ;
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
      final data = _inst._prepareRequest({})..['method'] = 'sc';
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
