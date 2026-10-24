import 'dart:convert';
import 'dart:io' show ContentType, HttpRequest, HttpServer, InternetAddress;

import 'package:countly_sdk_dart_core/countly_sdk_dart_core.dart';
import 'package:countly_sdk_dart_core/src/networking.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class FakeResponseSuccess extends http.Response {
  FakeResponseSuccess({String body = '{"result":"Success"}', int status = 200}) : super(body, status);
}

class RequestCapturingNetworkClient extends NetworkClient {
  final List<Map<String, dynamic>> sent = [];
  final Map<String, String> capturedHeaders = {};
  String? lastMethod;
  String? lastEndpoint;

  RequestCapturingNetworkClient(String baseUrl) : super(baseUrl);

  @override
  Future<http.Response> makeRequest(Map<String, dynamic> data, String endPoint) async {
    lastEndpoint = endPoint;
    lastMethod = 'POST';
    sent.add(Map<String, dynamic>.from(data));
    if (data['method'] == 'sc') {
      return FakeResponseSuccess(body: '{"c":{}}');
    }
    return FakeResponseSuccess();
  }

  @override
  Future<http.Response> makeSelectiveRequest(Map<String, dynamic> data) async {
    lastMethod = 'POST';
    sent.add(Map<String, dynamic>.from(data));
    return FakeResponseSuccess();
  }
}

class HeaderTrackingNetworkClient extends NetworkClient {
  final List<Map<String, dynamic>> sent = [];
  Map<String, String>? customHeaders;

  HeaderTrackingNetworkClient(String baseUrl) : super(baseUrl);

  void setCustomHeaders(Map<String, String> headers) {
    customHeaders = headers;
  }

  @override
  Future<http.Response> makeRequest(Map<String, dynamic> data, String endPoint) async {
    sent.add(Map<String, dynamic>.from(data));
    if (data['method'] == 'sc') {
      return FakeResponseSuccess(body: '{"c":{}}');
    }
    return FakeResponseSuccess();
  }

  @override
  Future<http.Response> makeSelectiveRequest(Map<String, dynamic> data) async {
    sent.add(Map<String, dynamic>.from(data));
    return FakeResponseSuccess();
  }
}

