import 'dart:convert';
import 'package:http/http.dart' as http;
import 'logging/logging_helper.dart';
import 'constants.dart';

class NetworkClient {
  final String baseUrl;
  final http.Client _client;
  final InstanceLogger? L;
  final int requestTimeout;
  final Map<String, String>? customHeaders;

  NetworkClient(this.baseUrl, {http.Client? client, this.L, int? requestTimeout, this.customHeaders})
      : _client = client ?? http.Client(),
        requestTimeout = requestTimeout ?? SdkInternal.requestTimeoutSeconds;

  /// makes a generic request to the specified endpoint.
  Future<http.Response> makeRequest(Map<String, dynamic> data, String endPoint) async {
    final f = _post('$baseUrl$endPoint', data);
    return f.timeout(Duration(seconds: requestTimeout));
  }

  /// Chooses endpoint automatically based on the 'method' field inside [data].
  /// Falls back to events endpoint if not matched.
  Future<http.Response> makeSelectiveRequest(Map<String, dynamic> data) async {
    L?.i('Make selective request with data: ${data.toString()}');
    final method = data['method'];
    const sdkMethods = {'ab'}; // Currently only 'ab' needs a different endpoint.
    final endpoint = (method != null && sdkMethods.contains(method)) ? Endpoints.sdk : Endpoints.i;
    return makeRequest(data, endpoint);
  }

  Future<http.Response> _post(String url, Map<String, dynamic> data) async {
    L?.i('POST [$url] with data[${data.toString()}]');
    final base = <String, String>{'Content-Type': 'application/json', 'Accept': 'application/json'};
    if (customHeaders != null) {
      base.addAll(customHeaders!);
    }
    return _client.post(Uri.parse(url), headers: base, body: jsonEncode(data));
  }

  /// Validates response: status 200-299 and JSON body with "result":"Success" or any JSON if acceptJSON is true.
  bool isResponseValid(http.Response resp, {bool acceptJSON = false}) {
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      L?.w('Invalid response: status=${resp.statusCode}, body=${resp.body}');
      return false;
    }

    try {
      final decoded = jsonDecode(resp.body);

      if (decoded is Map<String, dynamic>) {
        if (decoded['result'] == 'Success') {
          L?.d('Response JSON map accepted as success');
          return true;
        } else if (acceptJSON) {
          L?.d('Response JSON map accepted as success (no result check)');
          return true;
        }
      } else if (decoded is List<dynamic> && acceptJSON) {
        L?.d('Response JSON list accepted as success');
        return true; // Accept any JSON list.
      }
      L?.w('Response JSON not accepted: [$decoded]');
      return false;
    } catch (_) {
      L?.w('Non-JSON body with 200 status, not accepted');
      return false;
    }
  }

  void close() => _client.close();
}
