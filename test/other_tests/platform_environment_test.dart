import 'package:countly_sdk_dart_core/src/lifecycle/lifecycle_stub.dart' as lifecycle_stub;
import 'package:countly_sdk_dart_core/src/migration/legacy_native_types.dart';
import 'package:countly_sdk_dart_core/src/platform_environment.dart';
import 'package:countly_sdk_dart_core/countly.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLifecycleAdapter implements CountlyLifecycleAdapter {
  bool listenCalled = false;

  @override
  CountlyDisposeCallback listen({void Function()? onBackground, void Function()? onForeground}) {
    listenCalled = true;
    return () {};
  }
}

class _FakeMetricsAdapter implements CountlyMetricsAdapter {
  int collectCalls = 0;

  @override
  Map<String, dynamic> collectMetrics() {
    collectCalls++;
    return {
      '_os': 'FakeOS',
      '_device': 'FakeDevice',
      '_device_type': 'desktop',
      '_locale': 'en-US',
      '_app_version': '1.0.0',
    };
  }
}

class _FakeWarningPresenter implements CountlyWarningPresenter {
  bool invoked = false;

  @override
  bool get isAvailable => true;

  @override
  void showWarning(String message) {
    invoked = true;
  }
}

class _FakeLegacyMigrationAdapter implements CountlyLegacyMigrationAdapter {
  int fetchCalls = 0;

  @override
  Future<void> clearAndroidLegacyData() async {}

  @override
  Future<void> clearIOSLegacyData() async {}

  @override
  Future<LegacyNativeData?> fetchLegacyData() async {
    fetchCalls++;
    return null;
  }
}

class _FakeStorageAdapter implements CountlyStorageAdapter {
  final Map<String, String> _data = {};
  int writeCalls = 0;
  int readCalls = 0;
  int removeCalls = 0;

  @override
  Future<String?> read(String key) async {
    readCalls++;
    return _data[key];
  }

  @override
  Future<void> remove(String key) async {
    removeCalls++;
    _data.remove(key);
  }

  @override
  Future<void> write(String key, String value) async {
    writeCalls++;
    _data[key] = value;
  }
}

