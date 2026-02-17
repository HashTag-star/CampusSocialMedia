import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

class StorageService {
  final _secureStorage = const FlutterSecureStorage();
  
  // Cache SharedPreferences instance
  SharedPreferences? _prefs;

  Future<void> _initPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<String?> read({required String key}) async {
    // For Windows/Linux, use SharedPreferences (simpler for dev)
    // For Mobile, use SecureStorage
    if (Platform.isWindows || Platform.isLinux) {
      await _initPrefs();
      return _prefs?.getString(key);
    } else {
      return await _secureStorage.read(key: key);
    }
  }

  Future<void> write({required String key, required String value}) async {
    if (Platform.isWindows || Platform.isLinux) {
      await _initPrefs();
      await _prefs?.setString(key, value);
    } else {
      await _secureStorage.write(key: key, value: value);
    }
  }

  Future<void> delete({required String key}) async {
    if (Platform.isWindows || Platform.isLinux) {
      await _initPrefs();
      await _prefs?.remove(key);
    } else {
      await _secureStorage.delete(key: key);
    }
  }
}
