part of sdk_instance_lib;

class ViewsModule {
  final CountlyInstance _inst;
  ViewsModule(this._inst);

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

    endIfActive(); // End existing view if any

    // Start new view (record start event)
    _inst._activeViewName = viewName;
    _inst._activeViewStart = DateTime.now();

    final seg = {'name': viewName, 'visit': 1, 'pvn': _inst._previousViewName ?? ''};
    _inst.L.d('Starting view name=[$viewName]');
    final startTs = _inst._activeViewStart!;
    final evt = <String, dynamic>{
      'key': '[CLY]_view',
      'count': 1,
      'segmentation': seg,
      'timestamp': startTs.millisecondsSinceEpoch,
      'hour': startTs.hour,
      'dow': startTs.weekday % 7,
    };
    _inst._addToEventQueue(evt);
    _inst._previousViewName = viewName;
  }

  /// Ends currently active view if any. Used on dispose.
  void endIfActive() {
    if (!(_inst._sbs?.isViewTrackingAllowed == true)) {
      _inst.L.v('View tracking disabled (SBS), skipping view end');
      return;
    }

    if (_inst._activeViewName == null || _inst._activeViewStart == null) return;
    if (!_inst.hasConsentInternal(ConsentType.views)) return;
    final now = DateTime.now();
    final durMs = now.difference(_inst._activeViewStart!).inMilliseconds;
    final evt = <String, dynamic>{
      'key': '[CLY]_view',
      'count': 1,
      'dur': durMs / 1000.0,
      'segmentation': {'name': _inst._activeViewName, 'pvn': _inst._previousViewName ?? ''},
      'timestamp': now.millisecondsSinceEpoch,
      'hour': now.hour,
      'dow': now.weekday % 7,
    };
    _inst._addToEventQueue(evt);
    _inst.L.d('Ended active view name=[${_inst._activeViewName}] durMs=[$durMs]');
    _inst._activeViewName = null;
    _inst._activeViewStart = null;
  }
}
