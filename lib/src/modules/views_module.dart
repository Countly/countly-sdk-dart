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
  Future<void> startAutoStoppedView(String viewName) async {
    if (_inst._guardDisposed('views.startAutoStoppedView')) return;

    if (!(_inst._sbs?.isViewTrackingAllowed == true)) {
      _inst.L.d('View tracking disabled (SBS), skipping view start');
      return;
    }

    if (viewName.isEmpty) {
      _inst.L.e('views.startAutoStoppedView called with empty viewName');
      return;
    }
    if (!_inst.hasConsentInternal()) {
      _inst.L.v('View ["$viewName"] dropped: missing consent');
      return;
    }

    await _endIfActive();

    _inst._activeViewName = _inst._truncateKeyIfNeeded(viewName);
    final now = DateTime.now();
    _inst._activeViewStart = now;
    _lastBeatTime = now;
    _viewTime = 0;
    await _persistActiveViewState();
    _startHeartbeat();
    _inst.L.d('Started view name=[$viewName] at [$now]');
  }

  /// Ends currently active view if any.
  Future<void> endActiveView() async {
    if (_inst._guardDisposed('views.endActiveView')) return;
    await _endIfActive();
  }

  /// Ends currently active view if any. Used on dispose.
  Future<void> _endIfActive() async {
    if (!(_inst._sbs?.isViewTrackingAllowed == true)) {
      _inst.L.v('View tracking disabled (SBS), skipping view end');
      return;
    }

    if (_inst._activeViewName == null || _inst._activeViewStart == null) return;
    if (!_inst.hasConsentInternal()) return;
    final now = DateTime.now();
    final start = _inst._activeViewStart!;
    int durMs;
    final segmentation = <String, dynamic>{'name': _inst._activeViewName, 'visit': 1};
    durMs = now.difference(start).inMilliseconds;
    if (durMs < 0) durMs = 0;

    final evt = <String, dynamic>{
      'key': '[CLY]_view',
      'count': 1,
      'dur': durMs / 1000.0,
      'segmentation': segmentation,
      'timestamp': start.millisecondsSinceEpoch,
      'hour': start.hour,
      'dow': start.weekday % 7
    };
    await _inst._enqueueUserPropertiesCache();
    await _inst._addToEventQueue(evt);
    _inst.L.d('Ended view name=[${_inst._activeViewName}] durMs=[$durMs] mode=direct-diff');
    _inst._activeViewName = null;
    _inst._activeViewStart = null;
    _viewTime = 0;
    _lastBeatTime = null;
    await _clearPersistedActiveViewState();
    _cancelHeartbeat();
  }

  // storage of active view state for crash recovery
  Future<void> _persistActiveViewState() async {
    try {
      final name = _inst._activeViewName;
      final start = _inst._activeViewStart;
      if (name == null || start == null) return;
      if (_inst._isInUnknownConsentState) {
        _inst.L.v('In unknown consent state, skipping persisting active view state');
        return;
      }
      await _inst._storage
          .writeJson('COUNTLY_ACTIVE_VIEW', {'n': name, 'ts': start.millisecondsSinceEpoch, 'd': _viewTime});
    } catch (_) {}
  }

  Future<void> recoverView() async {
    try {
      final data = await _inst._storage.readJson<Map<String, dynamic>>('COUNTLY_ACTIVE_VIEW');
      if (data == null) return;
      _inst.L.d('Recovered view data: [$data]');
      final name = data['n'] as String;
      final startMs = data['ts'] as int;
      final time = data['d'] as int;
      final start = DateTime.fromMillisecondsSinceEpoch(startMs);
      int durMs = time;
      if (durMs < 0) durMs = 0;

      final evt = <String, dynamic>{
        'key': '[CLY]_view',
        'count': 1,
        'dur': durMs / 1000.0,
        'segmentation': {'name': name, 'visit': 1, 'recovered': 1},
        'timestamp': start.millisecondsSinceEpoch,
        'hour': start.hour,
        'dow': start.weekday % 7,
      };

      await _inst._addToEventQueue(evt); // TODO: request queue?
      _inst.L.i('Recovered unended view name=[$name] durMs=[$durMs]');
      await _clearPersistedActiveViewState();
    } catch (error) {
      _inst.L.e('Error recovering view', error: error);
    }
  }

  Future<void> _clearPersistedActiveViewState() async {
    try {
      await _inst._storage.remove('COUNTLY_ACTIVE_VIEW');
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

  Future<void> _onHeartbeat() async {
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
      await _persistActiveViewState();
      _inst.L.v('Heartbeat view=[${_inst._activeViewName}] cumulative time=[${_viewTime}]');
    }
  }

  @visibleForTesting
  void testSetupActiveViewForHeartbeat(String name, {int startOffsetMs = 0}) {
    _inst.L.v('Test setup active view for heartbeat with name=[$name] startOffsetMs=[$startOffsetMs]');
    _inst._activeViewName = _inst._truncateKeyIfNeeded(name);
    _inst._activeViewStart = DateTime.now().subtract(Duration(milliseconds: startOffsetMs));
    // leave _lastBeatTime null so the first heartbeat call sets it
    _lastBeatTime = null;
    _viewTime = 0;
  }

  @visibleForTesting
  Future<void> testHeartbeatOnce() async => await _onHeartbeat();
}
