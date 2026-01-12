# Phase 1 Security Implementation - Client-Side RSA E2E Encryption

## Overview

This document describes the client-side RSA end-to-end encryption implementation for Locksy. The server **never** stores or handles private keys - all encryption/decryption happens client-side.

## Architecture

### Encryption Flow

```
Client A (Flutter)
  ↓
1. Generate RSA keypair (2048-bit)
2. Store private key in FlutterSecureStorage (encrypted with user passphrase)
3. Send public key to server via POST /api/usuarios/me/public-key
  ↓
Server
  ↓
4. Store public key in database (Usuario.publicKey)
5. Provide public key via GET /api/usuarios/:id/public-key
  ↓
Client B (Flutter)
  ↓
6. Fetch Client A's public key from server
7. Encrypt message with Client A's public key (RSA)
8. Send encrypted message (ciphertext) to server
  ↓
Server
  ↓
9. Store encrypted message (cannot decrypt)
10. Forward to Client A via Socket.IO
  ↓
Client A
  ↓
11. Decrypt message with private key (stored securely on device)
```

## Client Implementation (Flutter)

### 1. Generate RSA Keypair

```dart
import 'package:pointycastle/export.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

Future<AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>> generateRSAKeypair() async {
  final keyGen = RSAKeyGenerator();
  final secureRandom = FortunaRandom();
  
  final seedSource = Random.secure();
  final seeds = <int>[];
  for (int i = 0; i < 32; i++) {
    seeds.add(seedSource.nextInt(255));
  }
  secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));
  
  final keyParams = RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64);
  final params = ParametersWithRandom(keyParams, secureRandom);
  
  keyGen.init(params);
  final keyPair = keyGen.generateKeyPair();
  
  return keyPair;
}
```

### 2. Store Private Key Securely

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';
import 'dart:convert';

final _storage = FlutterSecureStorage();

Future<void> storePrivateKey(RSAPrivateKey privateKey, String userPassphrase) async {
  // Derive encryption key from user passphrase
  final key = _deriveKeyFromPassphrase(userPassphrase);
  
  // Encrypt private key
  final encryptedKey = _encryptPrivateKey(privateKey, key);
  
  // Store encrypted private key
  await _storage.write(
    key: 'private_key',
    value: base64Encode(encryptedKey),
  );
}

