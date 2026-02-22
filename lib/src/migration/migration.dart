/// ## Android Migration
/// The Android SDK stores data in SharedPreferences with preference name "COUNTLY_STORE".
/// Keys are stored directly (not nested JSON):
/// - `CONNECTIONS` - Request queue (delimiter: `:::`)
/// - `EVENTS` - Event queue (delimiter: `:::`)
/// - `ly.count.android.api.DeviceId.id` - Device ID
/// - `ly.count.android.api.DeviceId.type` - Device ID type
/// - `REMOTE_CONFIG` - Remote config values (JSON string)
/// - `SERVER_CONFIG` - Server config (JSON string)
///
/// ## iOS Migration
/// The iOS SDK stores most data in NSUserDefaults (accessible via SharedPreferences):
/// - `kCountlyStoredDeviceIDKey` - Device ID
/// - `kCountlyStoredNSUUIDKey` - UUID for generated ID
/// - `kCountlyIsCustomDeviceIDKey` - Boolean indicating custom ID
/// - `kCountlyRemoteConfigKey` - Remote config (NSDictionary)
/// - `kCountlyServerConfigPersistencyKey` - Server config (NSDictionary)
/// However, request and event queues are stored in a file using NSKeyedArchiver

import 'dart:convert';
import '../storage/storage.dart';
import '../constants.dart';
import '../logging/logging_helper.dart';
import 'legacy_native.dart';

/// Keys used by the Android SDK (CountlyStore.java)
class _AndroidLegacyKeys {
  static const requestQueue = 'CONNECTIONS';
  static const eventQueue = 'EVENTS';
  static const deviceId = 'ly.count.android.api.DeviceId.id';
  static const deviceIdType = 'ly.count.android.api.DeviceId.type';
  static const remoteConfig = 'REMOTE_CONFIG';
  static const serverConfig = 'SERVER_CONFIG';
  static const schemaVersion = 'SCHEMA_VERSION';
  static const delimiter = ':::';
}

/// Keys used by the iOS SDK (CountlyPersistency.m)
class _IOSLegacyKeys {
  static const deviceId = 'kCountlyStoredDeviceIDKey';
  static const nsuuid = 'kCountlyStoredNSUUIDKey';
  static const isCustomDeviceId = 'kCountlyIsCustomDeviceIDKey';
  static const remoteConfig = 'kCountlyRemoteConfigKey';
  static const serverConfig = 'kCountlyServerConfigPersistencyKey';
}

class MigrationService {
  final StorageFacade storage;
  final bool enabled;
  final InstanceLogger? L;
  final LegacyNativeBridge _nativeBridge;

  MigrationService(this.storage, {required this.enabled, this.L, LegacyNativeBridge? nativeBridge})
      : _nativeBridge = nativeBridge ?? legacyNativeBridge;

  /// Runs migration if needed. Checks for Android data first, then iOS.
  /// Migration is skipped if new Dart SDK data already exists.
  Future<void> migrateIfNeeded() async {
    if (!enabled) {
      L?.v('migration: disabled');
      return;
    }

    final nativeData = await _nativeBridge.fetchLegacyData();
    if (nativeData == null || !nativeData.hasAny) {
      L?.d('migration(native): no legacy data returned by native bridge');
    }

    // Check if new SDK data already exists (no migration needed)
    final existingDeviceId = await storage.readString(StorageSubKeys.deviceId);
    if (existingDeviceId != null && existingDeviceId.isNotEmpty) {
      L?.v('migration: new SDK data already present -> skip');
      return;
    }

    // Try Android migration first
    final androidMigrated = await _migrateFromAndroidIfNeeded(nativeData?.android);
    if (androidMigrated) {
      await _nativeBridge.clearAndroidLegacyData();
      return;
    }

    // Try iOS migration
    final iosMigrated = await _migrateFromIOSIfNeeded(nativeData?.ios);
    if (iosMigrated) {
      await _nativeBridge.clearIOSLegacyData();
    }
  }