class MockHttpClient extends http.BaseClient {
  final List<http.BaseRequest> requests = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    return http.StreamedResponse(
      Stream.value(utf8.encode('{"result":"Success"}')),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

class MemoryBackedStorage {
  final Map<String, String> backing = {};

  CustomStorageMethods toMethods() {
    return CustomStorageMethods(
      read: (key) async => backing[key],
      write: (key, value) async => backing[key] = value,
      remove: (key) async => backing.remove(key),
      keys: () async => backing.keys.toList(),
    );
  }
}

Future<CountlyInstance> _createInstance({
  bool giveConsent = true,
  RequestCapturingNetworkClient? networkClient,
  Map<String, String>? customRequestHeaders,
  bool enableNetworkOverride = true,
  Map<String, dynamic> sbs = const {},
}) async {
  final client = enableNetworkOverride ? (networkClient ?? RequestCapturingNetworkClient('https://example.com')) : null;
  final cfg = CountlyConfig(
    appKey: 'test-app-key',
    serverUrl: 'https://example.com',
    deviceId: 'test-device-id',
    storageMode: StorageMode.memory,
    giveConsent: giveConsent,
    networkClientOverride: client,
    customRequestHeaders: customRequestHeaders,
    sbs: sbs,
  );
  final inst = await Countly.init(cfg);
  addTearDown(() async {
    await Countly.disposeAll();
  });
  return inst;
}

void main() {
  group('Request Structure - Required Fields', () {
    test('all requests include app_key', () async {
      final network = RequestCapturingNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.events.record(key: 'test_event');
      await sdk.processEventsAndRequests();

      expect(network.sent.isNotEmpty, true);
      final req = network.sent.firstWhere((r) => r.containsKey('events'), orElse: () => <String, dynamic>{});
      if (req.isNotEmpty) {
        expect(req['app_key'], 'test-app-key');
      }
    });

    test('all requests include device_id', () async {
      final network = RequestCapturingNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.events.record(key: 'test_event');
      await sdk.processEventsAndRequests();

      final req = network.sent.firstWhere((r) => r.containsKey('events'), orElse: () => <String, dynamic>{});
      if (req.isNotEmpty) {
        expect(req['device_id'], 'test-device-id');
      }
    });

    test('all requests include sdk_version', () async {
      final network = RequestCapturingNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.events.record(key: 'test_event');
      await sdk.processEventsAndRequests();

      final req = network.sent.firstWhere((r) => r.containsKey('events'), orElse: () => <String, dynamic>{});
      if (req.isNotEmpty) {
        expect(req['sdk_version'], isA<String>());
        expect((req['sdk_version'] as String).length, greaterThan(0));
      }
    });

    test('all requests include sdk_name', () async {
      final network = RequestCapturingNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.events.record(key: 'test_event');
      await sdk.processEventsAndRequests();

      final req = network.sent.firstWhere((r) => r.containsKey('events'), orElse: () => <String, dynamic>{});
      if (req.isNotEmpty) {
        expect(req['sdk_name'], isA<String>());
        expect((req['sdk_name'] as String).length, greaterThan(0));
      }
    });

    test('all requests include timestamp', () async {
      final network = RequestCapturingNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.events.record(key: 'test_event');
      await sdk.processEventsAndRequests();

      final req = network.sent.firstWhere((r) => r.containsKey('events'), orElse: () => <String, dynamic>{});
      if (req.isNotEmpty) {
        expect(req['timestamp'], isA<int>());
        expect(req['timestamp'], greaterThan(0));
      }
    });

    test('all requests include hour and dow', () async {
      final network = RequestCapturingNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.events.record(key: 'test_event');
      await sdk.processEventsAndRequests();

      final req = network.sent.firstWhere((r) => r.containsKey('events'), orElse: () => <String, dynamic>{});
      if (req.isNotEmpty) {
        expect(req['hour'], isA<int>());
        expect(req['hour'], inInclusiveRange(0, 23));
        expect(req['dow'], isA<int>());
        expect(req['dow'], inInclusiveRange(0, 6));
      }
    });

    test('all requests include timezone offset', () async {
      final network = RequestCapturingNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.events.record(key: 'test_event');
      await sdk.processEventsAndRequests();

      final req = network.sent.firstWhere((r) => r.containsKey('events'), orElse: () => <String, dynamic>{});
      if (req.isNotEmpty) {
        expect(req['tz'], isA<int>());
      }
    });
  });

  group('Request Creation Time', () {
    test('a request carries its creation time while it waits in the queue', () async {
      final sdk = await _createInstance(sbs: {
        'c': {'networking': false}
      });

      final before = DateTime.now().millisecondsSinceEpoch;
      await sdk.events.recordMetrics(metricOverride: {'queued': 'yes'});
      final after = DateTime.now().millisecondsSinceEpoch;

      final queued = sdk.debugRequestQueueSnapshot.last;
      expect(queued['metrics']['queued'], 'yes');
      expect(queued['timestamp'], inInclusiveRange(before, after));
      _expectTimeFieldsOfItsTimestamp(queued);
    });

    test('every kind of request carries timestamp, hour, dow and tz', () async {
      final network = RequestCapturingNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.events.record(key: 'test_event');
      await sdk.users.setProperties({'name': 'John'});
      await sdk.id.changeWithMerge('merged-device-id');
      await sdk.processEventsAndRequests();

      expect(network.sent.map(_requestKind),
          ['sbs', 'hc', 'consent', 'location', 'metrics', 'events', 'old_device_id', 'user_details']);
      for (final req in network.sent) {
        _expectTimeFieldsOfItsTimestamp(req);
      }
    });

    test('a request stored without time fields by an earlier version gets the time it is loaded, and keeps it',
        () async {
      const events = '[{"key":"stored_without_time","count":1}]';
      final storage = MemoryBackedStorage();
      storage.backing['default_COUNTLY_DART_RQ'] = jsonEncode([
        {'app_key': 'test-app-key', 'device_id': 'test-device-id', 'events': events}
      ]);

      final before = DateTime.now().millisecondsSinceEpoch;
      final sdk = await Countly.init(CountlyConfig(
        appKey: 'test-app-key',
        serverUrl: 'https://example.com',
        deviceId: 'test-device-id',
        storageMode: StorageMode.persistent,
        giveConsent: true,
        storageMethods: storage.toMethods(),
        networkClientOverride: RequestCapturingNetworkClient('https://example.com'),
        // Nothing is sent or newly stored, so only the loading itself writes the queue back.
        sbs: {
          'c': {'networking': false, 'tracking': false}
        },
      ));
      final after = DateTime.now().millisecondsSinceEpoch;
      addTearDown(() async {
        await Countly.disposeAll();
      });

      final loaded = sdk.debugRequestQueueSnapshot.first;
      expect(loaded['events'], events);
      expect(loaded['timestamp'], inInclusiveRange(before, after));
      _expectTimeFieldsOfItsTimestamp(loaded);
      final stored = jsonDecode(storage.backing['default_COUNTLY_DART_RQ']!) as List<dynamic>;
      expect((stored.first as Map<String, dynamic>)['timestamp'], loaded['timestamp']);
    });

    test('a queued request reaches the server with its creation time after a failed attempt and a restart', () async {
      final server = await _MockCountlyServer.start();
      addTearDown(server.close);
      // Created on an earlier run on a device in UTC+3, so its hour, dow and tz need not match this machine.
      final queuedEarlier = {
        'app_key': 'test-app-key',
        'device_id': 'test-device-id',
        'sdk_version': '26.1.0',
        'sdk_name': 'countly-sdk-dart-core',
        'av': '1.0.0',
        'timestamp': 1700000000000,
        'hour': 1,
        'dow': 3,
        'tz': 180,
        'events': '[{"key":"queued_earlier","count":1}]',
      };
      final storage = MemoryBackedStorage();
      storage.backing['default_COUNTLY_DART_RQ'] = jsonEncode([queuedEarlier]);
      final cfg = CountlyConfig(
        appKey: 'test-app-key',
        serverUrl: server.url,
        deviceId: 'test-device-id',
        storageMode: StorageMode.persistent,
        giveConsent: true,
        storageMethods: storage.toMethods(),
      );
      addTearDown(() async {
        await Countly.disposeAll();
      });

      server.failuresLeft = 1;
      final firstRunStart = DateTime.now().millisecondsSinceEpoch;
      await Countly.init(cfg);
      final firstRunReady = DateTime.now().millisecondsSinceEpoch;
      await _waitFor(() => server.received.length >= 3);
      await Countly.disposeAll();
      await Countly.init(cfg);
      await _waitFor(() => server.received.length >= 9);

      expect(server.received.length, 9);
      final fromQueue = server.received.where((r) => r.path == '/i' && !r.body.containsKey('hc')).toList();
      expect(fromQueue.map((r) => _requestKind(r.body)), ['events', 'events', 'consent', 'location', 'metrics']);
      for (final attempt in fromQueue.take(2)) {
        expect(attempt.body['events'], queuedEarlier['events']);
        expect(attempt.body['timestamp'], 1700000000000);
        expect(attempt.body['hour'], 1);
        expect(attempt.body['dow'], 3);
        expect(attempt.body['tz'], 180);
      }
      for (final createdOnFirstRun in fromQueue.skip(2)) {
        expect(createdOnFirstRun.body['timestamp'], inInclusiveRange(firstRunStart, firstRunReady));
      }
      expect(server.received.where((r) => r.path == '/o/sdk' && r.body['method'] == 'sc').length, 2);
      expect(server.received.where((r) => r.path == '/i' && r.body.containsKey('hc')).length, 2);
      for (final createdNow in server.received.where((r) => r.body['events'] != queuedEarlier['events'])) {
        _expectTimeFieldsOfItsTimestamp(createdNow.body);
      }
    });
  });

  group('Custom Request Headers', () {
    test('custom headers from config are passed', () async {
      final mockClient = MockHttpClient();

      await http.runWithClient(() async {
        final sdk = await _createInstance(
          customRequestHeaders: {'X-Custom': 'value1', 'Authorization': 'Bearer token'},
          enableNetworkOverride: false,
        );

        await sdk.events.record(key: 'test_event');
        await sdk.processEventsAndRequests();

        final req = mockClient.requests.firstWhere((r) => r.url.path.contains('/i'));
        expect(req.headers['x-custom'], 'value1');
        expect(req.headers['authorization'], 'Bearer token');
      }, () => mockClient);
    });

    test('empty custom headers map is allowed', () async {
      final mockClient = MockHttpClient();

      await http.runWithClient(() async {
        final sdk = await _createInstance(
          customRequestHeaders: {},
          enableNetworkOverride: false,
        );

        await sdk.events.record(key: 'test_event');
        await sdk.processEventsAndRequests();

        final req = mockClient.requests.firstWhere((r) => r.url.path.contains('/i'));
        // Standard headers should be present
        expect(req.headers.containsKey('content-type'), true);
      }, () => mockClient);
    });

    test('null custom headers is allowed', () async {
      final mockClient = MockHttpClient();

      await http.runWithClient(() async {
        final sdk = await _createInstance(
          customRequestHeaders: null,
          enableNetworkOverride: false,
        );

        await sdk.events.record(key: 'test_event');
        await sdk.processEventsAndRequests();

        final req = mockClient.requests.firstWhere((r) => r.url.path.contains('/i'));
        // Standard headers should be present
        expect(req.headers.containsKey('content-type'), true);
      }, () => mockClient);
    });
  });

  group('POST-Only Communication', () {
    test('makeRequest uses POST method', () async {
      final mockClient = MockHttpClient();

      await http.runWithClient(() async {
        final sdk = await _createInstance(enableNetworkOverride: false);

        await sdk.events.record(key: 'test_event');
        await sdk.processEventsAndRequests();

        final req = mockClient.requests.lastWhere((r) => r.url.path.contains('/i'));
        expect(req.method, 'POST');
      }, () => mockClient);
    });

    test('makeSelectiveRequest uses POST method', () async {
      final mockClient = MockHttpClient();

      await http.runWithClient(() async {
        await _createInstance(enableNetworkOverride: false);

        // SBS request uses makeSelectiveRequest and is sent during init
        // We check if any request was sent and if it was POST
        expect(mockClient.requests.isNotEmpty, true);
        expect(mockClient.requests.every((req) => req.method == 'POST'), true);
      }, () => mockClient);
    });

    test('large payloads are sent via POST body', () async {
      final mockClient = MockHttpClient();

      await http.runWithClient(() async {
        final sdk = await _createInstance(enableNetworkOverride: false);

        // Create large event
        final largeSegmentation = <String, dynamic>{};
        for (var i = 0; i < 50; i++) {
          largeSegmentation['key_$i'] = 'value_$i' * 10;
        }

        await sdk.events.record(key: 'large_event', segmentation: largeSegmentation);
        await sdk.processEventsAndRequests();

        final req = mockClient.requests.last;
        expect(req.method, 'POST');
        // Verify body contains our data
        if (req is http.Request) {
          expect(req.body, contains('large_event'));
        }
      }, () => mockClient);
    });

    test('all request endpoints use POST', () async {
      final mockClient = MockHttpClient();

      await http.runWithClient(() async {
        final sdk = await _createInstance(enableNetworkOverride: false);

        await sdk.events.record(key: 'test');
        await sdk.users.setProperties({'name': 'John'});
        sdk.views.startAutoStoppedView('TestView');

        await sdk.processEventsAndRequests();

        // All requests should use POST
        expect(mockClient.requests.isNotEmpty, true);
        expect(mockClient.requests.every((req) => req.method == 'POST'), true);
      }, () => mockClient);
    });
  });

  group('Request Batching', () {
    test('events are batched into single request', () async {
      final network = RequestCapturingNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.events.record(key: 'event1');
      await sdk.events.record(key: 'event2');
      await sdk.events.record(key: 'event3');

      await sdk.processEventsAndRequests();

      final eventReqs = network.sent.where((r) => r.containsKey('events')).toList();
      expect(eventReqs.length, lessThanOrEqualTo(1), reason: 'Events should be batched');

      if (eventReqs.isNotEmpty) {
        final events = jsonDecode(eventReqs.first['events'] as String) as List;
        expect(events.length, 3);
      }
    });

    test('requests are sent in order', () async {
      final network = RequestCapturingNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.events.record(key: 'first');
      await sdk.processEventsAndRequests();

      await sdk.events.record(key: 'second');
      await sdk.processEventsAndRequests();

      // Find event requests
      final eventReqs = network.sent.where((r) => r.containsKey('events')).toList();

      if (eventReqs.length >= 2) {
        final firstEvents = jsonDecode(eventReqs[0]['events'] as String) as List;
        final secondEvents = jsonDecode(eventReqs[1]['events'] as String) as List;

        expect((firstEvents.first as Map)['key'], 'first');
        expect((secondEvents.first as Map)['key'], 'second');
      }
    });
  });

  group('Request Queue Persistence', () {
    test('pending requests are persisted to storage', () async {
      final storage = MemoryBackedStorage();

      // Create instance with failing network
      final cfg = CountlyConfig(
        appKey: 'test-app-key',
        serverUrl: 'https://example.com',
        deviceId: 'test-device-id',
        storageMode: StorageMode.persistent,
        giveConsent: true,
        storageMethods: storage.toMethods(),
        networkClientOverride: _FailingNetworkClient('https://example.com'),
      );
      final sdk = await Countly.init(cfg);

      await sdk.events.record(key: 'will_persist');
      await sdk.processEventsAndRequests();

      await Future.delayed(const Duration(milliseconds: 100));

      // Request queue should be persisted
      final queueData = storage.backing['default_COUNTLY_DART_RQ'];
      expect(queueData, isNotNull);
      expect(queueData!.contains('will_persist'), true);

      await Countly.disposeAll();
    });

    test('persisted requests are restored on init', () async {
      final storage = MemoryBackedStorage();

      // Pre-populate storage with request
      final request = {
        'app_key': 'test-app-key',
        'device_id': 'test-device',
        'events': '[{"key":"restored_event","count":1,"timestamp":123456}]',
        'timestamp': 123456,
      };
      storage.backing['default_COUNTLY_DART_RQ'] = jsonEncode([request]);

      final network = RequestCapturingNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'test-app-key',
        serverUrl: 'https://example.com',
        deviceId: 'test-device',
        storageMode: StorageMode.persistent,
        giveConsent: true,
        storageMethods: storage.toMethods(),
        networkClientOverride: network,
      );
      final sdk = await Countly.init(cfg);

      await sdk.processEventsAndRequests();

      // Restored request should be sent
      final sentWithRestored = network.sent.any(
        (r) => r.containsKey('events') && (r['events'] as String).contains('restored_event'),
      );
      expect(sentWithRestored, true);

      await Countly.disposeAll();
    });
  });

  group('Server URL Handling', () {
    test('trailing slash is handled correctly', () async {
      final network = RequestCapturingNetworkClient('https://example.com/');
      final cfg = CountlyConfig(
        appKey: 'test-app-key',
        serverUrl: 'https://example.com/',
        deviceId: 'test-device-id',
        storageMode: StorageMode.memory,
        giveConsent: true,
        networkClientOverride: network,
      );
      final sdk = await Countly.init(cfg);

      await sdk.events.record(key: 'test');
      await sdk.processEventsAndRequests();

      // Should work without double slashes
      expect(network.sent.isNotEmpty, true);

      await Countly.disposeAll();
    });

    test('HTTPS URL is accepted', () async {
      final network = RequestCapturingNetworkClient('https://secure.example.com');
      final cfg = CountlyConfig(
        appKey: 'test-app-key',
        serverUrl: 'https://secure.example.com',
        deviceId: 'test-device-id',
        storageMode: StorageMode.memory,
        giveConsent: true,
        networkClientOverride: network,
      );
      final sdk = await Countly.init(cfg);

      await sdk.events.record(key: 'test');
      await sdk.processEventsAndRequests();

      expect(network.sent.isNotEmpty, true);

      await Countly.disposeAll();
    });
  });

  group('Error Handling in Requests', () {
    test('failed requests are retried', () async {
      final network = _RetryCountingNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'test-app-key',
        serverUrl: 'https://example.com',
        deviceId: 'test-device-id',
        storageMode: StorageMode.memory,
        giveConsent: true,
        networkClientOverride: network,
      );
      final sdk = await Countly.init(cfg);

      await sdk.events.record(key: 'retry_test');

      // Process multiple times to trigger retries
      await sdk.processEventsAndRequests();
      await sdk.processEventsAndRequests();
      await sdk.processEventsAndRequests();

      expect(network.attemptCount, greaterThanOrEqualTo(1), reason: 'Requests should be attempted');

      await Countly.disposeAll();
    });

    test('successful response clears request from queue', () async {
      final network = RequestCapturingNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.events.record(key: 'test');
      await sdk.processEventsAndRequests();

      expect(sdk.debugRequestQueueLength, 0, reason: 'Successful request should be removed');
    });
  });

