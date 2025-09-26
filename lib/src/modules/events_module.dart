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
  void record({required String key, int? count, double? sum, double? dur, Map<String, dynamic>? segmentation, DateTime? timestamp}) {
    if (_i._guardDisposed('events.record')) return;
    final internalConsentMap = <String, ConsentType?>{'[CLY]_nps': ConsentType.feedback, '[CLY]_survey': ConsentType.feedback, '[CLY]_star_rating': ConsentType.feedback, '[CLY]_view': ConsentType.views};
    ConsentType requiredConsent = ConsentType.events;
    if (internalConsentMap.containsKey(key)) {
      requiredConsent = internalConsentMap[key]!;
    }
    if (!_i.hasConsentInternal(requiredConsent)) {
      _i.L.w('Event ["$key"] dropped: missing consent for [${requiredConsent.name}]');
      return;
    }
    if (key.isEmpty) {
      _i.L.e('events.record called with empty key');
      return;
    }
    final ts = timestamp ?? DateTime.now(); // Can record past events with custom timestamp
    Map<String, dynamic> segOut = {};
    if (segmentation != null && segmentation.isNotEmpty) {
      segOut.addAll(segmentation);
    }
    segOut['pen'] = _i._previousEventKey ?? '';
    segOut['cvn'] = _i._activeViewName ?? '';
    final evt = <String, dynamic>{'key': key, 'count': count ?? 1, if (sum != null) 'sum': sum, if (dur != null) 'dur': dur, if (segOut.isNotEmpty) 'segmentation': segOut, 'timestamp': ts.millisecondsSinceEpoch, 'hour': ts.hour, 'dow': ts.weekday % 7};
    _i.L.d('Recording event key=[$key] count=[${count ?? 1}] sum=[${sum ?? 'n/a'}] dur=[${dur ?? 'n/a'}] segmentation=[${segmentation != null ? segmentation.toString() : 'n/a'}]');
    _i._enqueueUserPropertiesCache();
    _i._addToEventQueue(evt);
    _i._previousEventKey = key;
  }

  /// Sends a custom request with the given data.
  void customRequest(Map<String, dynamic> data) {
    final enriched = Map<String, dynamic>.from(data);
    enriched['cvn'] = _i._activeViewName ?? '';
    final req = _i._prepareRequest(enriched);
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
    if (metricOverride != null) metrics.addAll(metricOverride);
    final req = _i._prepareRequest({'metrics': metrics});
    _i._enqueueUserPropertiesCache();
    _i._addToRequestQueue(req);
    _i.L.d('Recorded metrics request: [${metrics.toString()}');
  }
}
