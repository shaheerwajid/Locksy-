import 'dart:convert';
import 'dart:typed_data';

import 'package:CryptoChat/crypto/crypto.dart';
import 'package:asn1lib/asn1lib.dart';
import 'package:encrypt/encrypt.dart' as cry;
import 'package:pointycastle/api.dart';
import 'package:pointycastle/asymmetric/api.dart';

class LocalCrypto {
  Set<String> generatePaireKey() {
    var key = generateRSAkeyPair();
    RSAPrivateKey privateKey = key.privateKey;
    RSAPublicKey publicKey = key.publicKey;
    String publicKeyString = publicKeyToString(publicKey);
    String privateKeyString = privateKeyToString(privateKey);
    return {publicKeyString, privateKeyString};
  }

  String publicKeyToString(RSAPublicKey publicKey) {
    var topLevel = ASN1Sequence();

    topLevel.add(ASN1Integer(publicKey.modulus!));
    topLevel.add(ASN1Integer(publicKey.exponent!));

    var dataBase64 = base64.encode(topLevel.encodedBytes);

    return dataBase64;
  }

  RSAPublicKey stringToPublicKey(String publicKeyString) {
    // Trim and normalize the string first
    String normalized = publicKeyString.trim();

    // Debug logging to see what we're receiving
    print('[Crypto] ======================================');
    print('[Crypto] stringToPublicKey called');
    print('[Crypto] Input length: ${normalized.length}');
    print(
        '[Crypto] First 80 chars: ${normalized.length > 80 ? normalized.substring(0, 80) : normalized}');
    print('[Crypto] Contains BEGIN: ${normalized.contains('-----BEGIN')}');
    print('[Crypto] Contains END: ${normalized.contains('-----END')}');

    // More robust PEM format check
    bool looksLikePEM = normalized.contains('-----BEGIN') &&
        normalized.contains('-----END') &&
        (normalized.contains('PUBLIC KEY') ||
            normalized.contains('PRIVATE KEY'));

    if (looksLikePEM) {
      // It's PEM format - use the existing parsePublicKeyFromPem function
      print(
          '[Crypto] ✅ Detected PEM format, parsing with parsePublicKeyFromPem...');
      try {
        RSAPublicKey key = parsePublicKeyFromPem(normalized);
        print('[Crypto] ✅✅ PEM parsing SUCCESS');
        print('[Crypto] ======================================');
        return key;
      } catch (e, stackTrace) {
        print('[Crypto] ❌ ERROR parsing PEM format: $e');
        print('[Crypto] Stack trace: $stackTrace');
        // Try ASN.1 as fallback
        print('[Crypto] Attempting ASN.1 fallback...');
      }
    }

    // Try ASN.1 Base64 format (direct format used by Flutter, or fallback)
    print('[Crypto] Attempting ASN.1 Base64 format parsing...');
    try {
      var publicKeyDER = base64.decode(normalized);
      print('[Crypto] Base64 decode successful, parsing ASN.1...');

      var asn1Parser = ASN1Parser(publicKeyDER);
      var topLevelSequence = asn1Parser.nextObject() as ASN1Sequence;

      print(
          '[Crypto] Top-level sequence has ${topLevelSequence.elements.length} elements');

      if (topLevelSequence.elements.length < 2) {
        throw Exception(
            'Invalid ASN.1 sequence: expected at least 2 elements, got ${topLevelSequence.elements.length}');
      }

      var modulus = topLevelSequence.elements[0] as ASN1Integer;
      var exponent = topLevelSequence.elements[1] as ASN1Integer;

      print('[Crypto] ✅✅ ASN.1 parsing SUCCESS');
      print('[Crypto] ======================================');
      return RSAPublicKey(
          modulus.valueAsBigInteger, exponent.valueAsBigInteger);
    } catch (e, stackTrace) {
      print('[Crypto] ❌❌ FATAL: Both PEM and ASN.1 parsing failed');
      print('[Crypto] ERROR: $e');
      print(
          '[Crypto] Input (first 200 chars): ${normalized.length > 200 ? normalized.substring(0, 200) : normalized}');
      print('[Crypto] Stack trace: $stackTrace');
      print('[Crypto] ======================================');
      rethrow;
    }
  }

  String privateKeyToString(RSAPrivateKey privateKey) {
    var topLevel = ASN1Sequence();

    topLevel.add(ASN1Integer(privateKey.n!)); // modulus
    topLevel.add(ASN1Integer(privateKey.privateExponent!)); // privateExponent
    topLevel.add(ASN1Integer(privateKey.p!)); // prime1
    topLevel.add(ASN1Integer(privateKey.q!)); // prime2

    var dataBase64 = base64.encode(topLevel.encodedBytes);

    return dataBase64;
  }

