import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:countly_sdk_dart/countly.dart';
import 'package:http/http.dart' as http;
import 'package:countly_sdk_dart/src/networking.dart';

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
  FakeResponseSuccess({String body = '{"result":"Success"}', int status = 200}) : super(body, status);
}

class FakeNetworkClient extends NetworkClient {
  final List<Map<String, dynamic>> sent = [];
  FakeNetworkClient(String baseUrl) : super(baseUrl);
  @override
  Future<http.Response> makeRequest(Map<String, dynamic> data, String endPoint) async {
    sent.add({...data});
    return FakeResponseSuccess();
  }
}

Future<CountlyInstance> _createInstanceWithUnknownConsent({
  required FakeNetworkClient networkClient,
}) async {
  final logger = TestLogger();
  final cfg = CountlyConfig(
    appKey: 'app-key',
    serverUrl: 'https://example.com',
    enableSDKLogs: true,
    logger: logger,
    giveConsent: false,
    startWithUnknownConsent: true,
    storageMode: StorageMode.memory,
  );
  final inst = await Countly.init(cfg, instanceKey: 'test-unknown-${DateTime.now().microsecondsSinceEpoch}');
  inst.debugOverrideNetworkClient = networkClient;
  addTearDown(() async {
    await Countly.disposeAll();
  });
  return inst;
}

Future<CountlyInstance> _createNormalInstance({
  required FakeNetworkClient networkClient,
}) async {
  final logger = TestLogger();
  final cfg = CountlyConfig(
    appKey: 'app-key',
    serverUrl: 'https://example.com',
    enableSDKLogs: true,
    logger: logger,
    giveConsent: true,
    storageMode: StorageMode.memory,
  );
  final inst = await Countly.init(cfg, instanceKey: 'test-normal-${DateTime.now().microsecondsSinceEpoch}');
  inst.debugOverrideNetworkClient = networkClient;
  addTearDown(() async {
    await Countly.disposeAll();
  });
  return inst;
}

