// Run with: dart run example/pure_dart_example/main.dart

import 'dart:async';
import 'package:countly_sdk_dart/countly.dart';

final config = CountlyConfig(
  appKey: 'YOUR_APP_KEY',
  serverUrl: 'https://sth.com',
  storageMode: StorageMode.memory,
  enableSDKLogs: true,
  logLevel: LogLevel.debug,
  deviceMetricOverrides: {
    'platform': 'pure_dart',
    '_os_version': '1.0.0',
  },
);

final config2 = CountlyConfig(
  appKey: 'YOUR_APP_KEY',
  serverUrl: 'https://sth.com',
  storageMode: StorageMode.memory,
  enableSDKLogs: true,
);

Future<void> main() async {
  final sdk = await Countly.init(config);

  await sdk.consents.giveConsent();
  await sdk.events.recordMetrics();
  sdk.views.startAutoStoppedView("home");

  final sdk_2 = await Countly.init(config2, instanceKey: 'secondary');
  sdk_2.events.record(key: 'instance_2_event');
  sdk_2.views.startAutoStoppedView("home");

  await sdk.events.record(key: 'session_start');
  await Future<void>.delayed(const Duration(seconds: 5));

  List<String> customSeg = ['a', 'b', 'c'];
  await sdk.events.record(key: 'button_click', segmentation: {'id': 'start', 'color': 'blue', 'custom': customSeg});
  await sdk.events.record(key: 'd', segmentation: {'id': 'start', 'color': 'blue', 'custom': customSeg});
  sdk.users.pushToArray("a", ['1', 2, 3.0, true]);
  sdk.users.setProperties({"a": '1', "b": 2, "c": 3.0, "d": true, "e": null});
  sdk.users.setProperties({NamedUserProperty.name: 'Alice'});
  await sdk.processEventsAndRequests();

  await Future<void>.delayed(const Duration(seconds: 2));

  await Countly.disposeAll();
}
