#import "CountlySdkDartPlugin.h"
#if __has_include(<countly_sdk_dart/countly_sdk_dart-Swift.h>)
#import <countly_sdk_dart/countly_sdk_dart-Swift.h>
#else
#import "countly_sdk_dart-Swift.h"
#endif

@implementation CountlySdkDartPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftCountlySdkDartPlugin registerWithRegistrar:registrar];
}
@end