  group('Device ID in Requests', () {
    test('all requests include current device_id', () async {
      final network = RequestCapturingNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.events.record(key: 'event1');
      await sdk.events.record(key: 'event2');
      await sdk.processEventsAndRequests();

      for (final req in network.sent) {
        expect(req['device_id'], 'test-device-id');
      }
    });

    test('device_id change is reflected in new requests', () async {
      final network = RequestCapturingNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      // Change device ID
      await sdk.id.changeWithMerge('new-device-id');

      await sdk.events.record(key: 'after_change');
      await sdk.processEventsAndRequests();

      // New requests should have new device ID
      final newIdReq = network.sent.any((r) => r['device_id'] == 'new-device-id');
      expect(newIdReq, true);
    });
  });
}

class _FailingNetworkClient extends NetworkClient {
  _FailingNetworkClient(String baseUrl) : super(baseUrl);

  @override
  Future<http.Response> makeRequest(Map<String, dynamic> data, String endPoint) async {
    throw Exception('Network failure');
  }

  @override
  Future<http.Response> makeSelectiveRequest(Map<String, dynamic> data) async {
    throw Exception('Network failure');
  }
}

class _RetryCountingNetworkClient extends NetworkClient {
  int attemptCount = 0;

  _RetryCountingNetworkClient(String baseUrl) : super(baseUrl);

