part of sdk_instance_lib;

class RemoteConfigModule {
  final SdkInstance _inst;
  RemoteConfigModule(this._inst);

  /// Fetches remote config from server and stores it locally.
  Future<void> fetch() async {
    if (_inst._guardDisposed('remoteConfig.fetch')) return;
    if (!_inst.hasConsentInternal(ConsentType.remoteConfig)) {
      _inst.L.w('Remote config request skipped: no remoteConfig consent');
      return;
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
      } else {
        _inst.L.w('Remote config request failed: invalid response');
      }
    } catch (e, st) {
      _inst.L.e('Remote config request failed', error: e, stack: st);
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
    final base = _inst._prepareRequest({});
    final data =
        base
          ..['method'] = 'ab'
          ..['keys'] = [key];
    final metrics = metrics_collector.getCurrentMetrics();
    data['metrics'] = metrics;
    final resp = await _inst._network.makeRequest(data, Endpoints.sdk);
    if (_inst._network.isResponseValid(resp, acceptJSON: true)) {
      _inst.L.d('Enrolled for key [$key] successful');
    } else {
      _inst.L.w('Enrollment for key [$key] failed: invalid response');
      return null;
    }

    return _inst._remoteConfigValues[key];
  }

  @visibleForTesting
  Map<String, dynamic> get peekValuesForTesting => Map.unmodifiable(_inst._remoteConfigValues);
}
