part of sdk_instance_lib;

class ConsentsModule {
  final CountlyInstance _inst;
  ConsentsModule(this._inst);

  void giveConsent() {
    if (_inst._guardDisposed('consents.giveConsent')) return;
    final wasInUnknownState = _inst._isInUnknownConsentState;
    if (_inst._consentGranted == true && !wasInUnknownState) {
      _inst.L.i('Consents already granted, skipping.');
      return;
    }
    _inst._consentGranted = true;
    _inst.L.i('Consents granted');
    // Only record consent if not in unknown state (unknown state handles its own recording)
    _inst._getOutOfUnknownConsentState(true);
    if (!wasInUnknownState) {
      _inst._recordConsentRequest();
      _inst.events.recordMetrics(metricOverride: _inst.deviceMetrics);
    }
  }

  void revokeConsent() {
    if (_inst._guardDisposed('consents.revokeConsent')) return;
    if (_inst._consentGranted == false) {
      _inst.L.i('Consents already revoked, skipping.');
      return;
    }
    _inst._consentGranted = false;
    _inst.L.i('Consents revoked');
    // Only record consent if not in unknown state (unknown state handles its own recording)
    final wasInUnknownState = _inst._isInUnknownConsentState;
    _inst._getOutOfUnknownConsentState(false);
    if (!wasInUnknownState) {
      _inst._recordConsentRequest();
    }
  }
}
