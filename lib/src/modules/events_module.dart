part of sdk_instance_lib;

class EventsModule {
  final CountlyInstance _i;
  EventsModule(this._i);

  /// Records an event with the given parameters.
  /// The [key] must be non-empty and is the only required parameter.
  /// The [count] defaults to 1 if not provided.
  /// The [sum] and [dur] are optional double values.
  /// The [segmentation] is an optional map of key-value pairs (String to primitive types).
  /// The [timestamp] can be provided to record past events; if omitted, current time is used.
  void record(
      {required String key,
      int? count,
      double? sum,
      double? dur,
      Map<String, dynamic>? segmentation,
      DateTime? timestamp}) {
    if (_i._guardDisposed('events.record')) return;
    final internalConsentMap = <String, ConsentType?>{
      '[CLY]_nps': ConsentType.feedback,
      '[CLY]_survey': ConsentType.feedback,
      '[CLY]_star_rating': ConsentType.feedback,
      '[CLY]_view': ConsentType.views
    };
    ConsentType requiredConsent = ConsentType.events;
    if (internalConsentMap.containsKey(key)) {
      requiredConsent = internalConsentMap[key]!;
    }
    if (!_i.hasConsentInternal(requiredConsent)) {
      _i.L.w('Event ["$key"] dropped: missing consent for [${requiredConsent.name}]');
      return;
    }
    if (_i._sbs!.isCustomEventTrackingAllowed == false && requiredConsent == ConsentType.events) {
      _i.L.d('Event tracking disabled (SBS), skipping event record');
      return;
    }
    if (key.isEmpty) {
      _i.L.e('events.record called with empty key');
      return;
    }
    if (_i._sbs!.eventWhitelist.isNotEmpty) {
      if (!_i._sbs!.eventWhitelist.contains(key)) {
        _i.L.w('Event ["$key"] dropped: not in whitelist');
        return;
      }
    } else if (_i._sbs!.eventBlacklist.contains(key)) {
      _i.L.w('Event ["$key"] dropped: blacklisted key');
      return;
    }

    segmentation = _i.removeGraylistedSegmentation(segmentation, key); // both whitelist and blacklist
    key = _i._truncateKeyIfNeeded(key);
    final ts = timestamp ?? DateTime.now(); // Can record past events with custom timestamp
    Map<String, dynamic> segOut = {};
    if (segmentation != null && segmentation.isNotEmpty) {
      segOut.addAll(_i._sanitizeSegmentation(segmentation));
    }

    final evt = <String, dynamic>{
      'key': key,
      'count': count ?? 1,
      if (sum != null) 'sum': sum,
      if (dur != null) 'dur': dur,
      if (segOut.isNotEmpty) 'segmentation': segOut,
      'timestamp': ts.millisecondsSinceEpoch,
      'hour': ts.hour,
      'dow': ts.weekday % 7
    };
    _i.L.d(
        'Recording event key=[$key] count=[${count ?? 1}] sum=[${sum ?? 'n/a'}] dur=[${dur ?? 'n/a'}] segmentation=[${segmentation != null ? segmentation.toString() : 'n/a'}]');
    _i._enqueueUserPropertiesCache();
    _i._addToEventQueue(evt);
    _i._previousEventKey = key;
  }

  /// Sends a custom request with the given data.
  /// [data] should be key-value pairs of request parameters and its value.
  void customRequest(Map<String, dynamic> data) {
    if (data.isEmpty) {
      _i.L.e('customRequest called with empty data');
      return;
    }
    final tempData = <String, dynamic>{};
    data.forEach((key, value) {
      var k = _i._truncateKeyIfNeeded(key);
      dynamic v = value;
      if (v is String) {
        v = _i._truncateValueIfNeeded(v);
      } else if (v is Map<String, dynamic>) {
        v = _i._sanitizeSegmentation(v);
      }
      tempData[k] = v;
    });
    final req = _i._prepareRequest(tempData);
    _i._enqueueUserPropertiesCache();
    _i._addToRequestQueue(req);
  }

  /// Collects device metrics and adds a request to request queue.
  /// The provided [metricOverride] map is shallow-merged onto collected values (overriding conflicts).
  void recordMetrics({Map<String, dynamic>? metricOverride}) {
    if (_i._guardDisposed('events.recordMetrics')) return;
    if (!_i.hasConsentInternal(ConsentType.metrics)) {
      _i.L.v('Metrics collection skipped: missing metrics consent');
      return;
    }
    final metrics = metrics_collector.getCurrentMetrics();
    if (metricOverride != null && metricOverride.isNotEmpty) {
      metrics.addAll(_i._sanitizeSegmentation(metricOverride));
    }
    final req = _i._prepareRequest({'metrics': metrics});
    _i._enqueueUserPropertiesCache();
    _i._addToRequestQueue(req);
    _i.L.d('Recorded metrics request: [${metrics.toString()}');
  }
}
