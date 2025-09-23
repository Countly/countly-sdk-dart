part of sdk_instance_lib;

class RemoteConfigModule {
  final SdkInstance _inst;
  final Map<String, dynamic> _experimentInfo = {};
  final Map<String, dynamic> _variantInfo = {};
  RemoteConfigModule(this._inst);

  /// Fetches remote config from server and stores it locally.
  /// Returns true on success, false otherwise.
  Future<bool> fetch() async {
    if (_inst._guardDisposed('remoteConfig.fetch')) return false;
    if (!_inst.hasConsentInternal(ConsentType.remoteConfig)) {
      _inst.L.w('Remote config request skipped: no remoteConfig consent');
      return false;
    }
    final base = _inst._prepareRequest({});
    final data = base..['method'] = 'rc';
    final metrics = metrics_collector.getCurrentMetrics();
    data['metrics'] = metrics;
    try {
      final resp = await _inst._network.makeRequest(data, Endpoints.sdk);
      if (_inst._network.isResponseValid(resp, acceptJSON: true)) {
        final decoded = jsonDecode(resp.body);
        _inst._remoteConfigValues = decoded;
        _inst.L.i('Remote config downloaded as=[${decoded.toString()}]');
        await _inst._storage.writeJson(StorageSubKeys.remoteConfig, decoded);
        return true;
      } else {
        _inst.L.w('Remote config request failed: invalid response');
        return false;
      }
    } catch (e, st) {
      _inst.L.e('Remote config request failed', error: e, stack: st);
      return false;
    }
  }

  /// Gets the value for the given key from the last fetched remote config.
  /// Additionally, enrolls the user for A/B testing for that key.
  /// Returns null if key not found or on error.
  /// Note: this does NOT trigger a fetch; fetch must be called separately.
  Future<dynamic> getValueAndEnroll(String key) async {
    _inst.L.d('Remote config key requested: [$key]');
    if (_inst._guardDisposed('remoteConfig.getValueAndEnroll')) return null;
    if (key.isEmpty) {
      _inst.L.e('remoteConfig.getValueAndEnroll called with empty key');
      return null;
    }
    if (!_inst.hasConsentInternal(ConsentType.remoteConfig)) {
      _inst.L.w('Remote config value request dropped: missing remoteConfig consent');
      return null;
    }
    if (!_inst._remoteConfigValues.containsKey(key)) {
      _inst.L.d('Remote config key not found: [$key]');
      return null;
    }
    final metrics = metrics_collector.getCurrentMetrics();
    final req = _inst._prepareRequest({
      'method': 'ab',
      'keys': [key],
      'metrics': metrics,
    });
    _inst._addToRequestQueue(req);
    _inst.L.d('Enrollment request for key [$key] queued');
    return _inst._remoteConfigValues[key];
  }

  /// Enrolls to A/B test for a given key by adding a request to the queue.
  /// Returns true if successfully queued, false otherwise.
  Future<bool> enroll(String key) async {
    if (_inst._guardDisposed('remoteConfig.enroll')) return false;
    if (key.isEmpty) {
      _inst.L.e('remoteConfig.enroll called with empty key');
      return false;
    }
    if (!_inst.hasConsentInternal(ConsentType.remoteConfig)) {
      _inst.L.w('Enroll request skipped: no remoteConfig consent');
      return false;
    }
    final metrics = metrics_collector.getCurrentMetrics();
    final req = _inst._prepareRequest({
      'method': 'ab',
      'keys': [key],
      'metrics': metrics,
    });
    _inst._addToRequestQueue(req);
    _inst.L.d('Enrollment request for key [$key] queued (explicit enroll)');
    return true;
  }



  /// Clears in-memory and persisted remote config values.
  Future<void> clearStoredValues() async {
    if (_inst._guardDisposed('remoteConfig.clearStoredValues')) return;
    _inst._remoteConfigValues = {};
    await _inst._storage.writeJson(StorageSubKeys.remoteConfig, {});
    _experimentInfo.clear();
    _variantInfo.clear();
    _inst.L.i('Cleared stored remote config values');
  }

