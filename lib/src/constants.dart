import 'package:meta/meta.dart';

@internal
class StorageSubKeys {
  static const requestQueue = 'COUNTLY_DART_RQ';
  static const eventQueue = 'COUNTLY_DART_EQ';
  static const deviceId = 'COUNTLY_DART_ID';
  static const deviceIdType = 'COUNTLY_DART_IDT';
  static const behavior = 'COUNTLY_DART_SBS';
}

/// Device ID type values
@internal
class DeviceIdType {
  /// Provided by user.
  static const provided = 1;

  /// Generated UUID.
  static const generated = 2;
}

/// SDK metadata
@internal
class SdkInternal {
  static const sdkVersion = '1.0.0';
  static const sdkName = 'countly-sdk-dart';
  static const appVersion = '1.0.0';
  static const requestTimeoutSeconds = 60;
}

@internal
class Endpoints {
  static const i = '/i';
  static const sdk = '/o/sdk';
}

/// Default values for SDK behavior settings.
@internal
class SBSDefaults {
  static const tracking = true; // Allow all tracking
  static const networking = true; // Allow sending requests
  static const rqs = 1000; // Request queue size (requests)
  static const eqs = 100; // Event queue size (events)
  static const sui = 60; // Session update interval (seconds) // TODO: Check if this is the only internal timer flag
  // static const st = true; // Allow session tracking - NOT SUPPORTED
  // static const crt = true; // Allow crash tracking - NOT SUPPORTED
  static const lt = true; // Allow location tracking
  static const vt = true; // Allow view tracking
  static const lkl = 128; // Key length limit (chars)
  static const lvs = 256; // Value size limit (chars)
  static const lsv = 100; // Segmentation values count limit (key/values)
  static const lbc = 100; // Breadcrumb count limit
  static const ltlpt = 30; // Stack trace line count limit (lines)
  static const ltl = 200; // Stack trace line length limit (chars)
  static const cet = true; // Allow custom event tracking
  static const ecz = false; // Enter Content Zone after init
  static const czi = 30; // Content Zone request interval (seconds)
  // static const cr = false; // Consent required - NOT SUPPORTED
  static const scui = 4 * 60 * 60; // Server config update interval (seconds, 4 hours)
  static const rcz = true; // Allow Refresh Content Zone
  static const dort = 0; // Drop old request time (disabled)
  static const bom = true; // Backoff mechanism enabled
  static const bom_at = 10; // Backoff mechanism accepted timeout (seconds)
  static const bom_rqp = 0.5; // Backoff mechanism request queue % (0-1)
  static const bom_ra = 24 * 60 * 60; // Backoff mechanism request age (seconds, 24 hours)
  static const bom_d = 60; // Backoff mechanism duration (seconds)
  static const upcl = 100; // User properties cache limit (key/value pairs)
  static const eb = []; // Event blacklist
  static const upb = []; // User properties blacklist
  static const sb = []; // Segmentation blacklist
  static const esb = <String, dynamic>{}; // Event segmentation blacklist
  static const ew = []; // Event whitelist
  static const upw = []; // User property whitelist
  static const sw = []; // Segment whitelist
  static const esw = <String, dynamic>{}; // Event segment whitelist
}
