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

For an example integration of this SDK, you can have a look [here](https://github.com/Countly/countly-sdk-).

This SDK supports the following features:

* [Analytics](https://support.count.ly/hc/en-us/articles/4431589003545-Analytics)
* [User Profiles](https://support.count.ly/hc/en-us/articles/4403281285913-User-Profiles)

## Installation

In the `dependencies:` section of your `pubspec.yaml`, add the following line:

```yaml
dependencies:
  countly_sdk_dart: <latest_version>
```

## Usage

```dart
import 'package:countly_sdk_dart/countly.dart';

void main() {
  runApp(MaterialApp(home: const MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        deviceId: 'your-device-ID',
        giveConsent: true,
        enableSDKLogs: true,
    );
    final sdk = await Countly.init(cfg);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Countly Example App')),
      body: Center(
        child: TextButton(
          onPressed: () {
            // record an event
            await sdk.events.record(key: 'Custom Event', count: 3, segmentation: {'key': 'value'});
          },
          child: Text('Record Event'),
        ),
      ),
    );
  }
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
