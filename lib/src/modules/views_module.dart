part of sdk_instance_lib;

class ViewsModule {
  final CountlyInstance _inst;
  ViewsModule(this._inst);

  static const int _heartbeatInterval = 15; // seconds
  Timer? _heartbeatTimer;
  int _viewTime = 0; // ms
  DateTime? _lastBeatTime;

  /// Starts a view that ends automatically when another view is started or on dispose.
  /// [viewName] must be non-empty.
  void startAutoStoppedView(String viewName) {
    if (_inst._guardDisposed('views.startAutoStoppedView')) return;

    if (!(_inst._sbs?.isViewTrackingAllowed == true)) {
      _inst.L.d('View tracking disabled (SBS), skipping view start');
      return;
    }

    if (viewName.isEmpty) {
      _inst.L.w('views.startAutoStoppedView called with empty viewName');
      return;
    }
    if (!_inst.hasConsentInternal(ConsentType.views)) {
      _inst.L.v('View ["$viewName"] dropped: missing views consent');
      return;
    }

    _endIfActive();

    _inst._activeViewName = viewName;
    final now = DateTime.now();
    _inst._activeViewStart = now;
    _lastBeatTime = now;
    _viewTime = 0;
    _inst._lastClosedViewName = null;
    _persistActiveViewState();
    _startHeartbeat();
    _inst.L.d('Started view name=[$viewName] at [$now]');
  }

  /// Ends currently active view if any. Used on dispose.
  void _endIfActive() {
    if (!(_inst._sbs?.isViewTrackingAllowed == true)) {
      _inst.L.v('View tracking disabled (SBS), skipping view end');
      return;
    }

    if (_inst._activeViewName == null || _inst._activeViewStart == null) return;
    if (!_inst.hasConsentInternal(ConsentType.views)) return;
    final now = DateTime.now();
    final start = _inst._activeViewStart!;
    int durMs;
    final segmentation = <String, dynamic>{'name': _inst._activeViewName, 'pvn': _inst._previousViewName ?? '', 'visit': 1};
    durMs = now.difference(start).inMilliseconds;
    if (durMs < 0) durMs = 0;

    final evt = <String, dynamic>{'key': '[CLY]_view', 'count': 1, 'dur': durMs / 1000.0, 'segmentation': segmentation, 'timestamp': start.millisecondsSinceEpoch, 'hour': start.hour, 'dow': start.weekday % 7};
    _inst._addToEventQueue(evt);
    _inst.L.d('Ended view name=[${_inst._activeViewName}] durMs=[$durMs] mode=direct-diff');
    _inst._previousViewName = _inst._activeViewName;
    _inst._activeViewName = null;
    _inst._activeViewStart = null;
    _viewTime = 0;
    _lastBeatTime = null;
    _clearPersistedActiveViewState();
    _cancelHeartbeat();
  }

  // storage of active view state for crash recovery
  void _persistActiveViewState() {
    try {
      final name = _inst._activeViewName;
      final start = _inst._activeViewStart;
      if (name == null || start == null) return;
      _inst._storage.writeJson('COUNTLY_ACTIVE_VIEW', {'n': name, 'ts': start.millisecondsSinceEpoch, 'd': _viewTime, 'pvn': _inst._previousViewName ?? ''});
    } catch (_) {}
  }

  Future<void> recoverView() async {
    try {
      final data = await _inst._storage.readJson<Map<String, dynamic>>('COUNTLY_ACTIVE_VIEW');
      if (data == null) return;
      final name = data['n'];
      final startMs = data['ts'];
      final time = data['d'];
      final pvn = data['pvn'];
      final start = DateTime.fromMillisecondsSinceEpoch(startMs);
      int durMs = time;
      if (durMs < 0) durMs = 0;
      final evt = <String, dynamic>{
        'key': '[CLY]_view',
        'count': 1,
        'dur': durMs / 1000.0,
        'segmentation': {'name': name, 'pvn': pvn, 'visit': 1, 'recovered': 1},
        'timestamp': start.millisecondsSinceEpoch,
        'hour': start.hour,
        'dow': start.weekday % 7,
      };
      _inst._addToEventQueue(evt);
      _inst.L.i('Recovered unended view name=[$name] durMs=[$durMs]');
      _clearPersistedActiveViewState();
    } catch (error) {
      _inst.L.e('Error recovering view', error: error);
    }
  }

  void _clearPersistedActiveViewState() {
    try {
      _inst._storage.remove('COUNTLY_ACTIVE_VIEW');
    } catch (_) {}
  }

  void _startHeartbeat() {
    _cancelHeartbeat();
    _heartbeatTimer = Timer.periodic(Duration(seconds: _heartbeatInterval), (_) => _onHeartbeat());
  }

  void _cancelHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _onHeartbeat() {
    if (_inst._activeViewName == null || _inst._activeViewStart == null) {
      _cancelHeartbeat();
      return;
    }
    if (_lastBeatTime == null) {
      _lastBeatTime = DateTime.now();
      return;
    }
    final now = DateTime.now();
    final beatDur = now.difference(_lastBeatTime!).inMilliseconds;
    if (beatDur > 0) {
      _viewTime += beatDur;
      _lastBeatTime = now;
      _persistActiveViewState();
      _inst.L.v('Heartbeat view=[${_inst._activeViewName}] cumulative time=[${_viewTime}]');
    }
  }
}
