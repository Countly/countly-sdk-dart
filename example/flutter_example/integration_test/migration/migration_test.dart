import 'dart:convert';

import 'package:countly_flutter_np/countly_config.dart';
import 'package:countly_flutter_np/countly_flutter.dart';
import 'package:countly_sdk_dart_core/countly.dart' as C;
import 'package:countly_sdk_dart_core/src/networking.dart' as N;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

class FakeResponseSuccess extends http.Response {
  FakeResponseSuccess({String body = '{"result":"Success"}', int status = 200}) : super(body, status);
}

class FakeNetworkClient extends N.NetworkClient {
  final List<Map<String, dynamic>> sent = [];
  final List<String> endpoints = [];
  FakeNetworkClient(String baseUrl) : super(baseUrl);

  @override
  Future<http.Response> makeRequest(Map<String, dynamic> data, String endPoint) async {
    sent.add(Map<String, dynamic>.from(data));
    endpoints.add(endPoint);
    if (data['method'] == 'sc') {
      return FakeResponseSuccess(body: '{"c":{}}');
    }
    return FakeResponseSuccess();
  }

  @override
  Future<http.Response> makeSelectiveRequest(Map<String, dynamic> data) async {
    sent.add(Map<String, dynamic>.from(data));
    endpoints.add('/i');
    return FakeResponseSuccess();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    await C.Countly.disposeAll();
  });

  testWidgets('Test SDK migrates data from flutter SDK', (WidgetTester tester) async {
    final oldConfig =
        CountlyConfig('https://old.com', 'old-app-key').setLoggingEnabled(true).setDeviceId('old-device-id');
    await Countly.initWithConfig(oldConfig);

    Countly.instance.userProfile.setProperty('specialProperty', 'value');
    Countly.instance.sessions.beginSession();
    Countly.recordEvent({'key': 'Old event', 'count': 1});

    final network = FakeNetworkClient('https://example.com');
    final cfg = C.CountlyConfig(
      appKey: 'app-key',
      serverUrl: 'https://example.com',
      networkClientOverride: network,
      deviceId: 'test-device',
      giveConsent: true,
      enableSDKLogs: true,
    );
    final sdk = await C.Countly.init(cfg);

    await sdk.processEventsAndRequests();

    expect(network.sent.length, greaterThanOrEqualTo(3));

    final first = network.sent[0];
    expect(first['begin_session'] == 1 || first['begin_session'] == '1', isTrue,
        reason: 'First request should be legacy begin_session request');
    expect(first['app_key'], 'old-app-key');
    expect(first['device_id'], 'old-device-id');
    expect(first['sdk_name'], 'dart-flutterbnp-android');
    expect(first['sdk_version'], '25.4.3');
    expect(first['av'], '0.0.1');

    final second = network.sent[1];
    expect(second['app_key'], 'old-app-key');
    final secondEvents = _decodeEvents(second['events']);
    expect(secondEvents.first['key'], '[CLY]_orientation');

    final third = network.sent[2];
    expect(third['app_key'], 'old-app-key');
    expect((third['user_details'] as Map)['custom']['specialProperty'], 'value');

    bool sawNewSdkRequest = false;
    bool sawMigratedOldEventUnderLegacyAppKey = false;
    for (final req in network.sent) {
      if (req['app_key'] == 'app-key') {
        sawNewSdkRequest = true;
        expect(req['device_id'], 'old-device-id');
        expect(req['sdk_name'], 'countly-sdk-dart-core');
        expect(req['sdk_version'], '26.1.0');
        expect(req['av'], '1.0.0');
      }

      final rawEvents = req['events'];
      if (rawEvents == null) continue;
      final events = _decodeEvents(rawEvents);
      final containsOldEvent = events.any((e) => e['key'] == 'Old event' && e['count'] == 1);
      if (containsOldEvent && req['app_key'] == 'old-app-key') {
        sawMigratedOldEventUnderLegacyAppKey = true;
      }
    }

    expect(sawNewSdkRequest, isTrue);
    expect(sawMigratedOldEventUnderLegacyAppKey, isTrue);
  });

  testWidgets('Migration does not re-populate legacy values on next core init', (WidgetTester tester) async {
    const markerEventKey = 'Old reinit marker event';
    final oldConfig =
        CountlyConfig('https://old.com', 'old-app-reinit').setLoggingEnabled(true).setDeviceId('old-device-reinit');
    await Countly.initWithConfig(oldConfig);

    Countly.instance.userProfile.setProperty('specialReinitProperty', 'value');
    Countly.instance.sessions.beginSession();
    Countly.recordEvent({'key': markerEventKey, 'count': 1});

    final firstNetwork = FakeNetworkClient('https://example.com');
    final firstCfg = C.CountlyConfig(
      appKey: 'new-app-first-init',
      serverUrl: 'https://example.com',
      networkClientOverride: firstNetwork,
      deviceId: 'new-device-first-init',
      giveConsent: true,
      enableSDKLogs: true,
    );
    final firstSdk = await C.Countly.init(firstCfg);
    await firstSdk.processEventsAndRequests();

    await C.Countly.disposeAll();

    final secondNetwork = FakeNetworkClient('https://example.com');
    final secondCfg = C.CountlyConfig(
      appKey: 'new-app-second-init',
      serverUrl: 'https://example.com',
      networkClientOverride: secondNetwork,
      deviceId: 'new-device-second-init',
      giveConsent: true,
      enableSDKLogs: true,
    );
    final secondSdk = await C.Countly.init(secondCfg);
    await secondSdk.processEventsAndRequests();

    bool secondRunContainsMarker = false;
    for (final req in secondNetwork.sent) {
      expect(req['device_id'], 'old-device-reinit');
      final rawEvents = req['events'];
      if (rawEvents == null) continue;
      final events = _decodeEvents(rawEvents);
      if (events.any((e) => e['key'] == markerEventKey)) {
        secondRunContainsMarker = true;
        break;
      }
    }

    expect(
      secondRunContainsMarker,
      isFalse,
      reason: 'Second init should not re-send migrated marker event',
    );
  });
}

List<Map<String, dynamic>> _decodeEvents(dynamic raw) {
  if (raw is String) {
    final decoded = json.decode(raw) as List<dynamic>;
    return decoded.cast<Map<String, dynamic>>();
  }
  return (raw as List).cast<Map<String, dynamic>>();
}
