import 'migration/legacy_native_types.dart';
import 'metrics/metrics_collector.dart' as metrics_collector;
import 'lifecycle/lifecycle_stub.dart' as lifecycle_stub;

typedef CountlyDisposeCallback = void Function();

abstract class CountlyLifecycleAdapter {
  CountlyDisposeCallback listen({void Function()? onBackground, void Function()? onForeground});
}

abstract class CountlyMetricsAdapter {
  Map<String, dynamic> collectMetrics();
}

abstract class CountlyWarningPresenter {
  bool get isAvailable;
  void showWarning(String message);
}

abstract class CountlyLegacyMigrationAdapter {
  Future<LegacyNativeData?> fetchLegacyData();
  Future<void> clearAndroidLegacyData();
  Future<void> clearIOSLegacyData();
}

abstract class CountlyStorageAdapter {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> remove(String key);
}

class NoOpLifecycleAdapter implements CountlyLifecycleAdapter {
  const NoOpLifecycleAdapter();

  @override
  CountlyDisposeCallback listen({void Function()? onBackground, void Function()? onForeground}) => () {};
}

class CoreLifecycleAdapter implements CountlyLifecycleAdapter {
  const CoreLifecycleAdapter();

  @override
  CountlyDisposeCallback listen({void Function()? onBackground, void Function()? onForeground}) {
    return lifecycle_stub.listenToLifecycle(onBackground: onBackground, onForeground: onForeground);
  }
}

class CoreMetricsAdapter implements CountlyMetricsAdapter {
  const CoreMetricsAdapter();

  @override
  Map<String, dynamic> collectMetrics() => metrics_collector.getCurrentMetrics();
}

class NoOpMetricsAdapter implements CountlyMetricsAdapter {
  const NoOpMetricsAdapter();

  @override
  Map<String, dynamic> collectMetrics() => <String, dynamic>{};
}

class NoOpWarningPresenter implements CountlyWarningPresenter {
  const NoOpWarningPresenter();

  @override
  bool get isAvailable => false;

  @override
  void showWarning(String message) {}
}

class NoOpLegacyMigrationAdapter implements CountlyLegacyMigrationAdapter {
  const NoOpLegacyMigrationAdapter();

  @override
  Future<void> clearAndroidLegacyData() async {}

  @override
  Future<void> clearIOSLegacyData() async {}

  @override
  Future<LegacyNativeData?> fetchLegacyData() async => null;
}

class NoOpStorageAdapter implements CountlyStorageAdapter {
  const NoOpStorageAdapter();

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> remove(String key) async {}

  @override
  Future<void> write(String key, String value) async {}
}

class CountlyPlatformEnvironment {
  final CountlyLifecycleAdapter lifecycleAdapter;
  final CountlyMetricsAdapter metricsAdapter;
  final CountlyWarningPresenter warningPresenter;
  final CountlyLegacyMigrationAdapter legacyMigrationAdapter;
  final CountlyStorageAdapter storageAdapter;

  const CountlyPlatformEnvironment({
    this.lifecycleAdapter = const CoreLifecycleAdapter(),
    this.metricsAdapter = const CoreMetricsAdapter(),
    this.warningPresenter = const NoOpWarningPresenter(),
    this.legacyMigrationAdapter = const NoOpLegacyMigrationAdapter(),
    this.storageAdapter = const NoOpStorageAdapter(),
  });
}
