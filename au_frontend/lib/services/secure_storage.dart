import 'package:flutter_secure_storage/flutter_secure_storage.dart';


class SecureStore {
static const _storage = FlutterSecureStorage();
static const _kUser = 'username';
static const _kPass = 'password';


static Future<void> saveCreds(String username, String password) async {
await _storage.write(key: _kUser, value: username);
await _storage.write(key: _kPass, value: password);
}


static Future<String?> readUsername() => _storage.read(key: _kUser);
static Future<String?> readPassword() => _storage.read(key: _kPass);


static Future<void> clear() async {
await _storage.delete(key: _kUser);
await _storage.delete(key: _kPass);
}
}