import 'dart:async';
import 'dart:convert';

import '../config.dart';
import '../logging/logging_helper.dart';
import '../platform_environment.dart';

abstract class StorageEngine {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> remove(String key);
}

// Adapter that wraps the platform-specific persistent storage engine.
class _PersistentAdapter implements StorageEngine {
  final CountlyStorageAdapter inner;
  _PersistentAdapter(this.inner);
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
  final CountlyConfig config;
  final InstanceLogger? L;
  final String namespace;
  late final StorageEngine _engine;

  StorageFacade(this.config, this.namespace, {this.L}) {
    if (config.storageMethods != null && config.storageMethods!.hasAny) {
      _engine = _CustomStorageEngine(config.storageMethods!);
      L?.d('storage: using custom storage methods');
    } else if (config.storageMode == StorageMode.persistent) {
      if (config.platformEnvironment.storageAdapter is NoOpStorageAdapter) {
        _engine = MemoryStorageEngine();
        L?.w('storage: persistent mode requested but no storage adapter injected, falling back to in-memory engine');
      } else {
        _engine = _PersistentAdapter(config.platformEnvironment.storageAdapter);
        L?.d('storage: using persistent adapter from platform environment');
      }
    } else {
      _engine = MemoryStorageEngine();
      L?.d('storage: using in-memory engine');
    }
  }

  String _nsKey(String key) {
    if (namespace.isEmpty) {
      return key;
    }
    return '${namespace}_$key';
  }

  /// Write a JSON-serializable object.
  Future<void> writeJson(String key, Object value) async {
    final encoded = jsonEncode(value);
    // L?.v('storage.writeJson key=$key bytes=${encoded.length}');
    await _engine.write(_nsKey(key), encoded);
  }

  /// Read and parse a JSON object, or null if not found or parse error.
  Future<T?> readJson<T>(String key) async {
    final raw = await _engine.read(_nsKey(key));
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
    // L?.v('storage.writeString key=$key len=${value.length}');
    await _engine.write(_nsKey(key), value);
  }

  /// Read a raw string value.
  Future<String?> readString(String key) async {
    // L?.v('storage.readString key=$key');
    return _engine.read(_nsKey(key));
  }

  /// Remove a key.
  Future<void> remove(String key) async {
    // L?.v('storage.remove key=$key');
    await _engine.remove(_nsKey(key));
  }
}
