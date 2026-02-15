import 'legacy_native_types.dart';

LegacyNativeBridge legacyNativeBridgeFactory() => _StubLegacyNativeBridge();

class _StubLegacyNativeBridge implements LegacyNativeBridge {
  @override
  Future<void> clearAndroidLegacyData() async {}

  @override
  Future<void> clearIOSLegacyData() async {}

  @override
  Future<LegacyNativeData?> fetchLegacyData() async => null;
}
