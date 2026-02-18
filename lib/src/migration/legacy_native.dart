import 'legacy_native_types.dart';
import 'legacy_native_stub.dart' if (dart.library.ui) 'legacy_native_flutter.dart';

export 'legacy_native_types.dart';

LegacyNativeBridge createLegacyNativeBridge() => legacyNativeBridgeFactory();

/// Exposed singleton bridge instance.
final LegacyNativeBridge legacyNativeBridge = createLegacyNativeBridge();