void main() {
  group('Unknown Consent Mode Tests', () {
    test('1. SDK in unknown consent mode does not send requests to server', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstanceWithUnknownConsent(networkClient: network);

      // Record some events
      sdk.events.record(key: 'test_event_1');
      sdk.events.record(key: 'test_event_2');

      // Start a view
      sdk.views.startAutoStoppedView('TestView');

      // Process events and requests
      await sdk.processEventsAndRequests();

      // Verify no requests were sent to the server
      expect(network.sent.length, 0, reason: 'No requests should be sent in unknown consent mode');

      // But events should still be tracked in memory
      // Events get bundled into request queue, so event queue may be empty
      // Check that data exists in either queue
      final totalQueued = sdk.debugEventQueueLength + sdk.debugRequestQueueLength;
      expect(totalQueued, 4, reason: 'Events should be tracked in memory');
    });

    test('2. Events are tracked in memory during unknown consent mode', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstanceWithUnknownConsent(networkClient: network);
      sdk.debugOverrideBehaviorSettings(eventQueueSize: 100); // Prevent auto-bundling

      // Record events
      sdk.events.record(key: 'event_a');
      sdk.events.record(key: 'event_b');
      sdk.events.record(key: 'event_c');

      // Verify events are in the event queue
      expect(sdk.debugEventQueueLength, 3);
      final eventKeys = sdk.debugEventQueueSnapshot.map((e) => e['key']).toList();
      expect(eventKeys, contains('event_a'));
      expect(eventKeys, contains('event_b'));
      expect(eventKeys, contains('event_c'));

      // No requests should be sent
      expect(network.sent.length, 0);
    });

    test('3. Views are tracked in memory during unknown consent mode', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstanceWithUnknownConsent(networkClient: network);
      sdk.debugOverrideBehaviorSettings(eventQueueSize: 100);

      // Start and switch views
      sdk.views.startAutoStoppedView('HomePage');
      await Future.delayed(Duration(milliseconds: 50)); // Small delay for view duration
      sdk.views.startAutoStoppedView('DetailsPage');

      // Check that view events are tracked
      final viewEvents = sdk.debugEventQueueSnapshot.where((e) => e['key'] == '[CLY]_view').toList();
      expect(viewEvents.length, 1, reason: 'View events should be tracked in memory');

      // No requests sent to server
      expect(network.sent.length, 0);
    });

    test('4. Giving consent exits unknown consent mode and sends queued data', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstanceWithUnknownConsent(networkClient: network);
      sdk.debugOverrideBehaviorSettings(eventQueueSize: 100);

      // Record events while in unknown consent mode
      sdk.events.record(key: 'pre_consent_event_1');
      sdk.events.record(key: 'pre_consent_event_2');

      // Verify no requests sent yet
      expect(network.sent.length, 0);

      // Give consent - this should exit unknown consent mode
      sdk.consents.giveConsent();

      // Allow async operations to complete
      await Future.delayed(Duration(milliseconds: 100));

      // Now requests should be sent
      expect(network.sent.length, greaterThan(0), reason: 'Requests should be sent after consent is given');

      // Verify the events were included in the sent requests
      final sentEventsRequest = network.sent.where((r) => r.containsKey('events')).toList();
      expect(sentEventsRequest.length, greaterThan(0), reason: 'Event requests should be sent');

      // Parse and verify event keys
      final allSentEventKeys = <String>[];
      for (final req in sentEventsRequest) {
        final eventsJson = req['events'] as String;
        final events = jsonDecode(eventsJson) as List<dynamic>;
        for (final e in events) {
          allSentEventKeys.add(e['key'] as String);
        }
      }
      expect(allSentEventKeys, contains('pre_consent_event_1'));
      expect(allSentEventKeys, contains('pre_consent_event_2'));
    });

    test('5. Request queue is populated but not sent during unknown consent mode', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstanceWithUnknownConsent(networkClient: network);
      sdk.debugOverrideBehaviorSettings(eventQueueSize: 2); // Force early bundling

      // Record enough events to trigger bundling
      sdk.events.record(key: 'e1');
      sdk.events.record(key: 'e2');
      sdk.events.record(key: 'e3'); // This should trigger bundling

      // Request queue should have requests
      expect(sdk.debugRequestQueueLength, greaterThan(0), reason: 'Events should be bundled into request queue');

      // But nothing should be sent to server
      expect(network.sent.length, 0, reason: 'Requests should not be sent in unknown consent mode');

      // Now process - still nothing should be sent
      await sdk.processEventsAndRequests();
      expect(network.sent.length, 0, reason: 'processEventsAndRequests should not send in unknown consent mode');
    });

    test('6. Compare: normal mode sends requests immediately', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createNormalInstance(networkClient: network);

      // Record events
      sdk.events.record(key: 'normal_event');

      // Process
      await sdk.processEventsAndRequests();

      // Requests should be sent in normal mode
      expect(network.sent.length, greaterThan(0), reason: 'Normal mode should send requests');
    });

    test('7. After consent, new events are sent normally', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstanceWithUnknownConsent(networkClient: network);

      // Give consent first
      sdk.consents.giveConsent();
      await Future.delayed(Duration(milliseconds: 50));

      // Clear any sent requests from consent transition
      network.sent.clear();

      // Record new events after consent
      sdk.events.record(key: 'post_consent_event');
      await sdk.processEventsAndRequests();

      // New events should be sent
      expect(network.sent.length, greaterThan(0), reason: 'Events after consent should be sent');

      final sentEventsRequest = network.sent.where((r) => r.containsKey('events')).toList();
      expect(sentEventsRequest.length, greaterThan(0));

      final eventsJson = sentEventsRequest.first['events'] as String;
      final events = jsonDecode(eventsJson) as List<dynamic>;
      final keys = events.map((e) => e['key']).toList();
      expect(keys, contains('post_consent_event'));
    });

    test('8. Multiple event types tracked correctly in unknown consent mode', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstanceWithUnknownConsent(networkClient: network);
      sdk.debugOverrideBehaviorSettings(eventQueueSize: 100);

      // Record various types of events
      sdk.events.record(key: 'custom_event', count: 5, sum: 10.5);
      sdk.events.record(key: 'event_with_segmentation', segmentation: {'category': 'test', 'value': 42});
      sdk.views.startAutoStoppedView('TestPage');

      // All should be tracked in memory
      final events = sdk.debugEventQueueSnapshot;
      expect(events.length, greaterThanOrEqualTo(2)); // At least custom events

      // Verify event properties are preserved
      final customEvent = events.firstWhere((e) => e['key'] == 'custom_event');
      expect(customEvent['count'], 5);
      expect(customEvent['sum'], 10.5);

      final segEvent = events.firstWhere((e) => e['key'] == 'event_with_segmentation');
      expect(segEvent['segmentation']['category'], 'test');
      expect(segEvent['segmentation']['value'], 42);

      // Still no requests sent
      expect(network.sent.length, 0);
    });
  });
}