  /// Test helper: Directly un-enroll from A/B test for a given key via immediate request.
  /// Returns true if request succeeded.
  Future<bool> testUnEnroll(String key) async {
    if (_inst._guardDisposed('remoteConfig.testUnEnroll')) return false;
    if (key.isEmpty) {
      _inst.L.e('testUnEnroll called with empty key');
      return false;
    }
    if (!_inst.hasConsentInternal(ConsentType.remoteConfig)) {
      _inst.L.w('testUnEnroll skipped: missing consent');
      return false;
    }
    final metrics = metrics_collector.getCurrentMetrics();
    final data = _inst._prepareRequest({
      'method': 'ab_opt_out',
      'keys': [key],
      'metrics': metrics,
    });
    try {
      final resp = await _inst._network.makeRequest(data, Endpoints.sdk);
      final ok = _inst._network.isResponseValid(resp, acceptJSON: true);
      if (!ok) _inst.L.w('testUnEnroll failed for key [$key]');
      return ok;
    } catch (e, st) {
      _inst.L.e('testUnEnroll network error', error: e, stack: st);
      return false;
    }
  }

  /// Test helper: Directly enroll into a specific variant for a key.
  /// Returns true on success.
  Future<bool> testEnrollVariant(String key, String variant) async {
    if (_inst._guardDisposed('remoteConfig.testEnrollVariant')) return false;
    if (key.isEmpty || variant.isEmpty) {
      _inst.L.e('testEnrollVariant called with empty key or variant');
      return false;
    }
    if (!_inst.hasConsentInternal(ConsentType.remoteConfig)) {
      _inst.L.w('testEnrollVariant skipped: missing consent');
      return false;
    }
    final metrics = metrics_collector.getCurrentMetrics();
    final data = _inst._prepareRequest({'method': 'ab_enroll_variant', 'key': key, 'variant': variant, 'metrics': metrics});
    try {
      final resp = await _inst._network.makeRequest(data, Endpoints.sdk);
      final ok = _inst._network.isResponseValid(resp, acceptJSON: true);
      if (!ok) _inst.L.w('testEnrollVariant failed for key [$key] variant [$variant]');
      return ok;
    } catch (e, st) {
      _inst.L.e('testEnrollVariant network error', error: e, stack: st);
      return false;
    }
  }

  /// Test helper: Download full experiment information (including variants) directly.
  /// On success stores the data internally and returns decoded value; else null.
  Future<dynamic> testDownloadExpInfo() async {
    if (_inst._guardDisposed('remoteConfig.testDownloadExpInfo')) return null;
    if (!_inst.hasConsentInternal(ConsentType.remoteConfig)) {
      _inst.L.w('testDownloadExpInfo skipped: missing consent');
      return null;
    }
    final metrics = metrics_collector.getCurrentMetrics();
    final data = _inst._prepareRequest({'method': 'ab_fetch_experiments', 'metrics': metrics});
    try {
      final resp = await _inst._network.makeRequest(data, Endpoints.sdk);
      if (_inst._network.isResponseValid(resp, acceptJSON: true)) {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic>) {
          _experimentInfo
            ..clear()
            ..addAll(decoded);
          // extract variants list
          for (final entry in decoded.entries) {
            if (entry.value is Map && (entry.value as Map).containsKey('variants')) {
              final vs = (entry.value as Map)['variants'];
              _variantInfo[entry.key] = vs;
            }
          }
        }
        _inst.L.d('Experiment info downloaded keys=[${_experimentInfo.keys.join(', ')}]');
        return decoded;
      }
      _inst.L.w('testDownloadExpInfo failed: invalid response');
      return null;
    } catch (e, st) {
      _inst.L.e('testDownloadExpInfo network error', error: e, stack: st);
      return null;
    }
  }

  /// Test helper: Returns last downloaded experiment info (immutable snapshot).
  Map<String, dynamic> testGetExpInfo() => Map.unmodifiable(_experimentInfo);

  /// Returns all recorded remote config values (immutable snapshot).
  Map<String, dynamic> getValues() => Map.unmodifiable(_inst._remoteConfigValues);
}
