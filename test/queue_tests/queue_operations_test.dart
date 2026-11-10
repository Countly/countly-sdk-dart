import 'dart:async';
import 'dart:convert';

import 'package:countly_sdk_dart_core/countly_sdk_dart_core.dart';
import 'package:countly_sdk_dart_core/src/constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class TestLogger implements SdkLogger {
  final List<String> logs = [];
  @override
  bool isEnabled(LogLevel level) => true;
  @override
  void log(LogLevel level, String message, {Object? error, StackTrace? stack}) {
    logs.add('[${level.name}] $message');
  }
}

class MemoryBackedStorage {
  final Map<String, String> backing;
  MemoryBackedStorage(this.backing);

  CustomStorageMethods toMethods() {
    return CustomStorageMethods(
      read: (key) async => backing[key],
      write: (key, value) async => backing[key] = value,
      remove: (key) async => backing.remove(key),
      keys: () async => backing.keys.toList(),
    );
  }
}

/// A request as the server received it.
class ServerRequest {
  final http.BaseRequest request;
  final Map<String, dynamic> params;
  int? status;
  ServerRequest(this.request, this.params);

  static const _common = {'app_key', 'device_id', 'sdk_version', 'sdk_name', 'av',
      'timestamp', 'hour', 'dow', 'tz', 'rr'};

  /// Path, app key and what the request carries, for example "/i app-key-a events[e1]".
  String describe() {
    final parts = [request.url.path, '${params['app_key']}'];
    for (final key in params.keys.where((k) => !_common.contains(k)).toList()..sort()) {
      if (key == 'method') {
        parts.add('method=${params[key]}');
      } else if (key == 'events') {
        final events = jsonDecode(params[key] as String) as List<dynamic>;
        final names = events.map((e) => e['key'] == '[CLY]_view' ? 'view:${e['segmentation']['name']}' : e['key']);
        parts.add('events[${names.join(',')}]');
      } else {
        parts.add(key);
      }
    }
    if (status != 200) parts.add('status=$status');
    return parts.join(' ');
  }
}

/// Stands in for the Countly server: records every request, answers 503 while [down],
/// and can keep the next request on its way until [release] is called.
class FakeServer extends http.BaseClient {
  final List<ServerRequest> requests = [];
  bool down = false;
  Completer<void>? _held;
  bool _holdNext = false;

  void holdNext() {
    _holdNext = true;
    _held = Completer<void>();
  }

  void release() => _held?.complete();

  List<String> describe() => requests.map((r) => r.describe()).toList();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final captured = ServerRequest(request, jsonDecode((request as http.Request).body) as Map<String, dynamic>);
    requests.add(captured);
    if (_holdNext) {
      _holdNext = false;
      await _held!.future;
    }
    captured.status = down ? 503 : 200;
    final body = down ? 'down' : (captured.params['method'] == 'sc' ? '{"c":{}}' : '{"result":"Success"}');
    return http.StreamedResponse(Stream.value(utf8.encode(body)), captured.status!,
        headers: {'content-type': 'application/json'});
  }
}

Future<CountlyInstance> _init(
  FakeServer server, {
  String appKey = 'app-key-a',
  TestLogger? logger,
  Map<String, String>? storageBacking,
}) async {
  final cfg = CountlyConfig(
    appKey: appKey,
    serverUrl: 'https://example.com',
    deviceId: 'test-device',
    storageMode: storageBacking == null ? StorageMode.memory : StorageMode.persistent,
    storageMethods: storageBacking == null ? null : MemoryBackedStorage(storageBacking).toMethods(),
    giveConsent: true,
    enableSDKLogs: true,
    logger: logger ?? TestLogger(),
  );
  final sdk = await http.runWithClient(() => Countly.init(cfg), () => server);
  addTearDown(() async {
    await Countly.disposeAll();
  });
  return sdk;
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var i = 0; i < 200 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(condition(), isTrue, reason: 'condition was not reached in time');
}

List<dynamic> _storedRequests(Map<String, String> backing) =>
    jsonDecode(backing['default_${StorageSubKeys.requestQueue}']!) as List<dynamic>;

List<dynamic> _queuedAppKeys(CountlyInstance sdk) => sdk.debugRequestQueueSnapshot.map((r) => r['app_key']).toList();

