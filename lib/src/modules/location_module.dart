part of '../main.dart';

class LocationModule {
  final CountlyInstance _inst;
  LocationModule(this._inst);

  /// Sends the user's location to the server as a separate request.
  /// All parameters are optional, but at least one has to be set. Empty values are not sent.
  /// The [countryCode] is the ISO country code of the user's country and [city] is the name of the user's city.
  /// Set [countryCode] and [city] together.
  /// The [gpsCoordinates] are comma separated latitude and longitude values, for example "56.42345,123.45325".
  /// The [ipAddress] is the user's IP address, for example "192.168.88.33".
  Future<void> setLocation({String? countryCode, String? city, String? gpsCoordinates, String? ipAddress}) async {
    if (_inst._guardDisposed('location.setLocation')) return;
    _inst.L.d('Setting location: countryCode=[$countryCode] city=[$city] gps=[$gpsCoordinates] ip=[$ipAddress]');
    if (!_inst.hasConsentInternal()) {
      _inst.L.w('Attempt to set location without consent');
      return;
    }
    if (_inst._sbs?.isLocationTrackingAllowed == false) {
      _inst.L.d('Location tracking disabled (SBS), skipping setting location');
      return;
    }
    final location = <String, dynamic>{
      if (gpsCoordinates != null && gpsCoordinates.isNotEmpty) 'location': gpsCoordinates,
      if (city != null && city.isNotEmpty) 'city': city,
      if (countryCode != null && countryCode.isNotEmpty) 'country_code': countryCode,
      if (ipAddress != null && ipAddress.isNotEmpty) 'ip_address': ipAddress,
    };
    if (location.isEmpty) {
      _inst.L.w('location.setLocation called without any location value, skipping');
      return;
    }
    if (location.containsKey('city') != location.containsKey('country_code')) {
      _inst.L.w('In "setLocation" both city and country code need to be set at the same time to be sent');
    }
    final req = _inst._prepareRequest(location);
    if (req == null) return;
    await _inst._addToRequestQueue(req);
    _inst.L.d('Recorded location request: [${location.toString()}]');
  }
}
