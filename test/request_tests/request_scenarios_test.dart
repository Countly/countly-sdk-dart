// In each request scenario the SDK sends the requests api/requests/<scenario>.json records, with the values that change
// from run to run masked. The scenarios make the calls the other Countly SDKs make in their own request tests, as far
// as this SDK has them: it has no sessions and no crash reporting, so the session calls and the crash scenario are left
// out. A deliberate change: run COUNTLY_UPDATE_REQUESTS=1 flutter test test/request_tests, which writes the records,
// check the difference and add a line to CHANGELOG.md.
import 'dart:convert';
import 'dart:io';

import 'package:countly_sdk_dart_core/countly_sdk_dart_core.dart';
import 'package:countly_sdk_dart_core/src/lifecycle/lifecycle_stub.dart';
import 'package:countly_sdk_dart_core/src/networking.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

const mask = '<masked>';
const maskedParams = [
  'timestamp',
  'hour',
  'dow',
  'tz',
  'sdk_version',
  'av',
  'rr',
  'checksum',
  'checksum256',
  'session_duration'
];
const jsonParams = ['events', 'metrics', 'user_details', 'crash', 'consent', 'hc'];
const maskedEventFields = ['timestamp', 'hour', 'dow', 'id', 'pvid', 'cvid', 'peid'];
const maxInt = 2147483647;

/// Network client of the scenarios: keeps every request as the server would get it, in the order the SDK sends them,
/// and answers each with success.
class RecordingClient extends NetworkClient {
  final List<Map<String, dynamic>> sent = [];

  RecordingClient(super.baseUrl);

  @override
  Future<http.Response> makeRequest(Map<String, dynamic> data, String endPoint) async {
    sent.add({'path': endPoint, 'params': jsonDecode(jsonEncode(data)) as Map<String, dynamic>});
    return http.Response(data['method'] == 'sc' ? '{"c":{}}' : '{"result":"Success"}', 200);
  }
}

/// A copy of a JSON value with the keys of every object sorted, so that the order the SDK writes them in does not count.
dynamic sorted(dynamic value) {
  if (value is List) {
    return value.map(sorted).toList();
  }
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return {for (final key in keys) key: sorted(value[key])};
  }
  return value;
}

/// A copy of an object with the values of the given keys masked.
Map<String, dynamic> masked(Map<String, dynamic> value, Iterable<String> keys) {
  return {for (final entry in value.entries) entry.key: keys.contains(entry.key) ? mask : entry.value};
}

/// The value of a JSON parameter with the values that change from run to run masked.
dynamic maskedJson(String name, dynamic value) {
  if ((name == 'metrics' || name == 'hc') && value is Map<String, dynamic>) {
    return masked(value, value.keys);
  }
  if (name == 'events' && value is List) {
    return value.map((event) {
      if (event is! Map<String, dynamic>) {
        return event;
      }
      return masked(event, event['key'] == '[CLY]_view' ? [...maskedEventFields, 'dur'] : maskedEventFields);
    }).toList();
  }
  return value;
}

/// A request as the scenario files record it: the path and the parameters, with the values that change from run to run
/// masked, the JSON parameters parsed and the keys of every object sorted.
Map<String, dynamic> recordedRequest(Map<String, dynamic> request) {
  final params = <String, dynamic>{};
  (request['params'] as Map<String, dynamic>).forEach((name, value) {
    if (maskedParams.contains(name)) {
      params[name] = mask;
    } else if (jsonParams.contains(name)) {
      params[name] = maskedJson(name, value is String ? jsonDecode(value) : value);
    } else {
      params[name] = value;
    }
  });
  return {'path': request['path'], 'params': sorted(params)};
}

/// Runs a scenario on a new SDK instance and compares the requests it sent with the record of the scenario, or writes
/// the record when COUNTLY_UPDATE_REQUESTS is set.
Future<void> checkRequests(String name, Future<void> Function(CountlyInstance sdk) scenario,
    {bool giveConsent = true}) async {
  final client = RecordingClient('https://parity.example');
  final sdk = await Countly.init(
    CountlyConfig(
      appKey: 'parity-app-key',
      serverUrl: 'https://parity.example',
      deviceId: 'parity-device-001',
      storageMode: StorageMode.memory,
      giveConsent: giveConsent,
      networkClientOverride: client,
    ),
    instanceKey: 'request-scenarios',
  );
  await scenario(sdk);
  await sdk.processEventsAndRequests();
  await Countly.disposeAll();
  clearLifecycleListeners();

  final current = '${const JsonEncoder.withIndent('  ').convert(client.sent.map(recordedRequest).toList())}\n';
  final file = File('api/requests/$name.json');
  if (Platform.environment.containsKey('COUNTLY_UPDATE_REQUESTS')) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(current);
    return;
  }
  final committed =
      file.existsSync() ? file.readAsStringSync().replaceAll('\r\n', '\n') : '(no api/requests/$name.json)\n';
  expect(current, committed,
      reason: 'the requests of the $name scenario differ from api/requests/$name.json. If that is deliberate, run '
          'COUNTLY_UPDATE_REQUESTS=1 flutter test test/request_tests, check the difference and add a line to CHANGELOG.md.');
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  test('parity: an event with one segmentation value of every type, and the user details', () async {
    await checkRequests('parity', (sdk) async {
      await sdk.events.record(key: 'purchase', count: 2, sum: 9.99, dur: 5, segmentation: {
        'nar': 'uto',
        'sasuke': maxInt,
        'sakura': false,
        'itachi': double.maxFinite,
        'kakaski': double.minPositive,
        'hashirama': -maxInt,
        'tobi': {'obito': 'uchiha', 'zetsu': 'white'},
        'stringList': ['value1', 'value2', 'value3'],
        'intList': [1, 2, 3],
        'doubleList': [1.1, 2.2, 3.3],
        'boolList': [true, false, true],
        'mixedList': ['value1', 2, 3.3, true],
        'mapList': [
          {'key1': 'value1', 'key2': 2},
          {'key1': 'value2', 'key2': 3},
          {'key1': 'value3', 'key2': 4},
        ],
      });
      await sdk.users.setProperties({
        'name': 'John Doe',
        'username': 'john_d',
        'email': 'john@example.com',
        'organization': 'Countly',
        'phone': '1234567890',
        'picture': 'https://example.com/picture.jpg',
        'gender': 'M',
        'byear': 1980,
        'tier': 'gold',
        'age': 30,
      });
    });
  });

  test('views: two views, the first with segmentation', () async {
    await checkRequests('views', (sdk) async {
      await sdk.views.startAutoStoppedView('Home', segmentation: {'source': 'scenario'});
      await sdk.views.endActiveView();
      await sdk.views.startAutoStoppedView('Settings');
      await sdk.views.endActiveView();
    });
  });

  test('consent: given, then taken back', () async {
    await checkRequests('consent', giveConsent: false, (sdk) async {
      await sdk.consents.giveConsent();
      await sdk.events.record(key: 'consented');
      await sdk.processEventsAndRequests();
      await sdk.consents.revokeConsent();
      await sdk.events.record(key: 'not_consented');
    });
  });

  test('device-id: a change with merge, then one without', () async {
    await checkRequests('device-id', (sdk) async {
      await sdk.id.changeWithMerge('parity-device-002');
      await sdk.events.record(key: 'after_merge');
      await sdk.processEventsAndRequests();
      await sdk.id.changeWithoutMerge('parity-device-003');
      await sdk.events.record(key: 'after_new_id');
    });
  });
}
