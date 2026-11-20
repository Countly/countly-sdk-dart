import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Compresses [plain] with the browser's CompressionStream. Returns null in a browser without it, or when compressing
/// fails.
Future<Uint8List?> gzipBytes(Uint8List plain) async {
  try {
    final compression = web.CompressionStream('gzip');
    final compressed = web.Blob(<JSAny>[plain.toJS].toJS)
        .stream()
        .pipeThrough(web.ReadableWritablePair(readable: compression.readable, writable: compression.writable));
    final buffer = await web.Response(compressed).arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  } catch (_) {
    return null;
  }
}
