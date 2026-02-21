import Flutter
import UIKit

public class SwiftCountlySdkDartPlugin: NSObject, FlutterPlugin {
  private static let channelName = "countly_sdk_dart_core/migration"
  private static let methodGet = "getLegacyData"
  private static let methodClear = "clearIOSLegacyData"

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    let instance = SwiftCountlySdkDartPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case Self.methodGet:
      result(readLegacyData())
    case Self.methodClear:
      clearLegacyData()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func readLegacyData() -> [String: Any?] {
    var ios: [String: Any?] = [:]
    let defaults = UserDefaults.standard
    ios["deviceId"] = defaults.string(forKey: Keys.deviceId)
    ios["nsuuid"] = defaults.string(forKey: Keys.nsuuid)
    ios["isCustomDeviceId"] = defaults.object(forKey: Keys.isCustomDeviceId) as? Bool
    ios["remoteConfig"] = defaults.dictionary(forKey: Keys.remoteConfig)
    ios["serverConfig"] = defaults.dictionary(forKey: Keys.serverConfig)
    ios["queuedRequests"] = readQueuedRequests()

    let hasData = ios.values.contains { value in
      if let str = value as? String { return !str.isEmpty }
      if let arr = value as? [Any] { return !arr.isEmpty }
      if let dict = value as? [AnyHashable: Any] { return !dict.isEmpty }
      return value != nil
    }

    return hasData ? ["ios": ios] : [:]
  }

  private func readQueuedRequests() -> [String]? {
    guard let url = persistencyURL else { return nil }
    guard let data = try? Data(contentsOf: url) else { return nil }
    do {
      if let unarchived = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [String: Any],
         let queued = unarchived[Keys.queuedRequestsPersistencyKey] as? [String] {
        return queued
      }
    } catch {
      return nil
    }
    return nil
  }

  private func clearLegacyData() {
    let defaults = UserDefaults.standard
    defaults.removeObject(forKey: Keys.deviceId)
    defaults.removeObject(forKey: Keys.nsuuid)
    defaults.removeObject(forKey: Keys.isCustomDeviceId)
    defaults.removeObject(forKey: Keys.remoteConfig)
    defaults.removeObject(forKey: Keys.serverConfig)

    if let url = persistencyURL {
      try? FileManager.default.removeItem(at: url)
    }
  }

  private var persistencyURL: URL? {
    guard var url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).last else {
      return nil
    }
#if targetEnvironment(macCatalyst)
    if let bundleId = Bundle.main.bundleIdentifier {
      url = url.appendingPathComponent(bundleId)
    }
#endif
    return url.appendingPathComponent(Keys.persistencyFileName)
  }

  private enum Keys {
    static let deviceId = "kCountlyStoredDeviceIDKey"
    static let nsuuid = "kCountlyStoredNSUUIDKey"
    static let isCustomDeviceId = "kCountlyIsCustomDeviceIDKey"
    static let remoteConfig = "kCountlyRemoteConfigKey"
    static let serverConfig = "kCountlyServerConfigPersistencyKey"
    static let queuedRequestsPersistencyKey = "kCountlyQueuedRequestsPersistencyKey"
    static let persistencyFileName = "Countly.dat"
  }
}
