import 'package:flutter/material.dart';
import 'package:sdk_dart/sdk_dart.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = SdkConfig(
    appKey: 'YOUR_APP_KEY',
    serverUrl: 'https://sth.com',
    storageMode: StorageMode.persistent,
    enableSDKLogs: true,
    logLevel: LogLevel.debug,
    turnOnRemoteConfig: true,
    requiresConsent: true,
    giveAllConsents: true,
    userProperties: const {'platform': 'flutter', 'build': '1.0.0'},
  );
  await Sdk.init(config);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int counter = 0;

  void _increment() {
    counter++;
    final inst = Sdk.defaultInstance!;
    inst.events.record(key: 'counter_increment', segmentation: {'value': counter});
    inst.users.setProperties({'last_counter': counter});
    setState(() {});
  }

  Future<void> _refreshRemoteConfig() async {
    final inst = Sdk.defaultInstance!;
    final ok = await inst.remoteConfig.fetch();
    debugPrint('Remote config fetch success: $ok');
  }

  @override
  void dispose() {
    Sdk.disposeAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('sdk_dart Example')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Counter: $counter'),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _increment, child: const Text('Record Event & Increment')),
              const SizedBox(height: 8),
              ElevatedButton(onPressed: _refreshRemoteConfig, child: const Text('Fetch Remote Config')),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  final inst = Sdk.defaultInstance!;
                  await inst.processEventsAndRequests();
                },
                child: const Text('Force Flush Now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
