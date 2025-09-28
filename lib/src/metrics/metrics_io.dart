import 'dart:io' show Platform;
import '../constants.dart';

Map<String, dynamic> getCurrentMetrics() {
  return {
    '_os': _platformName(),
    '_os_version': _platformVersion(),
    '_device':
        _deviceName(), // TODO: this might be generic 'hostname' on desktops plus some other info. Check.
    '_device_type': _inferDeviceType(),
    '_locale': _locale(),
    '_app_version': SdkInternal.sdkVersion,
  };
}

String? getOrientation() => null;

String _platformName() {
  if (Platform.isLinux) return 'Linux';
  if (Platform.isMacOS) return 'macOS';
  if (Platform.isWindows) return 'Windows';
  if (Platform.isAndroid) return 'Android';
  if (Platform.isIOS) return 'iOS';
  if (Platform.isFuchsia) return 'Fuchsia';
  return Platform.operatingSystem;
}

String _platformVersion() => Platform.version;
String _inferDeviceType() =>
    (Platform.isAndroid || Platform.isIOS) ? 'mobile' : 'desktop';
String _locale() {
  try {
    return Platform.localeName.replaceAll('_', '-');
  } catch (_) {
    return 'en-US';
  }
}

String _deviceName() {
  try {
    final h = Platform.localHostname;
    if (h.isNotEmpty) return h;
  } catch (_) {}
  return 'unknown';
}
