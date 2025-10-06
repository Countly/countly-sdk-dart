// For choosing platform-specific implementation (conditional imports).
import 'metrics_stub.dart'
    if (dart.library.html) 'metrics_web.dart'
    if (dart.library.ui) 'metrics_flutter.dart'
    if (dart.library.io) 'metrics_io.dart' as impl;

Map<String, dynamic> getCurrentMetrics() => impl.getCurrentMetrics();
String? getOrientation() => impl.getOrientation();
