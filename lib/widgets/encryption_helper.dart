import 'package:encrypt/encrypt.dart';

class EncryptionHelper {
  // Use a secure key in production! Never hardcode in real apps.
  static final _key = Key.fromUtf8('my32lengthsupersecretnooneknows1'); // 32 chars for AES-256
  static final _iv = IV.fromLength(16);

  static String encryptText(String plainText) {
    final encrypter = Encrypter(AES(_key));
    final encrypted = encrypter.encrypt(plainText, iv: _iv);
    return encrypted.base64;
  }

  static String decryptText(String encryptedText) {
    final encrypter = Encrypter(AES(_key));
    final decrypted = encrypter.decrypt64(encryptedText, iv: _iv);
    return decrypted;
  }
}