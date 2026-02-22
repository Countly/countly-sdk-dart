#import "CountlySdkDartPlugin.h"
#if __has_include(<countly_sdk_dart_core/countly_sdk_dart_core-Swift.h>)
#import <countly_sdk_dart_core/countly_sdk_dart_core-Swift.h>
#else
#import "countly_sdk_dart_core-Swift.h"
#endif

@implementation CountlySdkDartPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftCountlySdkDartPlugin registerWithRegistrar:registrar];
}
@end
