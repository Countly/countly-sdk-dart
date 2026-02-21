import 'dart:convert';
import 'dart:io';

import 'package:countly_sdk_dart_core/countly.dart' as C;
import 'package:countly_flutter_np/countly_config.dart';
import 'package:countly_flutter_np/countly_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:countly_sdk_dart_core/src/networking.dart' as N;
import '../../../../test/helper/helper.dart' as helper;
import 'package:http/http.dart' as http;

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
  testWidgets('Test SDK migrates data from flutter SDK', (WidgetTester tester) async {
    CountlyConfig config =
        CountlyConfig('https://old.com', 'old-app-key').setLoggingEnabled(true).setDeviceId('old-device-id');
    await Countly.initWithConfig(config);
    var event = {'key': 'Old event', 'count': 1};
    Countly.recordEvent(event);

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
    for (var req in network.sent) {
      print(req);
      expect(req['app_key'], 'app-key');
      expect(req['device_id'], 'old-device-id'); // migrated device ID should be used
      expect(req['sdk_name'], 'countly-sdk-dart');
      expect(req['sdk_version'], '1.0.0');
      expect(req['av'], '1.0.0');
      if (req['events'] != null) {
        final raw = req['events'];
        List<Map<String, dynamic>> events;
        if (raw is String) {
          final decoded = json.decode(raw) as List<dynamic>;
          events = decoded.cast<Map<String, dynamic>>();
        } else {
          events = (raw as List).cast<Map<String, dynamic>>();
        }
        expect(events.length, 2);
        expect(events[0]['key'], '[CLY]_orientation');
        expect(events[1]['key'], 'Old event');
        expect(events[1]['count'], 1);
      }
    }
  });
}
