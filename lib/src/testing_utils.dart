part of sdk_instance_lib;

/// Internal testing utilities.
extension SdkInstanceTesting on SdkInstance {
  @visibleForTesting
  void debugOverrideBehaviorSettings({int? eventQueueSize, int? requestQueueSize, int? timerIntervalSeconds}) {
    final overrides = <String, dynamic>{};
    if (eventQueueSize != null) overrides['eqs'] = eventQueueSize;
    if (requestQueueSize != null) overrides['rqs'] = requestQueueSize;
    if (timerIntervalSeconds != null) overrides['sui'] = timerIntervalSeconds;
    if (overrides.isEmpty) return;
    _sbs?.debugApplyOverrides(overrides);
    if (timerIntervalSeconds != null) _startTimer();
  }
}
