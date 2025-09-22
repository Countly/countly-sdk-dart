part of sdk_instance_lib;

class ConsentsModule {
  final SdkInstance _inst;
  ConsentsModule(this._inst);

  void give(Iterable<ConsentType> types) {
    if (_inst._guardDisposed('consents.give')) return;
    if (!_inst.config.requiresConsent) return;
    _inst._grantedConsents.addAll(types);
    _inst.L.i('Given consents: ${types.map((e) => e.name).join(', ')}');
  }

  void revoke(Iterable<ConsentType> types) {
    if (_inst._guardDisposed('consents.revoke')) return;
    if (!_inst.config.requiresConsent) return;
    for (final t in types) {
      _inst._grantedConsents.remove(t);
    }
    _inst.L.i('Revoked consents: ${types.map((e) => e.name).join(', ')}');
  }

  void giveAll() {
    if (_inst._guardDisposed('consents.giveAll')) return;
    if (!_inst.config.requiresConsent) return;
    _inst._grantedConsents.addAll(ConsentType.values);
    _inst.L.i('All consents granted');
  }

  void revokeAll() {
    if (_inst._guardDisposed('consents.revokeAll')) return;
    if (!_inst.config.requiresConsent) return;
    _inst._grantedConsents.clear();
    _inst.L.i('All consents revoked');
  }
}
