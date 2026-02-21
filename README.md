# Countly Dart SDK - Core

This repository contains the Countly Dart SDK, which can be integrated into mobile Flutter applications and any platform Dart can run. The Countly Dart SDK is intended to be used with [Countly Lite](https://countly.com/lite), [Countly Flex](https://countly.com/flex), [Countly Enterprise](https://countly.com/enterprise).

## What is Countly?

[Countly](https://countly.com) is a product analytics solution and innovation enabler that helps teams track product performance and customer journey and behavior across [mobile](https://countly.com/mobile-analytics), [web](https://countly.com/web-analytics),
and [desktop](https://countly.com/desktop-analytics) applications. [Ensuring privacy by design](https://countly.com/privacy-by-design), Countly allows you to innovate and enhance your products to provide personalized and customized customer experiences, and meet key business and revenue goals.

Track, measure, and take action - all without leaving Countly.

* **Questions or feature requests?** [Join the Countly Community on Discord](https://discord.gg/countly)
* **Looking for the Countly Server?** [Countly Server repository](https://github.com/Countly/countly-server)
* **Looking for other Countly SDKs?** [An overview of all Countly SDKs for mobile, web and desktop](https://support.count.ly/hc/en-us/articles/360037236571-Downloading-and-Installing-SDKs#h_01H9QCP8G5Y9PZJGERZ4XWYDY9)

## Integrating Countly SDK in your projects

For a detailed description on how to use this SDK [check out our documentation](https://support.count.ly/hc/en-us/articles/).

For information about how to add the SDK to your project, please check [this section of the documentation](https://support.count.ly/hc/en-us/articles/).

You can find minimal SDK integration information for your project in [this section of the documentation](https://support.count.ly/hc/en-us/articles/).

For an example integration of this SDK, you can have a look [here](https://github.com/Countly/countly-sdk-dart/tree/main/example).

This SDK supports the following features:

* [Analytics](https://support.count.ly/hc/en-us/articles/4431589003545-Analytics)
* [User Profiles](https://support.count.ly/hc/en-us/articles/4403281285913-User-Profiles)
* [Views](https://support.count.ly/hc/en-us/articles/)

## Installation

In the `dependencies:` section of your `pubspec.yaml`, add the following line:

```yaml
dependencies:
  countly_sdk_dart_core: <latest_version>
```

## Usage

### Initialization

```dart
import 'package:countly_sdk_dart_core/countly.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final config = CountlyConfig(
    appKey: 'YOUR_APP_KEY',
    serverUrl: 'https://your.server.com',
    giveConsent: true,
    enableSDKLogs: true, // Disable in production
  );
  
  final sdk = await Countly.init(config);
  runApp(const MyApp());
}
```

### Configuration Options

```dart
final config = CountlyConfig(
  appKey: 'YOUR_APP_KEY',           // Required: Your Countly app key
  serverUrl: 'https://server.com',   // Required: Your Countly server URL
  deviceId: 'custom-device-id',      // Optional: Custom device ID
  giveConsent: true,                 // Optional: Grant consent at init
  startWithUnknownConsent: false,    // Optional: Start with unknown consent
  enableSDKLogs: true,               // Optional: Enable logging
  logLevel: LogLevel.verbose,        // Optional: Log verbosity
  enableVisualWarnings: false,       // Optional: Show toast warnings
  customRequestHeaders: {            // Optional: Custom HTTP headers
    'X-Custom-Header': 'value',
  },
  deviceMetricOverrides: {           // Optional: Override device metrics
    '_os_version': '14.0',
  },
  userProperties: {                  // Optional: Initial user properties
    'name': 'John Doe',
    'tier': 'premium',
  },
  storageMode: StorageMode.persistent, // Optional: Storage mode
  disableOldDataMigration: false,    // Optional: Disable legacy migration
);
```

### Recording Events

```dart
final sdk = Countly.defaultInstance!;

// Record a simple event
await sdk.events.record(key: 'button_click');

// Record event with count
await sdk.events.record(key: 'item_purchased', count: 3);

// Record event with sum (e.g., revenue)
await sdk.events.record(key: 'purchase', sum: 29.99);

// Record event with duration
await sdk.events.record(key: 'video_watched', dur: 120.5);

// Record event with all parameters
await sdk.events.record(
  key: 'purchase',
  count: 1,
  sum: 99.99,
  dur: 5.0,
  segmentation: {
    'product_id': 'SKU123',
    'category': 'electronics',
    'tags': ['featured', 'sale'],
  },
);
```

### Recording Views

```dart
final sdk = Countly.defaultInstance!;

// Start an auto-stopped view (automatically ends when another view starts)
await sdk.views.startAutoStoppedView('HomePage');

// Navigate to another view (automatically ends HomePage)
await sdk.views.startAutoStoppedView('ProductPage');

// Manually end the current view
await sdk.views.endActiveView();
```

### User Profiles

```dart
final sdk = Countly.defaultInstance!;

// Set named user properties
await sdk.users.setProperties({
  'name': 'John Doe',
  'email': 'john@example.com',
  'username': 'johndoe',
  'phone': '+1234567890',
  'gender': 'M',
  'byear': 1990,
});

// Set custom user properties
await sdk.users.setProperties({
  'tier': 'premium',
  'points': 500,
  'preferences': ['news', 'sports'],
});

// Add values to array property (allows duplicates)
await sdk.users.pushToArray('viewed_products', ['SKU123', 'SKU456']);

// Add unique values to array property
await sdk.users.addToSet('categories', ['electronics', 'books']);

// Remove values from array property
await sdk.users.pullFromArray('interests', ['outdated']);
```

### Consent Management

```dart
final sdk = Countly.defaultInstance!;

// Grant consent
await sdk.consents.giveConsent();

// Revoke consent (clears all data)
await sdk.consents.revokeConsent();
```

### Device ID Management

```dart
final sdk = Countly.defaultInstance!;

// Get current device ID
final deviceId = sdk.deviceId;

// Change device ID with merge (same user, new ID)
await sdk.id.changeWithMerge('user_123456');

// Change device ID without merge (new user)
await sdk.id.changeWithoutMerge('new_anonymous_id');
await sdk.consents.giveConsent(); // Required after change without merge
```

### Multi-Instance Support

```dart
// Initialize default instance
final primary = await Countly.init(config);

// Initialize secondary instance
final secondary = await Countly.init(config2, instanceKey: 'secondary');

// Access instances
final primary = Countly.defaultInstance;
final secondary = Countly.instance('secondary');

// Dispose specific instance
await Countly.disposeInstance('secondary');

// Dispose all instances
await Countly.disposeAll();
```

### Custom Logger

```dart
class MyLogger implements SdkLogger {
  @override
  bool isEnabled(LogLevel level) => level.index <= LogLevel.info.index;
  
  @override
  void log(LogLevel level, String message, {Object? error, StackTrace? stack}) {
    // Your custom logging implementation
    print('[${level.name}] $message');
  }
}

final config = CountlyConfig(
  appKey: 'YOUR_APP_KEY',
  serverUrl: 'https://your.server.com',
  logger: MyLogger(),
  enableSDKLogs: true,
);
```

### Pure Dart Usage (Non-Flutter)

```dart
import 'package:countly_sdk_dart_core/countly.dart';

void main() async {
  final config = CountlyConfig(
    appKey: 'YOUR_APP_KEY',
    serverUrl: 'https://your.server.com',
    storageMode: StorageMode.memory, // Use memory storage for pure Dart
    deviceMetricOverrides: {
      '_os': 'Custom OS',
      '_os_version': '1.0.0',
    },
  );
  
  final sdk = await Countly.init(config);
  await sdk.consents.giveConsent();
  
  await sdk.events.record(key: 'app_start');
  await sdk.views.startAutoStoppedView('main');
  
  // Process and send data
  await sdk.processEventsAndRequests();
  
  await Countly.disposeAll();
}
```

## Security

Security is very important to us. If you discover any issue regarding security, please disclose the information responsibly by sending an email to <security@countly.com> and **not by creating a GitHub issue**.

## Badges

If you like Countly, [why not use one of our badges](https://countly.com/brand-assets) and give a link back to us so others know about this wonderful platform?

<a href="https://count.ly/f/badge" rel="nofollow"><img style="width:145px;height:60px" src="https://countly.com/badges/dark.svg?v2" alt="Countly - Product Analytics" /></a>

```JS
<a href="https://count.ly/f/badge" rel="nofollow"><img style="width:145px;height:60px" src="https://countly.com/badges/dark.svg" alt="Countly - Product Analytics" /></a>
```

<a href="https://count.ly/f/badge" rel="nofollow"><img style="width:145px;height:60px" src="https://countly.com/badges/light.svg?v2" alt="Countly - Product Analytics" /></a>

```JS
<a href="https://count.ly/f/badge" rel="nofollow"><img style="width:145px;height:60px" src="https://countly.com/badges/light.svg" alt="Countly - Product Analytics" /></a>
```

## How can I help you with your efforts?

Glad you asked! For community support, feature requests, and engaging with the Countly Community, please join us at [our Discord Server](https://discord.gg/countly). We're excited to have you there!

Also, we are on [Twitter](https://twitter.com/gocountly) and [LinkedIn](https://www.linkedin.com/company/countly) if you would like to keep up with Countly related updates.
