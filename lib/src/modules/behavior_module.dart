part of sdk_instance_lib;

class BehaviorModule {
  final SdkInstance _inst;
  BehaviorModule(this._inst);

  final Map<String, dynamic> _sbs = {};

  /// getters for SBS values to be used in SdkInstance
  bool get trackingEnabled => _sbs['tracking']; // default true
  bool get networkingEnabled => _sbs['networking']; // default true
  int get eventQueueSize => _sbs['eqs']; // default 100
  int get requestQueueSize => _sbs['rqs']; // default 50
  int get internalTimerInterval => _sbs['sui']; // default 60
  int get isSessionTrackingAllowed => _sbs['st']; // default 1
  int get isCrashTrackingAllowed => _sbs['crt']; // default 1
  int get isLocationTrackingAllowed => _sbs['lt']; // default 1
  int get isViewTrackingAllowed => _sbs['vt']; // default 1
  int get keyLengthLimit => _sbs['lkl']; // default 128
  int get valueSizeLimit => _sbs['lvs']; // default 256
  int get segmentationValuesLimit => _sbs['lsv']; // default 100
  int get breadcrumbCountLimit => _sbs['lbc']; // default 100
  int get stackTraceLineCountLimit => _sbs['ltlpt']; // default 30
  int get stackTraceLineLengthLimit => _sbs['ltl']; // default 200
  int get isCustomEventTrackingAllowed => _sbs['cet']; // default 1
  int get enterContentZoneAfterInit => _sbs['ecz']; // default 0
  int get contentZoneRequestInterval => _sbs['czi']; // default 30
  int get isConsentRequired => _sbs['cr']; // default 0
  int get serverConfigUpdateInterval => _sbs['scui']; // default 4 hours
  int get isRefreshContentZoneAllowed => _sbs['rcz']; // default 1
  int get dropOldRequestTime => _sbs['dort']; // default 0 (disabled)
  int get isBackoffMechanismEnabled => _sbs['bom']; // default 1
  int get backoffMechanismAcceptedTimeout => _sbs['bom_at']; // default 10
  double get backoffMechanismRequestQueuePercent => _sbs['bom_rqp']; // default 0.5
  int get backoffMechanismRequestAge => _sbs['bom_ra']; // default 24 hours
  int get backoffMechanismDuration => _sbs['bom_d']; // default 60
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
      'tracking': SdkBehaviorSettingsDefaults.tracking,
      'networking': SdkBehaviorSettingsDefaults.networking,
      'eqs': SdkBehaviorSettingsDefaults.eqs,
      'rqs': SdkBehaviorSettingsDefaults.rqs,
      'sui': SdkBehaviorSettingsDefaults.sui,
      'st': SdkBehaviorSettingsDefaults.st,
      'crt': SdkBehaviorSettingsDefaults.crt,
      'lt': SdkBehaviorSettingsDefaults.lt,
      'vt': SdkBehaviorSettingsDefaults.vt,
      'lkl': SdkBehaviorSettingsDefaults.lkl,
      'lvs': SdkBehaviorSettingsDefaults.lvs,
      'lsv': SdkBehaviorSettingsDefaults.lsv,
      'lbc': SdkBehaviorSettingsDefaults.lbc,
      'ltlpt': SdkBehaviorSettingsDefaults.ltlpt,
      'ltl': SdkBehaviorSettingsDefaults.ltl,
      'cet': SdkBehaviorSettingsDefaults.cet,
      'ecz': SdkBehaviorSettingsDefaults.ecz,
      'czi': SdkBehaviorSettingsDefaults.czi,
      'cr': _inst.config.requiresConsent ? 1 : 0,
      'scui': SdkBehaviorSettingsDefaults.scui,
      'rcz': SdkBehaviorSettingsDefaults.rcz,
      'dort': SdkBehaviorSettingsDefaults.dort,
      'bom': SdkBehaviorSettingsDefaults.bom,
      'bom_at': SdkBehaviorSettingsDefaults.bom_at,
      'bom_rqp': SdkBehaviorSettingsDefaults.bom_rqp,
      'bom_ra': SdkBehaviorSettingsDefaults.bom_ra,
      'bom_d': SdkBehaviorSettingsDefaults.bom_d,
    });
    _inst.L.d('BehaviorModule: defaults initialized');
  }

  /// Load persisted SBS object and apply any overrides.
  Future<void> _loadPersisted() async {
    final cfg = _inst.config;
    if (cfg.storageMode != StorageMode.persistent && !(cfg.storageMethods?.hasAny ?? false)) return;
    final stored = await _inst._storage.readJson<Map<String, dynamic>>(StorageSubKeys.behavior);
    if (stored == null) return;
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
    overrides.forEach((k, v) {
      if (_sbs.containsKey(k)) {
        _sbs[k] = v;
        applied++;
        _inst.L.d('BehaviorModule override ($source): [$k]=[$v]');
      }
    });
    if (applied > 0) _inst.L.i('BehaviorModule: applied [$applied] overrides from [$source]');
  }

  /// Fetch latest SBS from server and apply any overrides.
  /// Persists the full response for future use.
  Future<void> fetchLatest() async {
    if (_inst._guardDisposed('behaviorModule.fetchLatest')) return;
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