void main() {
  group('Platform environment - lifecycle adapters', () {
    setUp(() {
      lifecycle_stub.clearLifecycleListeners();
    });

    tearDown(() {
      lifecycle_stub.clearLifecycleListeners();
    });

    test('NoOpLifecycleAdapter listen returns callable dispose function', () {
      final adapter = NoOpLifecycleAdapter();
      final dispose = adapter.listen(
        onBackground: () {},
        onForeground: () {},
      );

      expect(dispose, isA<Function>());
      expect(() => dispose(), returnsNormally);
    });

    test('CoreLifecycleAdapter forwards callbacks to lifecycle stub', () {
      final adapter = CoreLifecycleAdapter();
      var backgroundCalls = 0;
      var foregroundCalls = 0;

      final dispose = adapter.listen(
        onBackground: () => backgroundCalls++,
        onForeground: () => foregroundCalls++,
      );

      lifecycle_stub.simulateBackground();
      lifecycle_stub.simulateForeground();

      expect(backgroundCalls, 1);
      expect(foregroundCalls, 1);

      dispose();
      lifecycle_stub.simulateBackground();
      lifecycle_stub.simulateForeground();

      expect(backgroundCalls, 1);
      expect(foregroundCalls, 1);
    });
  });

  group('Platform environment - metrics adapters', () {
    test('NoOpMetricsAdapter returns empty map', () {
      final adapter = NoOpMetricsAdapter();

      expect(adapter.collectMetrics(), isEmpty);
    });

    test('CoreMetricsAdapter returns metrics without _os_version', () {
      final adapter = CoreMetricsAdapter();
      final metrics = adapter.collectMetrics();

      expect(metrics, isNotEmpty);
      expect(metrics['_os'], isA<String>());
      expect(metrics['_device'], isA<String>());
      expect(metrics['_device_type'], isA<String>());
      expect(metrics['_locale'], isA<String>());
      expect(metrics['_app_version'], isA<String>());
      expect(metrics.containsKey('_os_version'), isFalse);
    });
  });

  group('Platform environment - no-op implementations', () {
    test('NoOpWarningPresenter is unavailable and does not throw', () {
      final presenter = NoOpWarningPresenter();

      expect(presenter.isAvailable, isFalse);
      expect(() => presenter.showWarning('warning'), returnsNormally);
    });

    test('NoOpLegacyMigrationAdapter returns null and clear calls succeed', () async {
      final adapter = NoOpLegacyMigrationAdapter();

      expect(await adapter.fetchLegacyData(), isNull);
      await adapter.clearAndroidLegacyData();
      await adapter.clearIOSLegacyData();
    });

    test('NoOpStorageAdapter reads null and write/remove do not throw', () async {
      final adapter = NoOpStorageAdapter();

      expect(await adapter.read('missing'), isNull);
      await adapter.write('k', 'v');
      await adapter.remove('k');
      expect(await adapter.read('k'), isNull);
    });
  });

  group('CountlyPlatformEnvironment', () {
    test('defaults to core lifecycle/metrics and no-op others', () {
      const env = CountlyPlatformEnvironment();

      expect(env.lifecycleAdapter, isA<CoreLifecycleAdapter>());
      expect(env.metricsAdapter, isA<CoreMetricsAdapter>());
      expect(env.warningPresenter, isA<NoOpWarningPresenter>());
      expect(env.legacyMigrationAdapter, isA<NoOpLegacyMigrationAdapter>());
      expect(env.storageAdapter, isA<NoOpStorageAdapter>());
    });

    test('uses custom injected adapters', () {
      final lifecycle = _FakeLifecycleAdapter();
      final metrics = _FakeMetricsAdapter();
      final warning = _FakeWarningPresenter();
      final migration = _FakeLegacyMigrationAdapter();
      final storage = _FakeStorageAdapter();

      final env = CountlyPlatformEnvironment(
        lifecycleAdapter: lifecycle,
        metricsAdapter: metrics,
        warningPresenter: warning,
        legacyMigrationAdapter: migration,
        storageAdapter: storage,
      );

      expect(identical(env.lifecycleAdapter, lifecycle), isTrue);
      expect(identical(env.metricsAdapter, metrics), isTrue);
      expect(identical(env.warningPresenter, warning), isTrue);
      expect(identical(env.legacyMigrationAdapter, migration), isTrue);
      expect(identical(env.storageAdapter, storage), isTrue);

      env.lifecycleAdapter.listen();
      expect(lifecycle.listenCalled, isTrue);

      final collected = env.metricsAdapter.collectMetrics();
      expect(collected['_os'], 'FakeOS');

      env.warningPresenter.showWarning('test warning');
      expect(warning.invoked, isTrue);
    });
  });

  group('Platform environment smoke', () {
    tearDown(() async {
      await Countly.disposeAll();
    });

    test('Countly init uses injected lifecycle, metrics, migration and storage adapters', () async {
      final lifecycle = _FakeLifecycleAdapter();
      final metrics = _FakeMetricsAdapter();
      final migration = _FakeLegacyMigrationAdapter();
      final storage = _FakeStorageAdapter();

      final env = CountlyPlatformEnvironment(
        lifecycleAdapter: lifecycle,
        metricsAdapter: metrics,
        legacyMigrationAdapter: migration,
        storageAdapter: storage,
      );

      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        deviceId: 'smoke-device',
        storageMode: StorageMode.persistent,
        giveConsent: true,
        platformEnvironment: env,
      );

      await Countly.init(cfg);

      expect(lifecycle.listenCalled, isTrue);
      expect(metrics.collectCalls, greaterThan(0));
      expect(migration.fetchCalls, greaterThan(0));
      expect(storage.readCalls, greaterThan(0));
      expect(storage.writeCalls, greaterThan(0));
    });
  });
}
