import 'dart:io';
import 'dart:typed_data';

/// Compresses [plain] with the gzip encoder of dart:io. Returns null when compressing fails.
Future<Uint8List?> gzipBytes(Uint8List plain) async {
  try {
    return Uint8List.fromList(gzip.encode(plain));
  } catch (_) {
    return null;
  }
}