  /// Attempts to migrate data from Android SDK.
  /// Android SDK stores data directly in SharedPreferences (not nested JSON).
  /// Returns true if migration was performed.
  Future<bool> _migrateFromAndroidIfNeeded(LegacyAndroidData? native) async {
    final androidDeviceId = native?.deviceId ?? await storage.readString(_AndroidLegacyKeys.deviceId);
    if (androidDeviceId == null || androidDeviceId.isEmpty) {
      L?.d('migration(Android): no legacy Android data found');
      return false;
    }

    L?.i('migration(Android): legacy data found, starting migration');
    bool migrated = false;

    try {
      // Migrate Device ID
      await storage.writeString(StorageSubKeys.deviceId, androidDeviceId);
      L?.d('migration(Android): migrated device id');
      migrated = true;

      // Migrate Device ID Type
      final androidDeviceIdType = native?.deviceIdType ?? await storage.readString(_AndroidLegacyKeys.deviceIdType);
      if (androidDeviceIdType != null && androidDeviceIdType.isNotEmpty) {
        // Android uses string types: "DEVELOPER_SUPPLIED", "SDK_GENERATED", etc.
        // Map to our internal type values
        final mappedType = _mapAndroidDeviceIdType(androidDeviceIdType);
        await storage.writeString(StorageSubKeys.deviceIdType, mappedType.toString());
        L?.d('migration(Android): migrated device id type ($androidDeviceIdType -> $mappedType)');
      }

      List<dynamic> migratedRequestQueueItems = const [];

      // Migrate Request Queue (delimiter separated string)
      final androidRq = native?.requestQueue ?? await storage.readString(_AndroidLegacyKeys.requestQueue);
      if (androidRq != null && androidRq.isNotEmpty) {
        final items = androidRq.split(_AndroidLegacyKeys.delimiter).where((e) => e.isNotEmpty).toList();
        if (items.isNotEmpty) {
          migratedRequestQueueItems = List<dynamic>.from(items);
          await storage.writeJson(StorageSubKeys.requestQueue, migratedRequestQueueItems);
          L?.d('migration(Android): migrated request queue (${items.length} items)');
        }
      }

      // Migrate Event Queue (delimiter separated string, each item is JSON)
      final androidEq = native?.eventQueue ?? await storage.readString(_AndroidLegacyKeys.eventQueue);
      if (androidEq != null && androidEq.isNotEmpty) {
        final items = androidEq.split(_AndroidLegacyKeys.delimiter).where((e) => e.isNotEmpty).toList();
        if (items.isNotEmpty) {
          // Parse and re-serialize events to ensure valid format
          final events = <Map<String, dynamic>>[];
          for (final item in items) {
            try {
              final decoded = jsonDecode(item);
              if (decoded is Map<String, dynamic>) {
                events.add(decoded);
              }
            } catch (e) {
              L?.w('migration(Android): failed to parse event: $e');
            }
          }
          if (events.isNotEmpty) {
            final legacyEnvelope = _extractLegacyEnvelopeFromRequestQueue(migratedRequestQueueItems, androidDeviceId);
            if (legacyEnvelope != null) {
              final legacyEventsRequest = {
                ...legacyEnvelope,
                'events': events,
              };
              final updatedRq = List<dynamic>.from(migratedRequestQueueItems)..add(legacyEventsRequest);
              await storage.writeJson(StorageSubKeys.requestQueue, updatedRq);
              migratedRequestQueueItems = updatedRq;
              L?.d('migration(Android): migrated event queue as legacy request (${events.length} events)');
            } else {
              await storage.writeJson(StorageSubKeys.eventQueue, events);
              L?.d('migration(Android): migrated event queue (${events.length} events)');
            }
          }
        }
      }

      // Clean up legacy Android keys
      await _cleanupAndroidLegacyData();

      L?.i('migration(Android): completed successfully');
    } catch (err, st) {
      L?.w(
          'migration(Android): failed (partial migration may have occurred) error=$err stack=${st.toString().split('\n').first}');
    }

    return migrated;
  }

  Map<String, dynamic>? _extractLegacyEnvelopeFromRequestQueue(List<dynamic> requestItems, String fallbackDeviceId) {
    if (requestItems.isEmpty) {
      return null;
    }

    for (final item in requestItems) {
      final parsed = _parseLegacyRequestItem(item);
      if (parsed == null) {
        continue;
      }

      final appKey = parsed['app_key'];
      if (appKey is! String || appKey.isEmpty) {
        continue;
      }

      final envelope = <String, dynamic>{
        'app_key': appKey,
        'device_id': (parsed['device_id'] is String && (parsed['device_id'] as String).isNotEmpty)
            ? parsed['device_id']
            : fallbackDeviceId,
      };

      if (parsed['sdk_version'] != null) envelope['sdk_version'] = parsed['sdk_version'];
      if (parsed['sdk_name'] != null) envelope['sdk_name'] = parsed['sdk_name'];
      if (parsed['av'] != null) envelope['av'] = parsed['av'];
      return envelope;
    }

    return null;
  }

  Map<String, dynamic>? _parseLegacyRequestItem(dynamic item) {
    if (item is Map<String, dynamic>) {
      return item;
    }
    if (item is! String || item.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(item);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}

    if (!item.contains('=')) {
      return null;
    }

    try {
      final query = Uri.splitQueryString(item, encoding: utf8);
      if (query.isEmpty) {
        return null;
      }
      final parsed = <String, dynamic>{};
      query.forEach((key, value) {
        parsed[key] = _coerceLegacyQueryValue(value);
      });
      return parsed;
    } catch (_) {
      return null;
    }
  }

  dynamic _coerceLegacyQueryValue(String value) {
    if (value.isEmpty) return value;

    final lower = value.toLowerCase();
    if (lower == 'true') return true;
    if (lower == 'false') return false;

    final intValue = int.tryParse(value);
    if (intValue != null) return intValue;

    final doubleValue = double.tryParse(value);
    if (doubleValue != null) return doubleValue;

    final firstChar = value[0];
    if (firstChar == '{' || firstChar == '[') {
      try {
        return jsonDecode(value);
      } catch (_) {
        return value;
      }
    }

    return value;
  }

