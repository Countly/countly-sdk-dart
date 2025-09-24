part of sdk_instance_lib;

class SessionsModule {
  final SdkInstance _inst;
  SessionsModule(this._inst);

  DateTime? _sessionBeginTime;
  DateTime? _lastUpdateTime;
  bool get _isActive => _sessionBeginTime != null;

  /// Begins a session.
  void begin({Map<String, dynamic>? metricsOverride}) {
    if (_inst._guardDisposed('sessions.begin')) return;
    if (_isActive) {
      _inst.L.w('Session begin ignored: already active');
      return;
    }
    _sessionBeginTime = DateTime.now();
    _lastUpdateTime = _sessionBeginTime;

    Map<String, dynamic> metrics = {};
    if (_inst.hasConsentInternal(ConsentType.metrics)) {
      metrics = metrics_collector.getCurrentMetrics();
      if (metricsOverride != null) metrics.addAll(metricsOverride);
    }

    final data = {'begin_session': 1, if (metrics.isNotEmpty) 'metrics': metrics};
    _inst._enqueueUserPropertiesCache();
    _inst._addToRequestQueue(_inst._prepareRequest(data));
    _inst.L.i('Session begun');
  }

  /// Update request if session active.
  void sessionUpdate() {
    if (!_isActive) return;
    final now = DateTime.now();
    final last = _lastUpdateTime ?? _sessionBeginTime!;
    final dur = now.difference(last).inSeconds;
    if (dur <= 0) return;
    _lastUpdateTime = now;
    final data = {'session_duration': dur};
    _inst._enqueueUserPropertiesCache();
    _inst._addToRequestQueue(_inst._prepareRequest(data));
    _inst.L.d('Session update queued duration=[$dur]');
  }

  /// Ends a session.
  void end() {
    if (_inst._guardDisposed('sessions.end')) return;
    if (!_isActive) {
      _inst.L.w('Session end ignored: no active session');
      return;
    }
    final now = DateTime.now();
    final last = _lastUpdateTime ?? _sessionBeginTime!;
    final dur = now.difference(last).inSeconds;
    final data = {'end_session': 1, 'session_duration': dur};
    _inst._enqueueUserPropertiesCache();
    _inst._addToRequestQueue(_inst._prepareRequest(data));
    _sessionBeginTime = null;
    _lastUpdateTime = null;
    _inst.L.i('Session ended duration=[$dur]');
  }
}
