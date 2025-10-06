part of sdk_instance_lib;

/// Named user properties for [UsersModule.setProperties].
class NamedUserProperty {
  static const name = 'name';
  static const username = 'username';
  static const email = 'email';
  static const organization = 'organization';
  static const phone = 'phone';
  static const picture = 'picture';
  static const gender = 'gender';
  static const byear = 'byear';
}

@internal
class UserData {
  static Map<String, dynamic> push(List<dynamic> values) => {'\$push': values};
  static Map<String, dynamic> addToSet(List<dynamic> values) => {'\$addToSet': values};
  static Map<String, dynamic> pull(List<dynamic> values) => {'\$pull': values};
}

class UsersModule {
  final CountlyInstance _inst;
  UsersModule(this._inst);

  /// Caches user properties. Merges with existing properties.
  /// Cache is flushed to request queue when an event is recorded or internal timer fires.
  void setProperties(Map<String, dynamic> props) {
    if (_inst._guardDisposed('users.setProperties')) return;
    _inst.L.d('Setting user properties: [${props.toString()}]');
    if (!_inst.hasConsentInternal(ConsentType.users)) {
      _inst.L.w('Attempt to set user properties without users consent');
      return;
    }
    if (_inst._sbs?.trackingEnabled == false) {
      _inst.L.d('Tracking disabled (SBS), skipping setting user properties');
      return;
    }
    _inst._ingestUserProperties(props);
    _inst.L.d(
        'User properties merged. Named=${_inst._userPropertiesNamedCache.keys.length} Custom=${_inst._customUserPropertiesCache.keys.length}');
    _inst._bundleEventQueue();

    final totalCachedSize = _inst._userPropertiesNamedCache.length + _inst._customUserPropertiesCache.length;
    final cacheLimit = _inst._sbs!.userPropertiesCacheLimit;

    if (totalCachedSize >= cacheLimit) {
      _inst.L.d('User properties cache limit reached [$totalCachedSize] >= [$cacheLimit], processing early');
      _inst._enqueueUserPropertiesCache();
    }
  }

  // Add values to a user property array
  void pushToArray(String key, List<dynamic> values) {
    setProperties({key: UserData.push(values)});
  }

  // Add values to a user property array only if they are not already present
  void addToSet(String key, List<dynamic> values) {
    setProperties({key: UserData.addToSet(values)});
  }

  // Remove values from a user property array
  void pullFromArray(String key, List<dynamic> values) {
    setProperties({key: UserData.pull(values)});
  }
}
