import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Verrouillage par code PIN (surtout utile sur Android).
///
/// Le PIN n'est jamais stocké en clair : seule son empreinte SHA-256 salée
/// est conservée dans le stockage sécurisé du système (Keystore sur Android,
/// DPAPI sur Windows).
class PinService {
  const PinService();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const String _hashKey = 'pin_hash';
  static const String _saltKey = 'pin_salt';

  Future<bool> isConfigured() async =>
      await _storage.read(key: _hashKey) != null;

  Future<void> setPin(String pin) async {
    final String salt = DateTime.now().microsecondsSinceEpoch.toString();
    await _storage.write(key: _saltKey, value: salt);
    await _storage.write(key: _hashKey, value: _hash(pin, salt));
  }

  Future<bool> verify(String pin) async {
    final String? hash = await _storage.read(key: _hashKey);
    final String? salt = await _storage.read(key: _saltKey);
    // Aucun code enregistré : on refuse, jamais l'inverse.
    // (Le cas « réglage synchronisé mais coffre vide » est traité au démarrage,
    // voir `_RootGate` dans lib/app.dart.)
    if (hash == null || salt == null) return false;
    return _hash(pin, salt) == hash;
  }

  Future<void> clear() async {
    await _storage.delete(key: _hashKey);
    await _storage.delete(key: _saltKey);
  }

  String _hash(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt::$pin')).toString();
}