void main() {
  group('flushQueues', () {
    test('discards queued events and requests, keeps the running view and pending user properties', () async {
      final backing = <String, String>{};
      final server = FakeServer();
      final sdk = await _init(server, storageBacking: backing);
      await sdk.views.startAutoStoppedView('Kept view');
      await sdk.events.record(key: 'flushed_event');
      expect(sdk.debugRequestQueueLength, 3);
      expect(sdk.debugEventQueueLength, 1);

      await sdk.flushQueues();

      expect(sdk.debugRequestQueueLength, 0);
      expect(sdk.debugEventQueueLength, 0);
      expect(backing['default_${StorageSubKeys.requestQueue}'], '[]');
      expect(backing['default_${StorageSubKeys.eventQueue}'], '[]');
      expect(sdk.debugActiveViewName, 'Kept view');

      await sdk.users.setProperties({'name': 'Kept user'});
      await sdk.flushQueues();
      server.requests.clear();
      await sdk.views.endActiveView();
      await sdk.events.record(key: 'new_event');
      await sdk.processEventsAndRequests();

      expect(server.describe(), [
        '/i app-key-a user_details',
        '/i app-key-a events[view:Kept view,new_event]',
      ]);
      expect(server.requests.first.params['user_details'], {'name': 'Kept user'});
    });

    test('a request on its way is completed and the flushed requests are never sent', () async {
      final logger = TestLogger();
      final server = FakeServer();
      final sdk = await _init(server, logger: logger);
      server.requests.clear();

      server.holdNext();
      final sending = sdk.processEventsAndRequests();
      await _waitUntil(() => server.requests.isNotEmpty);
      await sdk.flushQueues();
      server.release();
      await sending;

      expect(server.describe(), ['/i app-key-a consent'], reason: 'location and metrics were flushed');
      expect(sdk.debugRequestQueueLength, 0);
      expect(logger.logs.where((l) => l.contains('Queue lock action failed')), isEmpty);
      await sdk.events.record(key: 'after_flush');
      await sdk.processEventsAndRequests();
      expect(server.describe().last, '/i app-key-a events[after_flush]');
    });
  });

  group('replaceAllAppKeysInQueueWithCurrentAppKey', () {
    test('queued requests of the old app key are sent with the current app key', () async {
      final backing = <String, String>{};
      final server = FakeServer();
      final sdk = await _init(server, storageBacking: backing);
      await sdk.events.record(key: 'old_app_event');
      await sdk.changeAppKey('app-key-b');
      expect(_queuedAppKeys(sdk), ['app-key-a', 'app-key-a', 'app-key-a', 'app-key-a', 'app-key-b']);

      await sdk.replaceAllAppKeysInQueueWithCurrentAppKey();

      expect(_queuedAppKeys(sdk), List.filled(5, 'app-key-b'));
      expect(_storedRequests(backing).map((r) => r['app_key']), List.filled(5, 'app-key-b'));
      server.requests.clear();
      await sdk.processEventsAndRequests();
      expect(server.describe(), [
        '/i app-key-b consent',
        '/i app-key-b location',
        '/i app-key-b metrics',
        '/i app-key-b events[old_app_event]',
        '/i app-key-b consent',
      ]);
    });

    test('a request on its way keeps its key, its retry carries the current app key', () async {
      final server = FakeServer();
      final sdk = await _init(server);
      await sdk.changeAppKey('app-key-b');
      server.requests.clear();

      server.holdNext();
      final sending = sdk.processEventsAndRequests();
      await _waitUntil(() => server.requests.isNotEmpty);
      await sdk.replaceAllAppKeysInQueueWithCurrentAppKey();
      sdk.debugOverrideBehaviorSettings(timerIntervalSeconds: 1); // short backoff for the retry
      server.down = true;
      server.release();
      await sending;
      server.down = false;
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await sdk.processEventsAndRequests();

      expect(server.describe(), [
        '/i app-key-a consent status=503',
        '/i app-key-b consent',
        '/i app-key-b location',
        '/i app-key-b metrics',
        '/i app-key-b consent',
      ]);
    });
  });

  group('removeDifferentAppKeysFromQueue', () {
    test('removes the requests of other app keys, also when a stored key was loaded as a number', () async {
      final backing = <String, String>{
        'default_${StorageSubKeys.requestQueue}': jsonEncode(['app_key=12345&device_id=test-device&begin_session=1']),
      };
      final server = FakeServer()..down = true;
      final sdk = await _init(server, appKey: '12345', storageBacking: backing);
      expect(_queuedAppKeys(sdk), [12345, '12345', '12345', '12345']);

      await sdk.removeDifferentAppKeysFromQueue();
      expect(sdk.debugRequestQueueLength, 4, reason: 'every queued request belongs to the current app');

      await sdk.changeAppKey('app-key-b');
      await sdk.removeDifferentAppKeysFromQueue();
      expect(_queuedAppKeys(sdk), ['app-key-b']);
      expect(sdk.debugRequestQueueSnapshot.single.containsKey('consent'), isTrue);
      expect(_storedRequests(backing).map((r) => r['app_key']), ['app-key-b']);
      await Countly.disposeAll();

      // The next start sends what is stored: only the app-key-b request, the removed ones never arrive.
      server.down = false;
      server.requests.clear();
      await _init(server, appKey: '12345', storageBacking: backing);
      expect(server.describe(), [
        '/i app-key-b consent',
        '/o/sdk 12345 method=sc',
        '/i 12345 hc metrics',
      ]);
    });

    test('a request on its way is completed and the removed requests are never sent', () async {
      final server = FakeServer();
      final sdk = await _init(server);
      await sdk.changeAppKey('app-key-b');
      server.requests.clear();

      server.holdNext();
      final sending = sdk.processEventsAndRequests();
      await _waitUntil(() => server.requests.isNotEmpty);
      await sdk.removeDifferentAppKeysFromQueue();
      server.release();
      await sending;

      expect(server.describe(), ['/i app-key-a consent', '/i app-key-b consent']);
      expect(sdk.debugRequestQueueLength, 0);
    });
  });
}
