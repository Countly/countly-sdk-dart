// Stub (fallback) metrics implementation for unsupported platforms.
import '../constants.dart';

Map<String, dynamic> getCurrentMetrics() => {
      '_os': 'unknown',
      '_os_version': 'unknown',
      '_device': 'unknown',
      '_device_type': 'desktop',
      '_locale': 'en-US',
      '_app_version': SdkInternal.sdkVersion,
    };
