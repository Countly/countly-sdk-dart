import 'dart:async';
import 'dart:convert';

import 'package:countly_sdk_dart_core/countly_sdk_dart_core.dart';
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

  int count(LogLevel level, String text) =>
      logs.where((l) => l.startsWith('[${level.name}]') && l.contains(text)).length;
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

  /// Host, path, app key and what the request carries, for example "server-a.com/i app-key-a events[e1]".
  String describe() {
    final parts = ['${request.url.host}${request.url.path}', '${params['app_key']}'];
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

/// Stands in for the Countly servers: records every request, answers 503 while [down],
/// and can keep the next request on its way until [release] is called.
class FakeServers extends http.BaseClient {
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
  FakeServers servers, {
  TestLogger? logger,
  Map<String, String>? storageBacking,
}) async {
  final cfg = CountlyConfig(
    appKey: 'app-key-a',
    serverUrl: 'https://server-a.com',
    deviceId: 'test-device',
    storageMode: storageBacking == null ? StorageMode.memory : StorageMode.persistent,
    storageMethods: storageBacking == null ? null : MemoryBackedStorage(storageBacking).toMethods(),
    giveConsent: true,
    enableSDKLogs: true,
    logger: logger ?? TestLogger(),
    customRequestHeaders: {'X-Custom': 'kept'},
  );
  final sdk = await http.runWithClient(() => Countly.init(cfg), () => servers);
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

void main() {
  group('changeServerUrl', () {
    test('queued, new and immediate requests go to the new URL with the same app key and headers', () async {
      final servers = FakeServers();
      final sdk = await _init(servers);
      // Init sent the settings fetch and the health check to server A, and queued consent, location and metrics.
      expect(servers.describe(), ['server-a.com/o/sdk app-key-a method=sc', 'server-a.com/i app-key-a hc metrics']);
      expect(sdk.debugRequestQueueLength, 3);
      await sdk.events.record(key: 'before_change');
      servers.requests.clear();

      await sdk.changeServerUrl('https://server-b.com///');

      expect(sdk.config.serverUrl, 'https://server-b.com');
      expect(sdk.config.appKey, 'app-key-a');
      await sdk.events.record(key: 'after_change');
      await sdk.processEventsAndRequests();

      expect(servers.describe(), [
        'server-b.com/o/sdk app-key-a method=sc',
        'server-b.com/i app-key-a consent',
        'server-b.com/i app-key-a location',
        'server-b.com/i app-key-a metrics',
        'server-b.com/i app-key-a consent',
        'server-b.com/i app-key-a events[before_change,after_change]',
      ]);
      expect(servers.requests.every((r) => r.request.headers['x-custom'] == 'kept'), isTrue);
      expect(servers.requests.every((r) => r.params['device_id'] == 'test-device'), isTrue);
      expect(sdk.debugRequestQueueLength, 0);
    });

    test('invalid URLs are ignored and traffic stays on the current server', () async {
      final logger = TestLogger();
      final servers = FakeServers();
      final sdk = await _init(servers, logger: logger);
      await sdk.processEventsAndRequests();
      servers.requests.clear();

      for (final url in ['', 'not a url', 'ftp://server-b.com', 'server-b.com', 'http://', 'https:///']) {
        await sdk.changeServerUrl(url);
      }

      expect(sdk.config.serverUrl, 'https://server-a.com');
      expect(logger.count(LogLevel.error, 'changeServerUrl called with'), 6);
      expect(sdk.debugRequestQueueLength, 0, reason: 'no catch-up requests after an invalid URL');
      expect(servers.requests, isEmpty, reason: 'no SDK behavior settings fetch after an invalid URL');
      await sdk.events.record(key: 'still_on_a');
      await sdk.processEventsAndRequests();
      expect(servers.describe(), ['server-a.com/i app-key-a events[still_on_a]']);
    });

    test('a request on its way finishes at the old URL and its retry goes to the new URL', () async {
      final servers = FakeServers();
      final sdk = await _init(servers);
      await sdk.processEventsAndRequests();
      await sdk.events.record(key: 'on_its_way');
      servers.requests.clear();

      servers.holdNext();
      final sending = sdk.processEventsAndRequests();
      await _waitUntil(() => servers.requests.isNotEmpty);
      await sdk.changeServerUrl('https://server-b.com');
      sdk.debugOverrideBehaviorSettings(timerIntervalSeconds: 1); // short backoff for the retry
      servers.down = true;
      servers.release();
      await sending;
      servers.down = false;
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await sdk.processEventsAndRequests();

      expect(servers.describe(), [
        'server-a.com/i app-key-a events[on_its_way] status=503',
        'server-b.com/o/sdk app-key-a method=sc',
        'server-b.com/i app-key-a events[on_its_way]',
        'server-b.com/i app-key-a consent',
      ]);
      expect(sdk.debugRequestQueueLength, 0);
    });

    test('URL and app key changes are kept in memory only', () async {
      final backing = <String, String>{};
      final servers = FakeServers();
      final sdk = await _init(servers, storageBacking: backing);
      await sdk.changeServerUrl('https://server-b.com');
      await sdk.changeAppKey('app-key-b');
      await Countly.disposeAll();

      // Both changes together: the queued requests keep app-key-a, the new ones carry app-key-b, all go to server B.
      expect(servers.describe().skip(2), [
        'server-b.com/o/sdk app-key-a method=sc',
        'server-b.com/o/sdk app-key-b method=sc',
        'server-b.com/i app-key-a consent',
        'server-b.com/i app-key-a location',
        'server-b.com/i app-key-a metrics',
        'server-b.com/i app-key-a consent',
        'server-b.com/i app-key-b consent',
      ]);
      expect(backing.values.any((v) => v.contains('server-b.com') || v.contains('app-key-b')), isFalse);

      servers.requests.clear();
      final again = await _init(servers, storageBacking: backing);
      expect(again.config.serverUrl, 'https://server-a.com');
      expect(again.config.appKey, 'app-key-a');
      await again.processEventsAndRequests();
      expect(servers.requests, isNotEmpty);
      expect(servers.requests.map((r) => '${r.request.url.host} ${r.params['app_key']}').toSet(),
          {'server-a.com app-key-a'});
    });
  });

  group('changeAppKey', () {
    test('closes the old app with the old key, then new requests carry the new key', () async {
      final servers = FakeServers();
      final sdk = await _init(servers);
      await sdk.processEventsAndRequests();
      await sdk.views.startAutoStoppedView('Home');
      await sdk.events.record(key: 'old_app_event');
      await sdk.users.setProperties({'name': 'Old App User'});
      servers.requests.clear();

      await sdk.changeAppKey('app-key-b');

      expect(sdk.config.appKey, 'app-key-b');
      expect(sdk.config.serverUrl, 'https://server-a.com');
      expect(sdk.debugActiveViewName, isNull, reason: 'the running view is ended for the old app');
      expect(sdk.debugEventQueueLength, 0);
      await sdk.events.record(key: 'new_app_event');
      await sdk.processEventsAndRequests();

      expect(servers.describe(), [
        'server-a.com/o/sdk app-key-b method=sc',
        'server-a.com/i app-key-a events[old_app_event]',
        'server-a.com/i app-key-a user_details',
        'server-a.com/i app-key-a events[view:Home]',
        'server-a.com/i app-key-b consent',
        'server-a.com/i app-key-b events[new_app_event]',
      ]);
      expect(servers.requests[2].params['user_details'], {'name': 'Old App User'});
      expect(servers.requests.every((r) => r.params['device_id'] == 'test-device'), isTrue);
      expect(servers.requests.every((r) => r.request.headers['x-custom'] == 'kept'), isTrue);
    });

    test('invalid, placeholder and current app keys are ignored', () async {
      final logger = TestLogger();
      final servers = FakeServers();
      final sdk = await _init(servers, logger: logger);
      await sdk.views.startAutoStoppedView('Home');
      final queued = sdk.debugRequestQueueLength;
      servers.requests.clear();

      for (final key in ['', '   ', 'YOUR_APP_KEY', 'app-key-a', ' app-key-a ']) {
        await sdk.changeAppKey(key);
      }

      expect(sdk.config.appKey, 'app-key-a');
      expect(logger.count(LogLevel.error, 'changeAppKey called with'), 3);
      expect(logger.count(LogLevel.debug, 'changeAppKey called with the current app key'), 2);
      expect(sdk.debugActiveViewName, 'Home', reason: 'nothing is closed when the key does not change');
      expect(sdk.debugRequestQueueLength, queued, reason: 'no catch-up requests');
      expect(servers.requests, isEmpty, reason: 'no SDK behavior settings fetch');
    });
  });

  test('a disposed instance ignores the server URL, app key and queue calls', () async {
    final logger = TestLogger();
    final servers = FakeServers();
    final sdk = await _init(servers, logger: logger);
    await sdk.dispose();
    servers.requests.clear();

    await sdk.changeServerUrl('https://server-b.com');
    await sdk.changeAppKey('app-key-b');
    await sdk.flushQueues();
    await sdk.replaceAllAppKeysInQueueWithCurrentAppKey();
    await sdk.removeDifferentAppKeysFromQueue();

    expect(sdk.config.serverUrl, 'https://server-a.com');
    expect(sdk.config.appKey, 'app-key-a');
    expect(servers.requests, isEmpty);
    for (final call in [
      'changeServerUrl',
      'changeAppKey',
      'flushQueues',
      'replaceAllAppKeysInQueueWithCurrentAppKey',
      'removeDifferentAppKeysFromQueue'
    ]) {
      expect(logger.count(LogLevel.warning, 'Action ["$call"] ignored: instance disposed'), 1);
    }
  });
}
