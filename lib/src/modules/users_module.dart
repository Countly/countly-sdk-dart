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
    _inst._userPropertiesCache.addAll(props);
    _inst.L.d('User properties merged. Merged cache: ${_inst._userPropertiesCache.toString()}');
    _inst._bundleEventQueue();
  }
}
