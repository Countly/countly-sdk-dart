part of sdk_instance_lib;

class CrashesModule {
  final CountlyInstance _inst;
  CrashesModule(this._inst);

  /// Records an exception
  /// [exception] stack trace, [isHandled] handled or unhandled
  /// Optional [segmentation] custom key/value pairs
  /// Optional [name] name of the exception
  void recordException(String exception, String exceptionName, bool isHandled, [Map<String, Object>? segmentation]) {
    if (_inst._guardDisposed('crashes.recordException')) return;

    if (!(_inst._sbs?.isCrashTrackingAllowed ?? true)) {
      _inst.L.d('Crash tracking disabled (SBS), skipping recordException');
      return;
    }
    if (!_inst.hasConsentInternal(ConsentType.crashes)) {
      _inst.L.w('Crash dropped: missing crashes consent');
      return;
    }
    _inst.L.d(
        'Recording exception: handled=[$isHandled] name=[$exceptionName], segmentation=[$segmentation], exception=[$exception]');
    if (exception.trim().isEmpty) {
      _inst.L.e('recordException called with empty exception string');
      return;
    }

    final sanitizedStack = _inst._sanitizeStackTrace(exception);
    final linesFirst = sanitizedStack.split('\n').first.trim();
    final name =
        exceptionName.isEmpty ? _inst._truncateKeyIfNeeded(linesFirst) : _inst._truncateKeyIfNeeded(exceptionName);
    final runSeconds = DateTime.now().difference(_inst._sdkStartTime).inSeconds;

    final crash = <String, dynamic>{
      '_name': name,
      '_error': sanitizedStack,
      '_nonfatal': isHandled,
      '_run': runSeconds
    };

    final o = metrics_collector.getOrientation();
    if (o != null) crash['_orientation'] = o;
    crash['_background'] = _inst._isInBackground;

    crash.addAll(metrics_collector.getCurrentMetrics());

    if (segmentation != null && segmentation.isNotEmpty) {
      crash['_custom'] = _inst._sanitizeSegmentation(segmentation.cast<String, dynamic>(), forCrash: true);
    }

    final req = _inst._prepareRequest({'crash': crash});
    _inst.L.i('Recording crash handled=[$req]');
    _inst._enqueueUserPropertiesCache();
    _inst._addToRequestQueue(req);
    _inst.L.i('Recorded crash name=[$name] handled=[$isHandled]');
  }
}