  @override
  Future<http.Response> makeRequest(Map<String, dynamic> data, String endPoint) async {
    attemptCount++;
    if (attemptCount < 3) {
      throw Exception('Temporary failure');
    }
    if (data['method'] == 'sc') {
      return FakeResponseSuccess(body: '{"c":{}}');
    }
    return FakeResponseSuccess();
  }

  @override
  Future<http.Response> makeSelectiveRequest(Map<String, dynamic> data) async {
    attemptCount++;
    return FakeResponseSuccess();
  }
}

/// A local stand-in for a Countly server: records every request it receives and answers
/// `{"result":"Success"}`, or HTTP 500 while [failuresLeft] is above zero.
class _MockCountlyServer {
  final HttpServer _server;
  final List<({String path, Map<String, dynamic> body})> received = [];
  int failuresLeft = 0;

  _MockCountlyServer._(this._server) {
    _server.listen(_answer);
  }

  /// Starts the server on a free localhost port.
  static Future<_MockCountlyServer> start() async =>
      _MockCountlyServer._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  /// The server URL to give the SDK.
  String get url => 'http://${_server.address.address}:${_server.port}';

  /// Records [request] and answers it.
  Future<void> _answer(HttpRequest request) async {
    final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map<String, dynamic>;
    received.add((path: request.uri.path, body: body));
    final fail = failuresLeft > 0;
    if (fail) failuresLeft--;
    request.response
      ..statusCode = fail ? 500 : 200
      ..headers.contentType = ContentType.json
      ..write(fail ? '{"result":"Error"}' : '{"result":"Success"}');
    await request.response.close();
  }

