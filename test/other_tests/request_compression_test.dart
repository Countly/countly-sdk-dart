import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:countly_sdk_dart_core/countly_sdk_dart_core.dart';
import 'package:countly_sdk_dart_core/src/gzip/gzip_codec.dart';
import 'package:countly_sdk_dart_core/src/networking.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

const _base = 'https://gzip.example.com';
const _marker = 'content_encoding=gzip';

/// One request as the server received it, its body decoded the way the Countly server reads it: as gzip only when the
/// compression marker is the only query of the URL.
class Received {
  final Uri url;
  final bool compressed;
  final Map<String, dynamic> body;
  final int bodyBytes;
  final Map<String, String> headers;

  Received(this.url, this.compressed, this.body, this.bodyBytes, this.headers);
}

/// A Countly server stand-in: records every request, answers the SDK behavior settings with "gzip": true while [gzip]
/// is set, and refuses or drops compressed requests on demand.
class GzipServer extends http.BaseClient {
  final List<Received> received = [];
  bool gzip;
  int refuseCompressed = 0;
  int refuseStatus = 400;
  String refuseAnswer = '{"result":"Invalid request body"}';
  bool dropCompressed = false;

  GzipServer({this.gzip = true});

  List<Received> withMarker(String marker) => received.where((r) => r.body['marker'] == marker).toList();

  List<Received> get settingsRequests => received.where((r) => r.body['method'] == 'sc').toList();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bytes = await request.finalize().toBytes();
    final compressed = request.url.query == _marker;
    final text = utf8.decode(compressed ? io.gzip.decode(bytes) : bytes);
    final body = jsonDecode(text) as Map<String, dynamic>;
    received.add(Received(request.url, compressed, body, bytes.length, request.headers));
    if (compressed && dropCompressed) {
      throw http.ClientException('the connection was dropped', request.url);
    }
    var status = 200;
    var answer = '{"result":"Success"}';
    if (body['method'] == 'sc') {
      answer = jsonEncode({
        'v': 1,
        't': 1,
        'c': {'lkl': 100},
        if (gzip && body['gzip'] == '1') 'gzip': true
      });
    }
    if (compressed && refuseCompressed > 0) {
      refuseCompressed--;
      status = refuseStatus;
      answer = refuseAnswer;
    }
    return http.StreamedResponse(Stream.value(utf8.encode(answer)), status,
        request: request, headers: {'content-type': 'application/json'});
  }
}

/// A network client with request compression on, sending to [server], which already said that it reads gzip.
NetworkClient _client(GzipServer server, {bool accepted = true}) {
  final client = NetworkClient(_base, client: server)..requestCompressionEnabled = true;
  if (accepted) {
    client.onGzipAnswer(_base, true);
  }
  return client;
}

/// Sends a queued-style request with a payload of [length] characters, told apart by its [marker] parameter, and tells
/// whether its answer was accepted.
Future<bool> _send(NetworkClient client, String marker, int length) async {
  final resp = await client.makeRequest({'app_key': 'app-key', 'marker': marker, 'payload': 'a' * length}, '/i');
  return client.isResponseValid(resp);
}

