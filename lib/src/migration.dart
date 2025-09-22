/// TODO: useless?

import 'dart:convert';
import 'storage.dart';
import 'constants.dart';
import 'logging_helper.dart';

class MigrationService {
  final StorageFacade storage;
  final bool enabled;
  final InstanceLogger? L;

  MigrationService(this.storage, {required this.enabled, this.L});

  Future<void> migrateIfNeeded() async {
    if (!enabled) {
      L?.v('migration: disabled');
      return;
    }
    const legacyMain = 'COUNTLY_STORE';
    final raw = await storage.readString(legacyMain);
    if (raw == null) {
      L?.d('migration: no Android legacy key present, checking iOS keys');
      await _migrateFromIOSIfNeeded();
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        L?.i('migration: legacy data found, starting');
        final rq = decoded['CONNECTIONS'];
        final eq = decoded['EVENTS'];
        final rc = decoded['REMOTE_CONFIG'];
        final did = decoded['ly.count.android.api.DeviceId.id'];
        final didt = decoded['ly.count.android.api.DeviceId.type'];
        if (rq is String && rq.isNotEmpty) {
          final items = rq.split(':::').where((e) => e.isNotEmpty).toList();
          await storage.writeJson(StorageSubKeys.requestQueue, items);
          L?.d('migration: migrated request queue (${items.length} items)');
        }
        if (eq is String && eq.isNotEmpty) {
          final items = eq.split(':::').where((e) => e.isNotEmpty).toList();
          await storage.writeJson(StorageSubKeys.eventQueue, items);
          L?.d('migration: migrated event queue (${items.length} items)');
        }
        if (rc != null) {
          await storage.writeJson(StorageSubKeys.remoteConfig, rc);
          L?.d('migration: migrated remote config');
        }
        if (did is String) {
          await storage.writeString(StorageSubKeys.deviceId, did);
          L?.d('migration: migrated device id');
        }
        if (didt is String || didt is int) {
          await storage.writeString(StorageSubKeys.deviceIdType, didt.toString());
          L?.d('migration: migrated device id type');
        }
        // Remove legacy data
        await storage.remove(legacyMain);
        L?.i('migration: completed successfully');
      }
    } catch (err, st) {
      L?.w('migration: failed (ignored) error=$err stack=${st.toString().split('\n').first}');
    }
  }

  /// TODO: this will need native code to read iOS archived data. only device id is migrated for now.
  Future<void> _migrateFromIOSIfNeeded() async {
    const kStoredDeviceID = 'kCountlyStoredDeviceIDKey';

    final existingNew = await storage.readString(StorageSubKeys.deviceId);
    if (existingNew != null) {
      L?.v('migration(iOS): new device id already present -> skip');
      return;
    }

    final iosDeviceId = await storage.readString(kStoredDeviceID);
    if (iosDeviceId == null || iosDeviceId.isEmpty) {
      L?.d('migration(iOS): no legacy iOS device id key');
      return;
    }

    await storage.writeString(StorageSubKeys.deviceId, iosDeviceId);
    await storage.writeString(StorageSubKeys.deviceIdType, DeviceIdType.provided.toString());
    L?.i('migration(iOS): migrated device id');
  }
}