  RSAPrivateKey stringToPrivateKey(String privateKeyString) {
    // Trim and normalize the string first
    String normalized = privateKeyString.trim();

    print('[Crypto] ======================================');
    print('[Crypto] stringToPrivateKey called');
    print('[Crypto] Input length: ${normalized.length}');
    print(
        '[Crypto] First 80 chars: ${normalized.length > 80 ? normalized.substring(0, 80) : normalized}');
    print('[Crypto] Contains BEGIN: ${normalized.contains('-----BEGIN')}');
    print('[Crypto] Contains END: ${normalized.contains('-----END')}');

    // Check if it's PEM format
    bool looksLikePEM = normalized.contains('-----BEGIN') &&
        normalized.contains('-----END') &&
        (normalized.contains('PRIVATE KEY') ||
            normalized.contains('RSA PRIVATE KEY'));

    if (looksLikePEM) {
      print(
          '[Crypto] ✅ Detected PEM format, parsing with parsePrivateKeyFromPem...');
      try {
        RSAPrivateKey key = parsePrivateKeyFromPem(normalized);
        print('[Crypto] ✅✅ PEM parsing SUCCESS');
        print('[Crypto] ======================================');
        return key;
      } catch (e, stackTrace) {
        print('[Crypto] ❌ ERROR parsing PEM format: $e');
        print('[Crypto] Stack trace: $stackTrace');
        print('[Crypto] Attempting ASN.1 fallback...');
      }
    }

    // Try ASN.1 Base64 format
    print('[Crypto] Attempting ASN.1 Base64 format parsing...');
    try {
      var privateKeyDER = base64.decode(normalized);
      print('[Crypto] Base64 decode successful, parsing ASN.1...');

      var asn1Parser = ASN1Parser(privateKeyDER);
      var nextObject = asn1Parser.nextObject();

      // CRITICAL FIX: Check if it's actually a sequence before casting
      ASN1Sequence topLevelSequence;
      if (nextObject is ASN1Sequence) {
        topLevelSequence = nextObject;
      } else {
        // If it's not a sequence, log the actual type and throw a more descriptive error
        print(
            '[Crypto] ❌ First object is not a sequence, type: ${nextObject.runtimeType}');
        throw Exception(
            'Expected ASN1Sequence but got ${nextObject.runtimeType}. The private key format may be incorrect.');
      }

      print(
          '[Crypto] Top-level sequence has ${topLevelSequence.elements.length} elements');

      if (topLevelSequence.elements.length < 4) {
        throw Exception(
            'Invalid ASN.1 sequence: expected at least 4 elements, got ${topLevelSequence.elements.length}');
      }

      var modulus = topLevelSequence.elements[0] as ASN1Integer;
      var privateExponent = topLevelSequence.elements[1] as ASN1Integer;
      var prime1 = topLevelSequence.elements[2] as ASN1Integer;
      var prime2 = topLevelSequence.elements[3] as ASN1Integer;

      print('[Crypto] ✅✅ ASN.1 parsing SUCCESS');
      print('[Crypto] ======================================');
      return RSAPrivateKey(
          modulus.valueAsBigInteger,
          privateExponent.valueAsBigInteger,
          prime1.valueAsBigInteger,
          prime2.valueAsBigInteger);
    } catch (e, stackTrace) {
      print('[Crypto] ❌❌ FATAL: Both PEM and ASN.1 parsing failed');
      print('[Crypto] ERROR: $e');
      print(
          '[Crypto] Input (first 200 chars): ${normalized.length > 200 ? normalized.substring(0, 200) : normalized}');
      print('[Crypto] Stack trace: $stackTrace');
      print('[Crypto] ======================================');
      rethrow;
    }
  }

  String decrypt(String keyString, String base64EncryptedData) {
    final key = cry.Key.fromUtf8(keyString);
    final encrypter = cry.Encrypter(cry.AES(key, mode: cry.AESMode.cbc));
    final initVector = cry.IV.fromUtf8(keyString.substring(0, 16));

    // Convert the base64 string back into an Encrypted object
    final encryptedData = cry.Encrypted.fromBase64(base64EncryptedData);

    // Decrypt the data
    return encrypter.decrypt(encryptedData, iv: initVector);
  }

  String encrypt(String keyString, String plainText) {
    final key = cry.Key.fromUtf8(keyString);
    final encrypter = cry.Encrypter(cry.AES(key, mode: cry.AESMode.cbc));
    final initVector = cry.IV.fromUtf8(keyString.substring(0, 16));
    cry.Encrypted encryptedData = encrypter.encrypt(plainText, iv: initVector);
    return encryptedData.base64;
  }

