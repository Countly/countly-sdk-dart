/// Android legacy data read from native Countly SDK storage.
class LegacyAndroidData {
  final String? deviceId;
  final String? deviceIdType;
  final String? requestQueue;
  final String? eventQueue;
  final String? remoteConfig;
  final String? serverConfig;
  final String? schemaVersion;

  const LegacyAndroidData({
    this.deviceId,
    this.deviceIdType,
    this.requestQueue,
    this.eventQueue,
    this.remoteConfig,
    this.serverConfig,
    this.schemaVersion,
  });

  bool get hasAny =>
      (deviceId?.isNotEmpty ?? false) ||
      (deviceIdType?.isNotEmpty ?? false) ||
      (requestQueue?.isNotEmpty ?? false) ||
      (eventQueue?.isNotEmpty ?? false) ||
      (remoteConfig?.isNotEmpty ?? false) ||
      (serverConfig?.isNotEmpty ?? false) ||
      (schemaVersion?.isNotEmpty ?? false);

  factory LegacyAndroidData.fromMap(Map<dynamic, dynamic> map) {
    return LegacyAndroidData(
      deviceId: map['deviceId'] as String?,
      deviceIdType: map['deviceIdType'] as String?,
      requestQueue: map['requestQueue'] as String?,
      eventQueue: map['eventQueue'] as String?,
      remoteConfig: map['remoteConfig'] as String?,
      serverConfig: map['serverConfig'] as String?,
      schemaVersion: map['schemaVersion'] as String?,
    );
  }
}

/// iOS legacy data read from native Countly SDK storage.
class LegacyIOSData {
  final String? deviceId;
  final String? nsuuid;
  final bool? isCustomDeviceId;
  final Map<String, dynamic>? remoteConfig;
  final Map<String, dynamic>? serverConfig;
  final List<String>? queuedRequests;
  final List<Map<String, dynamic>>? recordedEvents;
  final String? legacyAppKey;

  const LegacyIOSData({
    this.deviceId,
    this.nsuuid,
    this.isCustomDeviceId,
    this.remoteConfig,
    this.serverConfig,
    this.queuedRequests,
    this.recordedEvents,
    this.legacyAppKey,
  });

  bool get hasAny =>
      (deviceId?.isNotEmpty ?? false) ||
      (nsuuid?.isNotEmpty ?? false) ||
      (remoteConfig?.isNotEmpty ?? false) ||
      (serverConfig?.isNotEmpty ?? false) ||
      (queuedRequests?.isNotEmpty ?? false) ||
      (recordedEvents?.isNotEmpty ?? false) ||
      (legacyAppKey?.isNotEmpty ?? false);

  factory LegacyIOSData.fromMap(Map<dynamic, dynamic> map) {
    return LegacyIOSData(
      deviceId: map['deviceId'] as String?,
      nsuuid: map['nsuuid'] as String?,
      isCustomDeviceId: map['isCustomDeviceId'] as bool?,
      remoteConfig: (map['remoteConfig'] as Map?)?.cast<String, dynamic>(),
      serverConfig: (map['serverConfig'] as Map?)?.cast<String, dynamic>(),
      queuedRequests: (map['queuedRequests'] as List?)?.whereType<String>().toList(),
      recordedEvents: (map['recordedEvents'] as List?)
          ?.whereType<Map<dynamic, dynamic>>()
          .map((event) => event.cast<String, dynamic>())
          .toList(),
      legacyAppKey: map['legacyAppKey'] as String?,
    );
  }
}

class LegacyNativeData {
  final LegacyAndroidData? android;
  final LegacyIOSData? ios;
  const LegacyNativeData({this.android, this.ios});

  bool get hasAny => (android?.hasAny ?? false) || (ios?.hasAny ?? false);
}

/// Bridge interface implemented per-platform.
abstract class LegacyNativeBridge {
  Future<LegacyNativeData?> fetchLegacyData();
  Future<void> clearAndroidLegacyData();
  Future<void> clearIOSLegacyData();
}
