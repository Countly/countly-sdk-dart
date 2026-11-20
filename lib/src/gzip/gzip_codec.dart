import 'dart:typed_data';

import 'gzip_stub.dart'
    if (dart.library.html) 'gzip_web.dart'
    if (dart.library.io) 'gzip_io.dart' as impl;

/// Compresses [plain] with gzip, with the encoder of the platform: dart:io on native platforms and CompressionStream
/// in browsers. Returns null when the platform has no gzip encoder or compressing fails.
Future<Uint8List?> gzipBytes(Uint8List plain) => impl.gzipBytes(plain);
