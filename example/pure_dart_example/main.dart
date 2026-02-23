// Run with: dart run example/pure_dart_example/main.dart
//
// This example demonstrates all SDK features for pure Dart environments
// (non-Flutter applications like CLI tools, servers, etc.)

import 'dart:async';
import 'package:countly_sdk_dart_core/countly_sdk_dart_core.dart';

Future<void> main() async {
  print('=== Countly Dart SDK - Pure Dart Example ===\n');

  // ----------------------------------------------------
  // 1. SDK Initialization
  // ----------------------------------------------------
  print('1. Initializing SDK...');

  final config = CountlyConfig(
    appKey: 'YOUR_APP_KEY',
    serverUrl: 'https://your.server.com',
    enableSDKLogs: true,
    logLevel: LogLevel.info,
    giveConsent: true,
    deviceMetricOverrides: {
      '_os': 'Pure Dart',
      '_os_version': '3.0.0',
      '_device': 'CLI',
    },
    userProperties: {
      'app_type': 'cli',
      'environment': 'development',
    },
    customRequestHeaders: {
      'X-Custom-Header': 'custom-value',
    },
  );

  final sdk = await Countly.init(config);
  print('SDK initialized with device ID: ${sdk.deviceId}\n');

  // ----------------------------------------------------
  // 2. Recording Events
  // ----------------------------------------------------
  print('2. Recording Events...');

  // Simple event
  await sdk.events.record(key: 'app_started');
  print('  - Recorded: app_started');

  // Event with count
  await sdk.events.record(key: 'item_viewed', count: 5);
  print('  - Recorded: item_viewed (count: 5)');

  // Event with sum
  await sdk.events.record(key: 'purchase', sum: 99.99);
  print('  - Recorded: purchase (sum: 99.99)');

  // Event with duration
  await sdk.events.record(key: 'task_completed', dur: 120.5);
  print('  - Recorded: task_completed (dur: 120.5)');

  // Event with string segmentation
  await sdk.events.record(
    key: 'button_clicked',
    segmentation: {
      'button_id': 'submit_btn',
      'screen': 'checkout',
      'color': 'blue',
    },
  );
  print('  - Recorded: button_clicked with string segmentation');

  // Event with number segmentation
  await sdk.events.record(
    key: 'game_level_completed',
    segmentation: {
      'level': 5,
      'score': 12500,
      'time_seconds': 180.5,
    },
  );
  print('  - Recorded: game_level_completed with number segmentation');

  // Event with boolean segmentation
  await sdk.events.record(
    key: 'feature_used',
    segmentation: {
      'is_premium': true,
      'is_first_time': false,
      'success': true,
    },
  );
  print('  - Recorded: feature_used with boolean segmentation');

  // Event with list segmentation
  await sdk.events.record(
    key: 'items_selected',
    segmentation: {
      'item_ids': ['SKU001', 'SKU002', 'SKU003'],
      'categories': ['electronics', 'accessories'],
      'quantities': [1, 2, 1],
    },
  );
  print('  - Recorded: items_selected with list segmentation');

  // Event with mixed segmentation
  await sdk.events.record(
    key: 'complex_action',
    count: 1,
    sum: 49.99,
    dur: 30.0,
    segmentation: {
      'action': 'checkout',
      'items_count': 3,
      'discount_applied': true,
      'discount_percent': 15.5,
      'product_ids': ['P001', 'P002'],
      'tags': ['sale', 'featured'],
    },
  );
  print('  - Recorded: complex_action with mixed segmentation\n');

  // ----------------------------------------------------
  // 3. Views
  // ----------------------------------------------------
  print('3. Tracking Views...');

  await sdk.views.startAutoStoppedView('MainMenu');
  print('  - Started view: MainMenu');
  await Future.delayed(const Duration(milliseconds: 100));

  await sdk.views.startAutoStoppedView('Settings');
  print('  - Started view: Settings (ended MainMenu)');
  await Future.delayed(const Duration(milliseconds: 100));

  await sdk.views.startAutoStoppedView('Profile');
  print('  - Started view: Profile (ended Settings)');

  await sdk.views.endActiveView();
  print('  - Ended active view: Profile\n');

  // ----------------------------------------------------
  // 4. User Profiles
  // ----------------------------------------------------
  print('4. Setting User Properties...');

  // Named properties
  await sdk.users.setProperties({
    NamedUserProperty.name: 'John Doe',
    NamedUserProperty.email: 'john@example.com',
    NamedUserProperty.username: 'johndoe',
    NamedUserProperty.phone: '+1234567890',
    NamedUserProperty.organization: 'Tech Corp',
    NamedUserProperty.gender: 'M',
    NamedUserProperty.byear: 1990,
  });
  print('  - Set named user properties');

  // Custom properties
  await sdk.users.setProperties({
    'tier': 'premium',
    'points': 1500,
    'verified': true,
    'subscription_date': '2024-01-15',
  });
  print('  - Set custom user properties');

  // Array operations
  await sdk.users.pushToArray('viewed_products', ['SKU001', 'SKU002', 'SKU003']);
  print('  - Pushed to viewed_products array');

  await sdk.users.addToSet('categories', ['electronics', 'books', 'clothing']);
  print('  - Added to categories set (unique values)');

  await sdk.users.pullFromArray('viewed_products', ['SKU001']);
  print('  - Pulled SKU001 from viewed_products\n');

  // ----------------------------------------------------
  // 5. Device ID Management
  // ----------------------------------------------------
  print('5. Device ID Management...');

  print('  - Current device ID: ${sdk.deviceId}');
  print('  - Device ID type: ${sdk.deviceIdType == 1 ? "Provided" : "Generated"}');

  // Change with merge (same user, new ID)
  await sdk.id.changeWithMerge('user_john_doe');
  print('  - Changed device ID with merge to: user_john_doe');

  // Process before changing without merge
  await sdk.processEventsAndRequests();

  // Change without merge (new user)
  await sdk.id.changeWithoutMerge('new_anonymous_user');
  print('  - Changed device ID without merge to: new_anonymous_user');

  // Must give consent after change without merge
  await sdk.consents.giveConsent();
  print('  - Gave consent after device ID change\n');

  // ----------------------------------------------------
  // 6. Consent Management
  // ----------------------------------------------------
  print('6. Consent Management...');

  // Consent is already given, let's demonstrate the flow
  print('  - Consent is currently: granted');

  // Record something while consent is given
  await sdk.events.record(key: 'consent_test_event');
  print('  - Recorded event with consent');

  // Revoke consent
  await sdk.consents.revokeConsent();
  print('  - Revoked consent (data cleared)');

  // Try to record (will be dropped)
  await sdk.events.record(key: 'should_not_record');
  print('  - Attempted event without consent (dropped)');

  // Give consent again
  await sdk.consents.giveConsent();
  print('  - Gave consent again\n');

  // ----------------------------------------------------
  // 7. Multi-Instance Support
  // ----------------------------------------------------
  print('7. Multi-Instance Support...');

  final secondaryConfig = CountlyConfig(
    appKey: 'SECONDARY_APP_KEY',
    serverUrl: 'https://secondary.server.com',
    giveConsent: true,
  );

  final secondary = await Countly.init(secondaryConfig, instanceKey: 'secondary');
  print('  - Created secondary instance with key: secondary');
  print('  - Secondary device ID: ${secondary.deviceId}');

  await secondary.events.record(key: 'secondary_event');
  print('  - Recorded event on secondary instance');

  // Access instances
  final defaultInst = Countly.defaultInstance;
  final secondaryInst = Countly.instance('secondary');
  print('  - Default instance: ${defaultInst?.deviceId}');
  print('  - Secondary instance: ${secondaryInst?.deviceId}\n');

  // ----------------------------------------------------
  // 8. Device Metrics
  // ----------------------------------------------------
  print('8. Recording Device Metrics...');

  await sdk.events.recordMetrics();
  print('  - Recorded default metrics');

  await sdk.events.recordMetrics(
    metricOverride: {
      '_app_version': '2.0.0',
      'custom_metric': 'value',
      'memory_usage': 256,
    },
  );
  print('  - Recorded metrics with overrides\n');

  // ----------------------------------------------------
  // 9. Processing Queue
  // ----------------------------------------------------
  print('9. Processing Queue...');

  await sdk.processEventsAndRequests();
  print('  - Processed events and requests queue\n');

  // ----------------------------------------------------
  // 10. Cleanup
  // ----------------------------------------------------
  print('10. Cleanup...');

  // Dispose secondary instance
  await Countly.disposeInstance('secondary');
  print('  - Disposed secondary instance');

  // Dispose all instances
  await Countly.disposeAll();
  print('  - Disposed all instances\n');

  print('=== Example Complete ===');
}
