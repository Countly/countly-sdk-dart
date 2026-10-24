import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

/// The time fields every request carries from the moment it is created.
final requestTimeFields = {
  'timestamp': isA<int>(),
  'hour': isA<int>(),
  'dow': isA<int>(),
  'tz': isA<int>(),
};

final sdkBehaviorRequest = {
  'app_key': 'app-key',
  'device_id': 'test-device',
  'sdk_version': '26.1.0',
  'sdk_name': 'countly-sdk-dart-core',
  'av': '1.0.0',
  ...requestTimeFields,
  'method': 'sc',
};

final healthCheckRequest = {
  'app_key': 'app-key',
  'device_id': 'test-device',
  'sdk_version': '26.1.0',
  'sdk_name': 'countly-sdk-dart-core',
  'av': '1.0.0',
  'hc': {'el': 0, 'wl': 0, 'sc': '', 'em': ''},
  'metrics': {'_app_version': '1.0.0'},
  ...requestTimeFields,
};

final falseConsentRequest = {
  'app_key': 'app-key',
  'device_id': 'test-device',
  'sdk_version': '26.1.0',
  'sdk_name': 'countly-sdk-dart-core',
  'av': '1.0.0',
  ...requestTimeFields,
  'consent': {
    'events': false,
    'users': false,
    'feedback': false,
    'metrics': false,
    'views': false,
  },
};
final trueConsentRequest = {
  'app_key': 'app-key',
  'device_id': 'test-device',
  'sdk_version': '26.1.0',
  'sdk_name': 'countly-sdk-dart-core',
  'av': '1.0.0',
  ...requestTimeFields,
  'consent': {
    'events': true,
    'users': true,
    'feedback': true,
    'metrics': true,
    'views': true,
  },
};
final locationRequest = {
  'app_key': 'app-key',
  'device_id': 'test-device',
  'sdk_version': '26.1.0',
  'sdk_name': 'countly-sdk-dart-core',
  'av': '1.0.0',
  ...requestTimeFields,
  'location': '',
};

final metricsRequest = {
  'app_key': 'app-key',
  'device_id': 'test-device',
  'sdk_version': '26.1.0',
  'sdk_name': 'countly-sdk-dart-core',
  'av': '1.0.0',
  ...requestTimeFields,
  'metrics': {
    '_os': isA<String>(),
    '_device': isA<String>(),
    '_device_type': isA<String>(),
    '_resolution': isA<String>(),
    '_density': isA<num>(),
    '_orientation': isA<String>(),
    '_locale': isA<String>(),
    '_app_version': '1.0.0'
  },
};

/// Deconstructs an 'events' request map into a list of per-event maps.
///
/// Example input:
/// {
///  'app_key': 'app-key',
///  'device_id': 'test-device',
///  'sdk_version': '26.1.0',
///  'sdk_name': 'countly-sdk-dart-core',
///  'av': '1.0.0',
///  'events': [ { ... }, { ... } ]
/// }
///
/// Returns a list where each element is the merged map of common request
/// fields and the individual event object.
List<Map<String, dynamic>> deconstructRequestByKey(Map<String, dynamic> request, String key) {
  final List<Map<String, dynamic>> result = [];

  if (!request.containsKey(key) || request[key] == null) return result;

  final commonKeys = ['app_key', 'device_id', 'sdk_version', 'sdk_name', 'av'];
  final Map<String, dynamic> common = {};
  for (final k in commonKeys) {
    if (request.containsKey(k)) {
      common[k] = request[k];
    }
  }

  final dynamic rawValue = request[key];
  List<dynamic> items;

  if (rawValue is String) {
    try {
      final parsed = jsonDecode(rawValue);
      if (parsed is List<dynamic>) {
        items = parsed;
      } else if (parsed is Map) {
        items = [parsed];
      } else {
        return result;
      }
    } catch (e) {
      return result;
    }
  } else if (rawValue is List<dynamic>) {
    items = rawValue;
  } else if (rawValue is Map) {
    items = [rawValue];
  } else {
    return result;
  }

  for (final item in items) {
    if (item is Map) {
      final ev = Map<String, dynamic>.from(item.cast<String, dynamic>());
      final merged = Map<String, dynamic>.from(common)..addAll(ev);
      result.add(merged);
    }
  }

  return result;
}

List<Map<String, dynamic>> deconstructEventsRequest(Map<String, dynamic> request) =>
    deconstructRequestByKey(request, 'events');
List<Map<String, dynamic>> deconstructUserPropertiesRequest(Map<String, dynamic> request) =>
    deconstructRequestByKey(request, 'user_details');
