import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdk_dart/sdk_dart.dart';
import 'package:http/http.dart' as http;
import 'package:sdk_dart/src/networking.dart';

class TestLogger implements SdkLogger {
  final List<String> logs = [];
  @override
  bool isEnabled(LogLevel level) => true;
  @override
  void log(LogLevel level, String message, {Object? error, StackTrace? stack}) {
    logs.add('[${level.name}] $message');
  }
}

class FakeResponseSuccess extends http.Response {
  FakeResponseSuccess({String body = '{"result":"Success"}', int status = 200})
    : super(body, status);
}

class FakeResponseFail extends http.Response {
  FakeResponseFail({String body = '{"result":"Error"}', int status = 500}) : super(body, status);
}

class FakeNetworkClient extends NetworkClient {
  final List<Map<String, dynamic>> sent = [];
  final bool succeed;
  FakeNetworkClient(String baseUrl, {this.succeed = true}) : super(baseUrl);
  @override
  Future<http.Response> makeRequest(Map<String, dynamic> data, String endPoint) async {
    sent.add({...data});
    if (succeed) {
      return FakeResponseSuccess();
    } else {
      return FakeResponseFail();
    }
  }
}

Future<SdkInstance> _createInstance({
  int eventQueueSize = 5,
  int requestQueueSize = 20,
  bool requiresConsent = false,
}) async {
  final logger = TestLogger();
  final cfg = SdkConfig(
    appKey: 'app-key',
    serverUrl: 'https://example.com',
    eventQueueSize: eventQueueSize,
    requestQueueSize: requestQueueSize,
    internalTimerInterval: 9999, /// TODO: mb no heartbeat for tests?
    enableSDKLogs: true,
    logger: logger,
    requiresConsent: requiresConsent,
    giveAllConsents: true,
    storageMode: StorageMode.memory,
  );
  final inst = await Sdk.init(cfg, instanceKey: 'test-${DateTime.now().microsecondsSinceEpoch}');
  addTearDown(() async {
    await Sdk.disposeAll();
  });
  return inst;
}

