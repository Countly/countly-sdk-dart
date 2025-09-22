import 'dart:async';
import 'dart:convert';

import 'config.dart';
import 'logging_helper.dart';

// TODO: We import shared_preferences only here; in pure dart environments user can provide custom methods or memory mode. A file-based engine can be added for dart.
import 'storage_persistent_stub.dart' if (dart.library.ui) 'storage_persistent_flutter.dart';

abstract class StorageEngine {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> remove(String key);
}

// Adapter that wraps the platform-specific persistent storage engine.
class _PersistentAdapter implements StorageEngine {
  final PersistentStorageEngine inner = PersistentStorageEngine();
  @override
  Future<String?> read(String key) => inner.read(key);
  @override
  Future<void> remove(String key) => inner.remove(key);
  @override
  Future<void> write(String key, String value) => inner.write(key, value);
}

/// In-memory (ephemeral) storage.
class MemoryStorageEngine implements StorageEngine {
  final Map<String, String> _m = {};

  @override
  Future<void> write(String key, String value) async => _m[key] = value;

  @override
  Future<String?> read(String key) async => _m[key];

  @override
  Future<void> remove(String key) async => _m.remove(key);
}

// Adapter that wraps user-provided custom storage functions.
class _CustomStorageEngine implements StorageEngine {
  final CustomStorageMethods methods;
  _CustomStorageEngine(this.methods);

  @override
  Future<String?> read(String key) async => methods.read?.call(key);

  @override
  Future<void> remove(String key) async => methods.remove?.call(key);

  @override
  Future<void> write(String key, String value) async => methods.write?.call(key, value);
}

/// Wrapper that chooses engine based on config, or uses custom user functions.
class StorageFacade {
  final SdkConfig config;
  final InstanceLogger? L;
  late final StorageEngine _engine;

  StorageFacade(this.config, {this.L}) {
    if (config.storageMethods != null && config.storageMethods!.hasAny) {
      _engine = _CustomStorageEngine(config.storageMethods!);
      L?.d('storage: using custom storage methods');
    } else if (config.storageMode == StorageMode.persistent) {
      _engine = _PersistentAdapter();
      L?.d('storage: using persistent engine');
    } else {
      _engine = MemoryStorageEngine();
      L?.d('storage: using in-memory engine');
    }
  }

  /// Write a JSON-serializable object.
  Future<void> writeJson(String key, Object value) async {
    final encoded = jsonEncode(value);
    L?.v('storage.writeJson key=$key bytes=${encoded.length}');
    await _engine.write(key, encoded);
  }

  /// Read and parse a JSON object, or null if not found or parse error.
  Future<T?> readJson<T>(String key) async {
    final raw = await _engine.read(key);
    if (raw == null) {
      L?.v('storage.readJson key=[$key] -> null');
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      L?.v('storage.readJson key=[$key] decodedType=${decoded.runtimeType}');
      return decoded as T;
    } catch (e) {
      L?.w('storage.readJson key=[$key] parse failed error=$e');
      return null;
    }
  }

  /// Write a raw string value.
  Future<void> writeString(String key, String value) async {
    L?.v('storage.writeString key=[$key] length=${value.length}');
    await _engine.write(key, value);
  }

  /// Read a raw string value, or null if not found.
  Future<String?> readString(String key) async {
    final v = await _engine.read(key);
    L?.v('storage.readString key=[$key] hit=${v != null}');
    return v;
  }

  /// Remove a stored value.
  Future<void> remove(String key) async {
    L?.v('storage.remove key=[$key]');
    await _engine.remove(key);
  }
}
