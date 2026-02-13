import 'dart:io' show Platform;
import 'dart:ui' as ui;
import '../constants.dart';

Map<String, dynamic> getCurrentMetrics() {
  final window = ui.PlatformDispatcher.instance.views.isNotEmpty ? ui.PlatformDispatcher.instance.views.first : null;
  final pixelRatio = window?.devicePixelRatio;
  final size = window?.physicalSize;
  return {
    '_os': _platformName(),
    '_os_version': Platform.version.split(' ').first, // we want version until first space
    '_device': _deviceModel(),
    '_device_type': _inferDeviceType(),
    if (size != null) '_resolution': '${size.width.toInt()}x${size.height.toInt()}',
    if (pixelRatio != null) '_density': pixelRatio,
    '_locale': _locale(),
    if (size != null && (size.width != 0 || size.height != 0)) '_orientation': size.height >= size.width ? 'portrait' : 'landscape',
    '_app_version': SdkInternal.sdkVersion,
  };
}

String _platformName() {
  if (Platform.isAndroid) return 'Android';
  if (Platform.isIOS) return 'iOS';
  if (Platform.isMacOS) return 'macOS';
  if (Platform.isLinux) return 'Linux';
  if (Platform.isWindows) return 'Windows';
  return Platform.operatingSystem;
}

String _inferDeviceType() => (Platform.isAndroid || Platform.isIOS) ? 'mobile' : 'desktop';
String _locale() {
  try {
    return Platform.localeName.replaceAll('_', '-');
  } catch (_) {
    return 'en-US';
  }
}

// TODO: check if we can get a better device model on desktops and our formatting is sane
String _deviceModel() {
  try {
    final raw = Platform.operatingSystemVersion;
    final firstLine = raw.split('\n').first;
    final beforeParen = firstLine.split('(').first.trim();
    if (beforeParen.isNotEmpty) {
      return beforeParen.length > 60 ? beforeParen.substring(0, 60) : beforeParen;
    }
  } catch (_) {}
  return 'unknown';
}