void main() {
  group('Request compression in the network client', () {
    test('sends plain bodies while compression is off, or before the server says it reads gzip', () async {
      final server = GzipServer();
      final off = NetworkClient(_base, client: server)..onGzipAnswer(_base, true);
      await _send(off, 'off', 5000);
      await _send(_client(server, accepted: false), 'no_answer_yet', 5000);

      expect(server.withMarker('off').single.compressed, isFalse);
      expect(server.withMarker('no_answer_yet').single.compressed, isFalse);
    });

    test('sends a body of at least 1 KB gzip-compressed to the marked URL, as JSON without a Content-Encoding header',
        () async {
      final server = GzipServer();
      expect(await _send(_client(server), 'big', 5000), isTrue);

      final big = server.withMarker('big').single;
      expect(big.compressed, isTrue);
      expect(big.url.toString(), '$_base/i?$_marker');
      expect(big.bodyBytes, lessThan(1000));
      expect(big.headers['Content-Type'], 'application/json');
      expect(big.headers.keys.map((k) => k.toLowerCase()), isNot(contains('content-encoding')));
      expect(big.body['payload'], 'a' * 5000);
      expect(big.body['app_key'], 'app-key');
    });

    test('keeps a body under 1 KB plain and compresses a bigger one after it', () async {
      final server = GzipServer();
      final client = _client(server);
      await _send(client, 'small', 300);
      await _send(client, 'big', 5000);

      expect(server.withMarker('small').single.compressed, isFalse);
      expect(server.withMarker('small').single.bodyBytes, lessThan(1024));
      expect(server.withMarker('big').single.compressed, isTrue);
    });

    test('keeps a body over 1 MB plain and keeps compressing the requests after it', () async {
      final server = GzipServer();
      final client = _client(server);
      await _send(client, 'huge', 1024 * 1024);
      await _send(client, 'big', 5000);

      expect(server.withMarker('huge').single.compressed, isFalse);
      expect(server.withMarker('huge').single.bodyBytes, greaterThan(1024 * 1024));
      expect(server.withMarker('big').single.compressed, isTrue);
    });

    test('a refused compressed request stops compression until a later settings answer says gzip again', () async {
      final server = GzipServer()..refuseCompressed = 1;
      final client = _client(server);
      expect(await _send(client, 'refused', 5000), isFalse);
      expect(await _send(client, 'retry', 5000), isTrue);
      client.onGzipAnswer(_base, false);
      await _send(client, 'without_gzip_answer', 5000);
      client.onGzipAnswer(_base, true);
      await _send(client, 'with_gzip_answer', 5000);

      expect(server.withMarker('refused').single.compressed, isTrue);
      expect(server.withMarker('retry').single.compressed, isFalse);
      expect(server.withMarker('without_gzip_answer').single.compressed, isFalse);
      expect(server.withMarker('with_gzip_answer').single.compressed, isTrue);
    });

    test('a compressed request answered with 200 but without "result" stops compression', () async {
      final server = GzipServer()
        ..refuseCompressed = 1
        ..refuseStatus = 200
        ..refuseAnswer = '{}';
      final client = _client(server);
      expect(await _send(client, 'no_result', 5000), isFalse);
      await _send(client, 'after', 5000);

      expect(server.withMarker('after').single.compressed, isFalse);
    });

    for (final answer in [
      ['JSON', 200, '{"color":"red"}', true],
      ['a page', 200, '<html><body>Bad gateway</body></html>', false],
      ['nothing', 200, '', false],
      ['an error status', 400, '{"result":"Invalid request body"}', false],
    ]) {
      test('a compressed request whose JSON answer is enough ${answer[3] == true ? 'keeps' : 'stops'} compression when answered with ${answer[0]}',
          () async {
        final server = GzipServer()
          ..refuseCompressed = 1
          ..refuseStatus = answer[1] as int
          ..refuseAnswer = answer[2] as String;
        final client = _client(server);
        final resp = await client.makeRequest({'method': 'rc', 'marker': 'direct', 'payload': 'a' * 5000}, '/o/sdk');
        client.isResponseValid(resp, acceptJSON: true);
        await _send(client, 'after', 5000);

        expect(server.withMarker('direct').single.compressed, isTrue);
        expect(server.withMarker('after').single.compressed, answer[3]);
      });
    }

    test('a compressed request that got no answer does not stop compression', () async {
      final server = GzipServer()..dropCompressed = true;
      final client = _client(server);
      await expectLater(_send(client, 'dropped', 5000), throwsA(isA<http.ClientException>()));
      server.dropCompressed = false;
      expect(await _send(client, 'retried', 5000), isTrue);

      expect(server.withMarker('retried').single.compressed, isTrue);
    });

    test('sends plain bodies to a new server URL until that server says it reads gzip', () async {
      final server = GzipServer();
      final client = _client(server);
      client.baseUrl = 'https://other.example.com';
      await _send(client, 'new_server', 5000);
      client.onGzipAnswer('https://other.example.com', true);
      await _send(client, 'after_answer', 5000);

      expect(server.withMarker('new_server').single.compressed, isFalse);
      expect(server.withMarker('after_answer').single.compressed, isTrue);
      expect(server.withMarker('after_answer').single.url.host, 'other.example.com');
    });

    test('gzipBytes gives gzip that decodes to the input', () async {
      final plain = Uint8List.fromList(utf8.encode('{"payload":"${'a' * 2000}"}'));
      final compressed = await gzipBytes(plain);

      expect(compressed, isNotNull);
      expect(compressed!.length, lessThan(plain.length));
      expect(io.gzip.decode(compressed), plain);
    });
  });

  group('Request compression through the SDK', () {
    tearDown(() async {
      await Countly.disposeAll();
    });

    /// Starts the SDK against [server] and waits until it has stored the settings answer, which it reads first.
    Future<CountlyInstance> start(GzipServer server, {required bool compression, Map<String, String>? storage}) async {
      final backing = storage ?? <String, String>{};
      final inst = await Countly.init(CountlyConfig(
        appKey: 'app-key',
        serverUrl: _base,
        deviceId: 'gzip-device',
        storageMode: StorageMode.persistent,
        storageMethods: CustomStorageMethods(
          read: (key) async => backing[key],
          write: (key, value) async => backing[key] = value,
          remove: (key) async => backing.remove(key),
          keys: () async => backing.keys.toList(),
        ),
        giveConsent: true,
        enableRequestCompression: compression,
        networkClientOverride: NetworkClient(_base, client: server),
      ));
      for (var i = 0; i < 200 && !backing.keys.any((k) => k.contains('COUNTLY_DART_SBS')); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(backing.keys.any((k) => k.contains('COUNTLY_DART_SBS')), isTrue, reason: 'the settings answer was not stored');
      return inst;
    }

    /// Records events whose request body is well over 1 KB, and sends them.
    Future<void> sendBigEvents(CountlyInstance inst) async {
      for (var i = 0; i < 20; i++) {
        await inst.events.record(key: 'big_event_$i', segmentation: {'blob': 'b' * 200});
      }
      await inst.processEventsAndRequests();
    }

    test('without enableRequestCompression, the settings request does not ask for gzip and requests go plain',
        () async {
      final server = GzipServer();
      final inst = await start(server, compression: false);
      await sendBigEvents(inst);

      expect(server.settingsRequests.single.body.containsKey('gzip'), isFalse);
      final events = server.received.where((r) => r.body.containsKey('events')).toList();
      expect(events, isNotEmpty);
      expect(events.every((r) => !r.compressed), isTrue);
    });

    test('asks for gzip, compresses the event request once the server says it reads gzip, and never stores the key',
        () async {
      final server = GzipServer();
      final backing = <String, String>{};
      final inst = await start(server, compression: true, storage: backing);
      await sendBigEvents(inst);

      expect(server.settingsRequests.single.body['gzip'], '1');
      final events = server.received.where((r) => r.body.containsKey('events')).toList();
      expect(events, isNotEmpty);
      expect(events.every((r) => r.compressed), isTrue);
      expect((jsonDecode(events.first.body['events'] as String) as List).length, 20);
      final stored = backing.entries.firstWhere((e) => e.key.contains('COUNTLY_DART_SBS')).value;
      expect(stored, isNot(contains('gzip')));
    });

    test('sends plain requests when the settings answer has no gzip key', () async {
      final server = GzipServer(gzip: false);
      final inst = await start(server, compression: true);
      await sendBigEvents(inst);

      expect(server.settingsRequests.single.body['gzip'], '1');
      final events = server.received.where((r) => r.body.containsKey('events')).toList();
      expect(events, isNotEmpty);
      expect(events.every((r) => !r.compressed), isTrue);
    });

    test('a refused compressed event request stays queued and goes plain on its next try', () async {
      final server = GzipServer()..refuseCompressed = 1;
      final inst = await start(server, compression: true);
      inst.debugOverrideBehaviorSettings(timerIntervalSeconds: 1); // short backoff for the retry
      await sendBigEvents(inst);
      List<Received> eventRequests() => server.received.where((r) => r.body.containsKey('events')).toList();
      for (var i = 0; i < 100 && eventRequests().length < 2; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }

      final events = eventRequests();
      expect(events.map((r) => r.compressed).toList(), [true, false]);
      expect(events[1].body['events'], events[0].body['events']);
    });
  });
}
