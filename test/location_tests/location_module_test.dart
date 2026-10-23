import 'package:countly_sdk_dart_core/countly_sdk_dart_core.dart';
import 'package:countly_sdk_dart_core/src/networking.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../helper/helper.dart' as helper;

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
    if (data['method'] == 'sc') {
      return FakeResponseSuccess(body: '{"c":{}}');
    }
    return FakeResponseSuccess();
  }

  @override
  Future<http.Response> makeSelectiveRequest(Map<String, dynamic> data) async {
    sent.add({...data});
    return FakeResponseSuccess();
  }
}

Future<CountlyInstance> _createInstance({
  bool giveConsent = true,
  bool startWithUnknownConsent = false,
  TestLogger? logger,
  FakeNetworkClient? networkClient,
  Map<String, dynamic>? sbs,
}) async {
  final log = logger ?? TestLogger();
  final client = networkClient ?? FakeNetworkClient('https://example.com');
  final cfg = CountlyConfig(
    appKey: 'app-key',
    serverUrl: 'https://example.com',
    deviceId: 'test-device',
    storageMode: StorageMode.memory,
    startWithUnknownConsent: startWithUnknownConsent,
    giveConsent: giveConsent,
    enableSDKLogs: true,
    logLevel: LogLevel.verbose,
    logger: log,
    networkClientOverride: client,
    sbs: sbs ?? {},
  );
  final inst = await Countly.init(cfg);
  addTearDown(() async {
    await Countly.disposeAll();
  });
  return inst;
}

/// Returns the queued request expected for [location]: the common request fields plus the given location values.
Map<String, dynamic> _expectedLocationRequest(Map<String, dynamic> location) {
  final expected = Map<String, dynamic>.from(helper.locationRequest)..remove('location');
  expected.addAll(location);
  return expected;
}

void main() {
  group('Location Module - setLocation', () {
    test('queues a request with all location values', () async {
      final sdk = await _createInstance();
      final initialRQLength = sdk.debugRequestQueueLength;

      await sdk.location.setLocation(
        countryCode: 'TR',
        city: 'Istanbul',
        gpsCoordinates: '41.0082,28.9784',
        ipAddress: '192.168.88.33',
      );

      expect(sdk.debugRequestQueueLength, initialRQLength + 1);
      expect(
          sdk.debugRequestQueueSnapshot.last,
          equals(_expectedLocationRequest({
            'location': '41.0082,28.9784',
            'city': 'Istanbul',
            'country_code': 'TR',
            'ip_address': '192.168.88.33',
          })));
    });

    test('sends only the values that are set', () async {
      final sdk = await _createInstance();

      await sdk.location.setLocation(gpsCoordinates: '56.42345,123.45325', city: '', ipAddress: null);

      expect(sdk.debugRequestQueueSnapshot.last, equals(_expectedLocationRequest({'location': '56.42345,123.45325'})));
    });

    test('drops the call when no value is set', () async {
      final logger = TestLogger();
      final sdk = await _createInstance(logger: logger);
      final initialRQLength = sdk.debugRequestQueueLength;

      await sdk.location.setLocation();
      await sdk.location.setLocation(countryCode: '', city: '', gpsCoordinates: '', ipAddress: '');

      expect(sdk.debugRequestQueueLength, initialRQLength);
      expect(logger.logs.where((log) => log.contains('without any location value')).length, 2);
    });

    test('warns but still sends a city without a country code', () async {
      final logger = TestLogger();
      final sdk = await _createInstance(logger: logger);

      await sdk.location.setLocation(city: 'Istanbul');

      expect(sdk.debugRequestQueueSnapshot.last, equals(_expectedLocationRequest({'city': 'Istanbul'})));
      expect(logger.logs.any((log) => log.contains('both city and country code need to be set')), true);
    });

    test('does not warn when city and country code are set together', () async {
      final logger = TestLogger();
      final sdk = await _createInstance(logger: logger);

      await sdk.location.setLocation(countryCode: 'TR', city: 'Istanbul');

      expect(logger.logs.any((log) => log.contains('both city and country code need to be set')), false);
    });

    test('is ignored without consent', () async {
      final logger = TestLogger();
      final sdk = await _createInstance(giveConsent: false, logger: logger);
      final initialRQLength = sdk.debugRequestQueueLength;

      await sdk.location.setLocation(countryCode: 'TR', city: 'Istanbul');

      expect(sdk.debugRequestQueueLength, initialRQLength);
      expect(logger.logs.any((log) => log.contains('Attempt to set location without consent')), true);
    });

    test('is ignored when location tracking is disabled via SBS', () async {
      final logger = TestLogger();
      final sdk = await _createInstance(
        logger: logger,
        sbs: {
          'c': {'lt': false}
        },
      );
      final initialRQLength = sdk.debugRequestQueueLength;

      await sdk.location.setLocation(countryCode: 'TR', city: 'Istanbul');

      expect(sdk.debugRequestQueueLength, initialRQLength);
      expect(logger.logs.any((log) => log.contains('Location tracking disabled (SBS)')), true);
    });

    test('is ignored after the instance is disposed', () async {
      final sdk = await _createInstance();
      await sdk.dispose();
      final initialRQLength = sdk.debugRequestQueueLength;

      await sdk.location.setLocation(countryCode: 'TR', city: 'Istanbul');

      expect(sdk.debugRequestQueueLength, initialRQLength);
    });

    test('is sent to the server after the init-time empty location', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.location.setLocation(countryCode: 'TR', city: 'Istanbul');
      await sdk.processEventsAndRequests();

      final locationRequests = network.sent.where((r) => r.containsKey('location') || r.containsKey('city')).toList();
      expect(locationRequests.length, 2);
      expect(locationRequests[0]['location'], '');
      expect(locationRequests[1]['city'], 'Istanbul');
      expect(locationRequests[1]['country_code'], 'TR');
      expect(locationRequests[1].containsKey('location'), false);
      expect(sdk.debugRequestQueueLength, 0);
    });

    test('is held in unknown consent state and sent once consent is given', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(giveConsent: false, startWithUnknownConsent: true, networkClient: network);

      await sdk.location.setLocation(countryCode: 'TR', city: 'Istanbul');
      expect(sdk.debugRequestQueueSnapshot.any((r) => r['city'] == 'Istanbul'), true);
      expect(network.sent.any((r) => r['city'] == 'Istanbul'), false);

      await sdk.consents.giveConsent();

      expect(network.sent.any((r) => r['city'] == 'Istanbul' && r['country_code'] == 'TR'), true);
    });

    test('is dropped when consent is denied from unknown consent state', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(giveConsent: false, startWithUnknownConsent: true, networkClient: network);

      await sdk.location.setLocation(countryCode: 'TR', city: 'Istanbul');
      await sdk.consents.revokeConsent();
      await sdk.processEventsAndRequests();

      expect(network.sent.any((r) => r['city'] == 'Istanbul'), false);
    });
  });
}
