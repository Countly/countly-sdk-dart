part of sdk_instance_lib;

class DeviceIdModule {
  final CountlyInstance _inst;
  DeviceIdModule(this._inst);

  // Changes the current device ID for the same user (use this for same user to change what their device ID should be in the server)
  Future<void> changeWithMerge(String newDeviceId) async {
    if (_inst._guardDisposed('id.changeWithMerge')) return;
    if (newDeviceId.isEmpty) {
      _inst.L.e('id.changeWithMerge called with empty newDeviceId');
      return;
    }
    if (newDeviceId == _inst._deviceId) {
      _inst.L.d('id.changeWithMerge called with the same deviceId, no change needed');
      return;
    }

    final oldDeviceId = _inst._deviceId;
    _inst.L.i('Changing device ID with merge from [$oldDeviceId] to [$newDeviceId]');

    // Update internal device id first so that merge request uses the new id.
    await _inst._setDeviceIdInternal(newDeviceId, type: DeviceIdType.provided);

    // Enqueue merge request containing old_device_id so backend can merge profiles.
    if (oldDeviceId != null && oldDeviceId.isNotEmpty) {
      final req = _inst._prepareRequest({'old_device_id': oldDeviceId});
      _inst._addToRequestQueue(req);
      _inst.L.d('Enqueued device ID merge request with old_device_id=[$oldDeviceId]');
    }
  }

  // Changes the current device ID to a new one, without merging data (use this for new users)
  // This somewhat equals to reinitializing the SDK with a new device ID
  // Open view will be stopped, queues will be flushed for old ID,
  // SDK will enter unknown consent state.
  Future<void> changeWithoutMerge(String newDeviceId) async {
    if (_inst._guardDisposed('id.changeWithoutMerge')) return;
    if (newDeviceId.isEmpty) {
      _inst.L.e('id.changeWithoutMerge called with empty newDeviceId');
      return;
    }
    if (newDeviceId == _inst._deviceId) {
      _inst.L.d('id.changeWithoutMerge called with the same deviceId, no change needed');
      return;
    }

    final oldDeviceId = _inst._deviceId;
    _inst.L.i('Changing device ID without merge from [$oldDeviceId] to [$newDeviceId]');

    // Stop any open view so its data is finalized under the old device id.
    _inst._viewsModule?._endIfActive();

    await _inst.processEventsAndRequests();
    _inst._clearAllDataQueuesAndCaches();

    await _inst._setDeviceIdInternal(newDeviceId, type: DeviceIdType.provided);
    _inst._consentGranted = true; // To allow tracking.
    _inst._isInUnknownConsentState = true;
    _inst.L.i('SDK entered unknown consent state after device ID change without merge. Give consent to resume data delivery.');
  }
}
