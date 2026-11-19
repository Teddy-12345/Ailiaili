import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Trust only a manifest authenticated by the application's embedded public key.
Map<String, dynamic> verifyWindowsRelease(
  Uint8List envelope,
  Map<String, dynamic> key,
) {
  if (envelope.length > 65536)
    throw const FormatException('Manifest too large');
  final data = jsonDecode(utf8.decode(envelope)) as Map<String, dynamic>;
  final payload = base64Decode(data['payload'] as String);
  final signature = base64Decode(data['signature'] as String);
  final verifier = RSASigner(SHA256Digest(), '0609608648016503040201')
    ..init(
      false,
      PublicKeyParameter<RSAPublicKey>(
        RSAPublicKey(
          BigInt.parse(key['modulus'] as String, radix: 16),
          BigInt.parse(key['exponent'] as String, radix: 16),
        ),
      ),
    );
  if (!verifier.verifySignature(payload, RSASignature(signature))) {
    throw const FormatException('Invalid release signature');
  }
  final release = jsonDecode(utf8.decode(payload)) as Map<String, dynamic>;
  if (release['product'] != 'ailiaili' ||
      release['platform'] != 'windows-x64') {
    throw const FormatException('Wrong release identity');
  }
  return release;
}