  /// Maps Android SDK device ID type strings to our internal type values.
  int _mapAndroidDeviceIdType(String androidType) {
    // Android SDK types from DeviceId.java / CountlyStore.java:
    // "DEVELOPER_SUPPLIED" -> custom/provided
    // "SDK_GENERATED" -> generated
    // "OPEN_UDID", "ADVERTISING_ID" -> also SDK generated variants
    switch (androidType.toUpperCase()) {
      case 'SDK_GENERATED':
      case 'OPEN_UDID':
      case 'ADVERTISING_ID':
        return DeviceIdType.generated;
      case 'DEVELOPER_SUPPLIED':
      default:
        return DeviceIdType.provided;
    }
  }

  /// Cleans up legacy Android keys after successful migration.
  Future<void> _cleanupAndroidLegacyData() async {
    try {
      await storage.remove(_AndroidLegacyKeys.deviceId);
      await storage.remove(_AndroidLegacyKeys.deviceIdType);
      await storage.remove(_AndroidLegacyKeys.requestQueue);
      await storage.remove(_AndroidLegacyKeys.eventQueue);
      await storage.remove(_AndroidLegacyKeys.remoteConfig);
      await storage.remove(_AndroidLegacyKeys.serverConfig);
      await storage.remove(_AndroidLegacyKeys.schemaVersion);
      L?.d('migration(Android): cleaned up legacy keys');
    } catch (e) {
      L?.w('migration(Android): cleanup failed (non-critical): $e');
    }
  }

  /// Attempts to migrate data from iOS SDK.
  /// iOS SDK stores device ID and settings in NSUserDefaults.
  /// Request/event queues are stored in a file using NSKeyedArchiver
  Future<bool> _migrateFromIOSIfNeeded(LegacyIOSData? native) async {
    // Check for iOS device ID as indicator of iOS data presence
    final iosDeviceId = native?.deviceId ?? await storage.readString(_IOSLegacyKeys.deviceId);
    final iosNsuuid = native?.nsuuid ?? await storage.readString(_IOSLegacyKeys.nsuuid);

    // Either the stored device ID or the NSUUID (used for generated IDs) indicates iOS data
    final hasIosData = (iosDeviceId != null && iosDeviceId.isNotEmpty) || (iosNsuuid != null && iosNsuuid.isNotEmpty);

    if (!hasIosData) {
      L?.d('migration(iOS): no legacy iOS data found');
      return false;
    }

    L?.i('migration(iOS): legacy data found, starting migration');
    bool migrated = false;

    try {
      // Determine device ID and type
      String? deviceId;
      int deviceIdType = DeviceIdType.generated;

      // Check if custom device ID was set
      final isCustomIdStr =
          native?.isCustomDeviceId?.toString() ?? await storage.readString(_IOSLegacyKeys.isCustomDeviceId);
      final isCustomId = isCustomIdStr == '1' || isCustomIdStr?.toLowerCase() == 'true';

      if (iosDeviceId != null && iosDeviceId.isNotEmpty) {
        deviceId = iosDeviceId;
        deviceIdType = isCustomId ? DeviceIdType.provided : DeviceIdType.generated;
      } else if (iosNsuuid != null && iosNsuuid.isNotEmpty) {
        // NSUUID is used as fallback for generated device IDs on watchOS/macOS
        deviceId = iosNsuuid;
        deviceIdType = DeviceIdType.generated;
      }

      if (deviceId != null) {
        await storage.writeString(StorageSubKeys.deviceId, deviceId);
        await storage.writeString(StorageSubKeys.deviceIdType, deviceIdType.toString());
        L?.d(
            'migration(iOS): migrated device id (type=${deviceIdType == DeviceIdType.provided ? 'custom' : 'generated'})');
        migrated = true;
      }

      final queuedRequests = native?.queuedRequests;
      if (queuedRequests != null && queuedRequests.isNotEmpty) {
        await storage.writeJson(StorageSubKeys.requestQueue, queuedRequests);
        L?.d('migration(iOS): migrated request queue (${queuedRequests.length} items)');
        migrated = true;
      }
      // Clean up legacy iOS keys
      await _cleanupIOSLegacyData();

      L?.i('migration(iOS): completed successfully');
    } catch (err, st) {
      L?.w(
          'migration(iOS): failed (partial migration may have occurred) error=$err stack=${st.toString().split('\n').first}');
    }

    return migrated;
  }

  /// Cleans up legacy iOS keys after successful migration.
  Future<void> _cleanupIOSLegacyData() async {
    try {
      await storage.remove(_IOSLegacyKeys.deviceId);
      await storage.remove(_IOSLegacyKeys.nsuuid);
      await storage.remove(_IOSLegacyKeys.isCustomDeviceId);
      await storage.remove(_IOSLegacyKeys.remoteConfig);
      await storage.remove(_IOSLegacyKeys.serverConfig);
      L?.d('migration(iOS): cleaned up legacy keys');
    } catch (e) {
      L?.w('migration(iOS): cleanup failed (non-critical): $e');
    }
  }
}
