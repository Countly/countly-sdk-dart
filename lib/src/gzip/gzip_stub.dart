import 'dart:typed_data';

/// A platform without a gzip encoder sends plain bodies, so this returns null.
Future<Uint8List?> gzipBytes(Uint8List plain) async => null;
