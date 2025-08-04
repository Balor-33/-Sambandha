import 'package:encrypt/encrypt.dart';
import 'dart:convert';
import 'dart:typed_data';

class EncryptionHelper {
  // Use a secure key in production! Never hardcode in real apps.
  static final _key = Key.fromUtf8('my32lengthsupersecretnooneknows1');
  static final _encrypter = Encrypter(AES(_key));

  static String encryptText(String plainText) {
    try {
      // Generate a unique IV for each encryption
      final iv = IV.fromSecureRandom(16);

      // Encrypt the text
      final encrypted = _encrypter.encrypt(plainText, iv: iv);

      // Combine IV and encrypted data
      final combined = <int>[];
      combined.addAll(iv.bytes);
      combined.addAll(encrypted.bytes);

      // Return as base64 string
      return base64Encode(combined);
    } catch (e) {
      print('Encryption error: $e');
      throw Exception('Failed to encrypt message');
    }
  }

  static String decryptText(String encryptedText) {
    try {
      // Decode base64
      final combined = base64Decode(encryptedText);

      // Ensure we have enough bytes (at least IV + some encrypted data)
      if (combined.length <= 16) {
        throw Exception('Invalid encrypted data length');
      }

      // Extract IV (first 16 bytes)
      final ivBytes = combined.sublist(0, 16);
      final iv = IV(Uint8List.fromList(ivBytes));

      // Extract encrypted data (remaining bytes)
      final encryptedBytes = combined.sublist(16);
      final encrypted = Encrypted(Uint8List.fromList(encryptedBytes));

      // Decrypt and return
      return _encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      print('Decryption error: $e');
      print('Encrypted text: $encryptedText');
      return '[Unable to decrypt message]';
    }
  }

  // Test function to verify encryption/decryption works
  static bool testEncryption() {
    try {
      const testMessage = "Hello, this is a test message! 🚀";
      final encrypted = encryptText(testMessage);
      final decrypted = decryptText(encrypted);

      print('Test - Original: $testMessage');
      print('Test - Encrypted: ${encrypted.substring(0, 20)}...');
      print('Test - Decrypted: $decrypted');

      return testMessage == decrypted;
    } catch (e) {
      print('Test failed: $e');
      return false;
    }
  }
}