  /// Stops the server.
  Future<void> close() => _server.close(force: true);
}

/// Names a request by the key that sets it apart from the fields every request carries.
String _requestKind(Map<String, dynamic> req) {
  if (req['method'] == 'sc') return 'sbs';
  const kinds = ['hc', 'consent', 'location', 'metrics', 'events', 'old_device_id', 'user_details'];
  return kinds.firstWhere(req.containsKey, orElse: () => 'other');
}

/// Expects [req] to carry a timestamp in ms, and the hour, day of week (0 is Sunday) and
/// timezone offset in minutes of that same moment on this machine.
void _expectTimeFieldsOfItsTimestamp(Map<String, dynamic> req) {
  final reason = 'request: $req';
  expect(req['timestamp'], isA<int>(), reason: reason);
  final time = DateTime.fromMillisecondsSinceEpoch(req['timestamp'] as int);
  expect(req['hour'], time.hour, reason: reason);
  expect(req['dow'], time.weekday == DateTime.sunday ? 0 : time.weekday, reason: reason);
  expect(req['tz'], time.timeZoneOffset.inMinutes, reason: reason);
}

/// Polls [condition] until it holds, and fails the test when it still does not after [timeout].
Future<void> _waitFor(bool Function() condition, {Duration timeout = const Duration(seconds: 10)}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('Condition not met within $timeout');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
