// Run with: dart run example/pure_dart_example/main.dart

import 'dart:async';
import 'package:sdk_dart/sdk_dart.dart';

Future<void> main() async {
  final config = SdkConfig(
    appKey: 'YOUR_APP_KEY',
    serverUrl: 'https://sth.com',
    storageMode: StorageMode.memory,
    enableSDKLogs: true,
    logLevel: LogLevel.verbose,
    requiresConsent: true,
    setConsentEnabled: const [
      ConsentType.events,
      ConsentType.users,
      ConsentType.metrics,
      ConsentType.views,
    ],
  );
  final config2 = SdkConfig(
    appKey: 'YOUR_APP_KEY',
    serverUrl: 'https://sth.com',
    storageMode: StorageMode.memory,
    enableSDKLogs: true,
    logLevel: LogLevel.verbose,
  );

  final sdk = await Sdk.init(config);

  sdk.consents.give([ConsentType.remoteConfig]);
  sdk.events.recordMetrics();
  sdk.views.startAutoStoppedView("home");

  final sdk_2 = await Sdk.init(config2, instanceKey: 'secondary');
  sdk_2.events.record(key: 'instance_2_event');
  sdk_2.views.startAutoStoppedView("home");

  sdk.events.record(key: 'session_start');
  sdk.events.record(key: 'button_click', segmentation: {'id': 'start', 'color': 'blue'});
  final fetched = await sdk.remoteConfig.fetch();
  print('Remote config fetch success: $fetched');

  await sdk.users.setProperties({'name': 'Alice', 'plan': 'pro'});
  await sdk.processEventsAndRequests();

  await Future<void>.delayed(const Duration(seconds: 2));

  await Sdk.disposeAll();
}
