import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'logging/logging_helper.dart';
import 'constants.dart';
import 'gzip/gzip_codec.dart';

class NetworkClient {
  String baseUrl;
  final http.Client _client;
  final InstanceLogger? L;
  final int requestTimeout;
  final Map<String, String>? customHeaders;

  /// Whether request bodies are sent gzip-compressed once the server's SDK behavior settings answer says it reads
  /// them; set from the config at init.
  @internal
  bool requestCompressionEnabled = false;
  String? _gzipAcceptingUrl;
  bool _requestCompressionBlocked = false;

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
    final body = jsonEncode(data);
    // the wait for the compressor happens only for a body that is compressed, a plain request leaves right away
    final plain = _compressibleBody(body, url);
    if (plain != null) {
      final compressed = await gzipBytes(plain);
      if (compressed != null && compressed.length < plain.length) {
        L?.d('The request body is sent gzip-compressed, [${plain.length}] -> [${compressed.length}] bytes');
        return _client.post(Uri.parse('$url?${RequestCompression.urlMarker}'), headers: base, body: compressed);
      }
    }
    return _client.post(Uri.parse(url), headers: base, body: body);
  }

  /// Returns the body as bytes when it may be sent gzip-compressed: request compression is on, the current server
  /// said in its SDK behavior settings answer that it reads compressed bodies, no compressed request was refused since
  /// that answer, [url] has no query, since the compression marker has to be the only query, and the body is between
  /// 1 KB and 1 MB. Returns null when the body goes plain.
  Uint8List? _compressibleBody(String body, String url) {
    if (!requestCompressionEnabled ||
        _requestCompressionBlocked ||
        _gzipAcceptingUrl == null ||
        _gzipAcceptingUrl != baseUrl ||
        url.contains('?')) {
      return null;
    }
    final plain = utf8.encode(body);
    if (plain.length < RequestCompression.minBytes || plain.length > RequestCompression.maxBytes) {
      return null;
    }
    return plain;
  }

  /// Takes the "gzip" key of an SDK behavior settings answer from the server at [serverUrl]: true turns request
  /// compression on for that server, also after a refused compressed request had stopped it; an answer without it
  /// turns compression off.
  @internal
  void onGzipAnswer(String serverUrl, bool gzipAccepted) {
    if (!requestCompressionEnabled) return;
    _gzipAcceptingUrl = gzipAccepted ? serverUrl : null;
    if (gzipAccepted && _requestCompressionBlocked) {
      _requestCompressionBlocked = false;
      L?.i('A behavior settings answer says that the server reads compressed bodies, requests are compressed again');
    }
    L?.d('The server ${gzipAccepted ? 'reads' : 'does not say it reads'} compressed request bodies');
  }

  /// Validates response: status 200-299 and JSON body with "result":"Success" or any JSON if acceptJSON is true.
  /// A compressed request whose answer is not valid stops request compression, until the next SDK behavior settings
  /// answer says that the server reads compressed bodies, or the SDK starts again.
  bool isResponseValid(http.Response resp, {bool acceptJSON = false}) {
    final valid = _isResponseValid(resp, acceptJSON: acceptJSON);
    if (!valid && resp.request?.url.query == RequestCompression.urlMarker && !_requestCompressionBlocked) {
      _requestCompressionBlocked = true;
      L?.i('A compressed request was refused, requests are sent uncompressed until a behavior settings answer says that the server reads compressed bodies, or the SDK starts again');
    }
    return valid;
  }

  bool _isResponseValid(http.Response resp, {bool acceptJSON = false}) {
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
