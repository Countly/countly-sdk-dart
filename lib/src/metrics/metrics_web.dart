import '../constants.dart';

import 'package:web/web.dart' as web;

Map<String, dynamic> getCurrentMetrics() {
  final nav = web.window.navigator;
  final ua = nav.userAgent;
  final screen = web.window.screen;
  final width = screen.width;
  final height = screen.height;
  final pixelRatio = web.window.devicePixelRatio;
  final browser = _parseBrowser(ua);
  final osInfo = _parseOs(ua);
  final deviceType = _inferDeviceTypeFromUa(ua);
  return {
    '_os': osInfo.$1,
    '_os_version': osInfo.$2,
    '_device': 'browser',
    '_device_type': deviceType,
    '_resolution': '${width}x$height',
    if (height != 0 && width != 0) '_orientation': height >= width ? 'portrait' : 'landscape',
    '_density': pixelRatio,
    '_browser': browser.name,
    '_browser_version': browser.version,
    '_ua': ua,
    '_locale': _locale(),
    '_app_version': SdkInternal.sdkVersion,
  };
}


String _locale() {
  final l = web.window.navigator.language;
  if (l.isEmpty) return 'en-US';
  return l.replaceAll('_', '-');
}

class _BrowserInfo {
  final String name;
  final String version;
  _BrowserInfo(this.name, this.version);
}

_BrowserInfo _parseBrowser(String ua) {
  final patterns = <RegExp, String>{
    RegExp(r'OPR\/([0-9.]+)'): 'Opera',
    RegExp(r'Edg\/([0-9.]+)'): 'Edge',
    RegExp(r'Chrome\/([0-9.]+)'): 'Chrome',
    RegExp(r'Firefox\/([0-9.]+)'): 'Firefox',
    RegExp(r'Vivaldi\/([0-9.]+)'): 'Vivaldi',
    RegExp(r'Safari\/([0-9.]+)'): 'Safari'
  };
  for (final e in patterns.entries) {
    final m = e.key.firstMatch(ua);
    if (m != null) return _BrowserInfo(e.value, m.group(1)!);
  }
  return _BrowserInfo('Unknown', '0');
}

/// Returns (osName, osVersion)
(String, String) _parseOs(String ua) {
  final android = RegExp(r'Android ([0-9.]+)');
  final ios = RegExp(r'iPhone OS ([0-9_]+)');
  final ipad = RegExp(r'iPad; CPU OS ([0-9_]+)');
  final mac = RegExp(r'Mac OS X ([0-9_]+)');
  final win = RegExp(r'Windows NT ([0-9.]+)');
  final linux = RegExp(r'X11; Linux');
  if (android.hasMatch(ua)) {
    final v = android.firstMatch(ua)!.group(1)!;
    return ('Android', v);
  }
  if (ios.hasMatch(ua)) {
    final v = ios.firstMatch(ua)!.group(1)!.replaceAll('_', '.');
    return ('iOS', v);
  }
  if (ipad.hasMatch(ua)) {
    final v = ipad.firstMatch(ua)!.group(1)!.replaceAll('_', '.');
    return ('iPadOS', v);
  }
  if (mac.hasMatch(ua)) {
    final v = mac.firstMatch(ua)!.group(1)!.replaceAll('_', '.');
    return ('macOS', v);
  }
  if (win.hasMatch(ua)) {
    final v = win.firstMatch(ua)!.group(1)!;
    return ('Windows', v);
  }
  if (linux.hasMatch(ua)) {
    return ('Linux', 'n/a');
  }
  return ('Web', 'n/a');
}

String _inferDeviceTypeFromUa(String ua) {
  final lower = ua.toLowerCase();
  if (lower.contains('mobile') || lower.contains('android') || lower.contains('iphone')) return 'mobile';
  if (lower.contains('ipad') || lower.contains('tablet')) return 'tablet';
  return 'desktop';
}
