import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;

class CryptoService {
  // 真实源站 Web Worker (crypto-worker.js) 提取的真实密钥与 IV
  static final _key = encrypt.Key.fromUtf8('f5d965df75336270');
  static final _iv = encrypt.IV.fromUtf8('97b60394abc2fbe1');

  static Uint8List decryptImage(Uint8List encryptedBytes) {
    if (encryptedBytes.length < 16) return encryptedBytes;
    try {
      // 官方前端使用的是 AES-128-CBC 模式无填充解密
      final encrypter = encrypt.Encrypter(encrypt.AES(_key, mode: encrypt.AESMode.cbc, padding: null));
      
      // 确保密文长度对齐 16 字节
      final validLength = encryptedBytes.length - (encryptedBytes.length % 16);
      final inputBytes = validLength == encryptedBytes.length
          ? encryptedBytes
          : encryptedBytes.sublist(0, validLength);

      final encrypted = encrypt.Encrypted(inputBytes);
      final decrypted = encrypter.decryptBytes(encrypted, iv: _iv);
      return Uint8List.fromList(decrypted);
    } catch (e) {
      return encryptedBytes;
    }
  }
}
