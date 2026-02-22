import 'package:flutter/services.dart';

import 'legacy_native_types.dart';

const MethodChannel _channel = MethodChannel('countly_sdk_dart_core/migration');

LegacyNativeBridge legacyNativeBridgeFactory() => _FlutterLegacyNativeBridge();

class _FlutterLegacyNativeBridge implements LegacyNativeBridge {
  @override
  Future<LegacyNativeData?> fetchLegacyData() async {
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>?>('getLegacyData');
      if (raw == null || raw.isEmpty) return null;
      final androidMap = raw['android'];
      final iosMap = raw['ios'];
      final android = androidMap is Map ? LegacyAndroidData.fromMap(androidMap) : null;
      final ios = iosMap is Map ? LegacyIOSData.fromMap(iosMap) : null;
      final data = LegacyNativeData(android: android, ios: ios);
      return data.hasAny ? data : null;
    } catch (e) {
      // ignore: avoid_print
      // print('[countly-sdk-dart] migration: native bridge failed to fetch legacy data: $e');
      return null;
    }
  }

  @override
  Future<void> clearAndroidLegacyData() async {
    try {
      await _channel.invokeMethod('clearAndroidLegacyData');
    } catch (e) {
      // ignore: avoid_print
      // print('[countly-sdk-dart] migration: native bridge failed to clear Android legacy data: $e');
    }
  }

  @override
  Future<void> clearIOSLegacyData() async {
    try {
      await _channel.invokeMethod('clearIOSLegacyData');
    } catch (e) {
      // ignore: avoid_print
      // print('[countly-sdk-dart] migration: native bridge failed to clear iOS legacy data: $e');
    }
  }
}