  String rsaEncryptMessage(String texto, String publicKey) {
    String x = base64
        .encode(rsaEncrypt(stringToPublicKey(publicKey), utf8.encode(texto)));
    return x;
  }

  AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> getKeyPairFromString(
      String privateKey, String publicKey) {
    return AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>(
        stringToPublicKey(publicKey), stringToPrivateKey(privateKey));
  }

  /// Converts PEM format public key to ASN.1 Base64 format
  /// Used when backend sends PEM format but we need to store ASN.1 format
  String pemToASN1(String pemString) {
    try {
      print('[Crypto] pemToASN1 called');
      print('[Crypto] Input PEM length: ${pemString.length}');
      print(
          '[Crypto] Input PEM first 100 chars: ${pemString.length > 100 ? pemString.substring(0, 100) : pemString}');

      // Parse PEM to get the RSAPublicKey object
      print('[Crypto] Parsing PEM to RSAPublicKey...');
      RSAPublicKey publicKey = parsePublicKeyFromPem(pemString);
      print('[Crypto] ✅ PEM parsed successfully');

      // Convert back to ASN.1 Base64 format
      print('[Crypto] Converting RSAPublicKey to ASN.1 Base64...');
      String asn1 = publicKeyToString(publicKey);
      print('[Crypto] ✅ Converted to ASN.1 (length: ${asn1.length})');
      print(
          '[Crypto] ASN.1 first 100 chars: ${asn1.length > 100 ? asn1.substring(0, 100) : asn1}');

      return asn1;
    } catch (e, stackTrace) {
      print('[Crypto] ❌ ERROR in pemToASN1: $e');
      print('[Crypto] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Converts ASN.1 Base64 public key to PEM format for backend validation
  /// The backend expects PEM format (with BEGIN/END markers) for validation
  /// Flutter uses ASN.1 format internally for encryption/decryption
  ///
  /// This function takes the Base64-encoded ASN.1 sequence (modulus, exponent)
  /// and wraps it in a proper SubjectPublicKeyInfo (SPKI) structure for PEM format
  String publicKeyToPEM(String base64PublicKey) {
    try {
      // Decode the ASN.1 sequence (modulus, exponent) that Flutter generates
      var publicKeyDER = base64.decode(base64PublicKey);

      // Create SubjectPublicKeyInfo structure:
      // SEQUENCE {
      //   SEQUENCE {
      //     OBJECT IDENTIFIER rsaEncryption (1.2.840.113549.1.1.1)
      //     NULL
      //   }
      //   BIT STRING {
      //     SEQUENCE {
      //       INTEGER modulus
      //       INTEGER exponent
      //     }
      //   }
      // }

      // AlgorithmIdentifier sequence
      // RSA OID bytes: 0x06 0x09 0x2a 0x86 0x48 0x86 0xf7 0x0d 0x01 0x01 0x01
      var algorithmAsn1Obj = ASN1Object.fromBytes(Uint8List.fromList(
          [0x6, 0x9, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0xd, 0x1, 0x1, 0x1]));
      var paramsAsn1Obj = ASN1Object.fromBytes(Uint8List.fromList([0x5, 0x0]));
      var algorithmSeq = ASN1Sequence();
      algorithmSeq.add(algorithmAsn1Obj);
      algorithmSeq.add(paramsAsn1Obj);

      // PublicKey BIT STRING - wrap the existing ASN.1 sequence
      // The publicKeyDER already contains the SEQUENCE(modulus, exponent)
      var publicKeySeqBitString = ASN1BitString(publicKeyDER);

      // SubjectPublicKeyInfo (top-level sequence)
      var topLevelSeq = ASN1Sequence();
      topLevelSeq.add(algorithmSeq);
      topLevelSeq.add(publicKeySeqBitString);

      // Encode to Base64
      var dataBase64 = base64.encode(topLevelSeq.encodedBytes);

      // Split into 64-character lines (PEM format standard)
      String pemBody = '';
      for (int i = 0; i < dataBase64.length; i += 64) {
        int end = (i + 64 < dataBase64.length) ? i + 64 : dataBase64.length;
        pemBody += dataBase64.substring(i, end);
        if (end < dataBase64.length) {
          pemBody += '\n';
        }
      }

      return '-----BEGIN PUBLIC KEY-----\n$pemBody\n-----END PUBLIC KEY-----';
    } catch (e) {
      print('[Crypto] Error converting ASN.1 to PEM: $e');
      rethrow; // Re-throw so registration can handle the error
    }
  }
}