Uint8List _deriveKeyFromPassphrase(String passphrase) {
  // Use PBKDF2 or Argon2 to derive key from passphrase
  final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
  pbkdf2.init(Pbkdf2Parameters(Uint8List.fromList(utf8.encode('locksy-salt')), 100000, 32));
  return pbkdf2.process(Uint8List.fromList(utf8.encode(passphrase)));
}
```

### 3. Send Public Key to Server

```dart
Future<void> uploadPublicKey(String publicKeyPEM) async {
  final response = await http.post(
    Uri.parse('$baseUrl/api/usuarios/me/public-key'),
    headers: {
      'Content-Type': 'application/json',
      'x-token': await getAccessToken(),
    },
    body: jsonEncode({
      'publicKey': publicKeyPEM,
    }),
  );
  
  if (response.statusCode == 200) {
    print('Public key uploaded successfully');
  }
}
```

### 4. Get Recipient's Public Key

```dart
Future<String?> getPublicKey(String userId) async {
  final response = await http.get(
    Uri.parse('$baseUrl/api/usuarios/$userId/public-key'),
    headers: {
      'x-token': await getAccessToken(),
    },
  );
  
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return data['usuario']['publicKey'];
  }
  
  return null;
}
```

### 5. Encrypt Message

```dart
Future<String> encryptMessage(String plaintext, String recipientPublicKeyPEM) async {
  // Parse public key
  final publicKey = RSAKeyParser().parse(recipientPublicKeyPEM) as RSAPublicKey;
  
  // Encrypt with RSA-OAEP
  final encrypter = OAEPEncoding(RSAEngine());
  encrypter.init(true, PublicKeyParameter<RSAPublicKey>(publicKey));
  
  final plaintextBytes = Uint8List.fromList(utf8.encode(plaintext));
  final encrypted = encrypter.process(plaintextBytes);
  
  // Return base64 encoded ciphertext
  return base64Encode(encrypted);
}
```

### 6. Decrypt Message

```dart
Future<String> decryptMessage(String ciphertextBase64) async {
  // Get private key from secure storage
  final encryptedKeyBase64 = await _storage.read(key: 'private_key');
  final userPassphrase = await getUserPassphrase(); // From secure storage
  final key = _deriveKeyFromPassphrase(userPassphrase);
  final privateKey = _decryptPrivateKey(base64Decode(encryptedKeyBase64!), key);
  
  // Decrypt with RSA-OAEP
  final decrypter = OAEPEncoding(RSAEngine());
  decrypter.init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));
  
  final ciphertextBytes = base64Decode(ciphertextBase64);
  final decrypted = decrypter.process(ciphertextBytes);
  
  return utf8.decode(decrypted);
}
```

### 7. Send Encrypted Message

```dart
Future<void> sendMessage(String recipientId, String ciphertext) async {
  final response = await http.post(
    Uri.parse('$baseUrl/api/mensajes'),
    headers: {
      'Content-Type': 'application/json',
      'x-token': await getAccessToken(),
    },
    body: jsonEncode({
      'para': recipientId,
      'mensaje': {
        'ciphertext': ciphertext,
        'type': 'text',
      },
    }),
  );
  
  if (response.statusCode == 200) {
    print('Message sent successfully');
  }
}
```

## Server API Endpoints

### POST /api/usuarios/me/public-key
Upload or update user's public key.

**Request:**
```json
{
  "publicKey": "-----BEGIN PUBLIC KEY-----\n...\n-----END PUBLIC KEY-----"
}
```

**Response:**
```json
{
  "ok": true,
  "usuario": {
    "uid": "...",
    "publicKey": "-----BEGIN PUBLIC KEY-----\n...\n-----END PUBLIC KEY-----"
  }
}
```

### GET /api/usuarios/:id/public-key
Get user's public key.

**Response:**
```json
{
  "ok": true,
  "usuario": {
    "uid": "...",
    "nombre": "User Name",
    "codigoContacto": "ABC12",
    "publicKey": "-----BEGIN PUBLIC KEY-----\n...\n-----END PUBLIC KEY-----"
  }
}
```

### POST /api/mensajes
Send encrypted message.

**Request:**
```json
{
  "para": "recipient_user_id",
  "mensaje": {
    "ciphertext": "base64_encoded_encrypted_message",
    "type": "text"
  }
}
```

**Response:**
```json
{
  "ok": true,
  "mensaje": {
    "_id": "...",
    "de": "sender_id",
    "para": "recipient_id",
    "mensaje": {
      "ciphertext": "base64_encoded_encrypted_message",
      "type": "text"
    }
  }
}
```

## Security Notes

1. **Private Keys**: NEVER stored on server. Always stored client-side in FlutterSecureStorage.

2. **Key Derivation**: Use PBKDF2 or Argon2 to derive encryption key from user passphrase.

3. **Key Size**: Use 2048-bit RSA keys minimum.

4. **Encryption Scheme**: Use RSA-OAEP for encryption (not PKCS1v1.5).

5. **Message Format**: Messages are stored as ciphertext only - server cannot decrypt.

6. **Key Rotation**: Support key rotation by allowing users to generate new keypairs and update public key.

## Migration Notes

- Existing users with `privateKey` in database: Run migration script to remove.
- Existing messages: May need re-encryption if stored in plaintext (not covered in Phase 1).
- Password recovery: Currently uses legacy encoding (to be replaced with JWT tokens).

## Testing

1. Generate keypair on client
2. Upload public key to server
3. Verify private key is NOT stored on server
4. Send encrypted message
5. Verify server stores only ciphertext
6. Verify recipient can decrypt message

## References

- [RSA Encryption](https://en.wikipedia.org/wiki/RSA_(cryptosystem))
- [Flutter Secure Storage](https://pub.dev/packages/flutter_secure_storage)
- [PointyCastle](https://pub.dev/packages/pointycastle)

