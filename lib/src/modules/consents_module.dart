part of sdk_instance_lib;

class ConsentsModule {
  final CountlyInstance _inst;
  ConsentsModule(this._inst);

  void giveConsent() {
    if (_inst._guardDisposed('consents.giveConsent')) return;
    _inst._consentGranted = true;
    _inst.L.i('Consents granted');
    _inst._recordConsentRequest();
  }

  void revokeConsent() {
    if (_inst._guardDisposed('consents.revokeConsent')) return;
    _inst._consentGranted = false;
    _inst.L.i('Consents revoked');
    _inst._recordConsentRequest();
  }
}