void main() {
  group('Event Tests', () {
    test('1. recording events adds them to the event queue', () async {
      final sdk = await _createInstance();
      expect(sdk.debugEventQueueLength, 0);
      sdk.events.record(key: 'login');
      sdk.events.record(key: 'purchase', count: 2);
      expect(sdk.debugEventQueueLength, 2);
      final names = sdk.debugEventQueueSnapshot.map((e) => e['key']).toList();
      expect(names, ['login', 'purchase']);
    });

    test('2. not providing event name (empty key) does not record event', () async {
      final sdk = await _createInstance();
      expect(sdk.debugEventQueueLength, 0);
      sdk.events.record(key: 'valid');
      expect(sdk.debugEventQueueLength, 1);
      sdk.events.record(key: ''); // should be ignored
      expect(sdk.debugEventQueueLength, 1, reason: 'Empty key must not be added');
    });

    test('3. bundling moves events to request queue', () async {
      final sdk = await _createInstance(eventQueueSize: 10);
      sdk.events.record(key: 'e1');
      sdk.events.record(key: 'e2');
      expect(sdk.debugEventQueueLength, 2);
      await sdk.processEventsAndRequests();
      // After processing, events should be flushed => event queue empty, request queue has one events request
      expect(sdk.debugEventQueueLength, 0);
      expect(sdk.debugRequestQueueLength, 1);
      final req = sdk.debugRequestQueueSnapshot.first;
      expect(req.containsKey('events'), isTrue);
      final decoded = jsonDecode(req['events'] as String) as List<dynamic>;
      expect(decoded.length, 2);
      final keys = decoded.map((e) => e['key']).toList();
      expect(keys, ['e1', 'e2']);
    });

    test('4. changing event queue size triggers early bundling when full', () async {
      final sdk = await _createInstance(eventQueueSize: 2);
      // Fill to capacity
      sdk.events.record(key: 'a');
      sdk.events.record(key: 'b');
      expect(sdk.debugEventQueueLength, 2);
      // should cause auto-bundle (queue cleared -> moved to request)
      sdk.events.record(key: 'c');
      // After adding third: event queue should have 1 (the latest), request queue should have 1 (bundle of first two)
      expect(
        sdk.debugEventQueueLength,
        1,
        reason: 'Queue should contain only the last event after bundling',
      );
      expect(
        sdk.debugRequestQueueLength,
        1,
        reason: 'Request queue should have received bundled events',
      );
      final bundledReq = sdk.debugRequestQueueSnapshot.first;
      final decoded = jsonDecode(bundledReq['events'] as String) as List<dynamic>;
      final keys = decoded.map((e) => e['key']).toList();
      expect(keys, ['a', 'b']);
      await sdk.processEventsAndRequests();
      expect(sdk.debugEventQueueLength, 0);
      expect(
        sdk.debugRequestQueueLength,
        2,
        reason: 'Second request added after flushing remaining event',
      );
    });

    test('5. pen & cvn works across sequential events and views', () async {
      final sdk = await _createInstance(requiresConsent: true, eventQueueSize: 20);
      sdk.views.startAutoStoppedView('Home');
      sdk.events.record(key: 'first');
      sdk.events.record(key: 'second');
      sdk.views.startAutoStoppedView('Details');
      sdk.events.record(key: 'third');
      final events = sdk.debugEventQueueSnapshot;
      final customEvents = events.where((e) => e['key'] != '[CLY]_view').toList();
      expect(customEvents.length, 3);
      // pen for first custom event should be empty string since no previous event
      expect(customEvents[0]['segmentation']['pen'], '');
      expect(customEvents[0]['segmentation']['cvn'], 'Home');
      // second custom event pen should be 'first'
      expect(customEvents[1]['segmentation']['pen'], 'first');
      expect(customEvents[1]['segmentation']['cvn'], 'Home');
      // third custom event pen should be the last view event key set 'second'
      expect(customEvents[2]['segmentation']['pen'], 'second');
      expect(customEvents[2]['segmentation']['cvn'], 'Details');
    });

    test('6. network failure triggers backoff (suspends further sends)', () async {
      final sdk = await _createInstance();
      final failing = FakeNetworkClient('https://example.com', succeed: false);
      sdk.debugOverrideNetworkClient = failing; // override
      sdk.events.record(key: 'a');
      await sdk.processEventsAndRequests();
      // Events flushed -> one request attempted (failed) remains in queue due to failure
      expect(sdk.debugRequestQueueLength, 1, reason: 'Failed request should remain in queue');
      // Add another event and process; since suspended, second send attempt should not remove / modify queue length except bundling new event
      sdk.events.record(key: 'b');
      await sdk.processEventsAndRequests();
      // Second event causes bundling -> new request appended
      expect(
        sdk.debugRequestQueueLength,
        2,
        reason: 'Second bundled request should be queued while suspended',
      );
    });

    test('7. request queue overflow drops oldest', () async {
      final sdk = await _createInstance(requestQueueSize: 3, eventQueueSize: 2);
      // Each pair of events + process => 1 request
      for (var i = 0; i < 5; i++) {
        sdk.events.record(key: 'e${i}a');
        sdk.events.record(key: 'e${i}b');
        await sdk.processEventsAndRequests();
      }
      // We created 5 requests but capacity is 3, so only last 3 remain
      expect(sdk.debugRequestQueueLength, 3);
      final remaining = sdk.debugRequestQueueSnapshot;
      List<String> firstEventKeys = [];
      for (final r in remaining) {
        if (r.containsKey('events')) {
          final arr = jsonDecode(r['events'] as String) as List<dynamic>;
          firstEventKeys.add(arr.first['key']);
        }
      }
      // Should correspond to batches 2,3,4 (0 & 1 dropped)
      expect(firstEventKeys.first, contains('e2'));
      expect(firstEventKeys.last, contains('e4'));
    });
  });
}
