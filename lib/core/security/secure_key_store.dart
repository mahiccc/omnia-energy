import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Hardware-backed Android Keystore wrapper for OmniaEnergy credentials.
///
/// Guarantees Data Sovereignty: API credentials exist strictly in the local
/// device's Android Keystore and are never transmitted to any middleman backend.
class SecureKeyStore {
  static const String keyTuyaClientId = 'omnia_tuya_client_id';
  static const String keyTuyaClientSecret = 'omnia_tuya_client_secret';
  static const String keyTuyaEndpoint = 'omnia_tuya_endpoint';
  static const String keyGoogleSpreadsheetId = 'omnia_master_spreadsheet_id';

  final FlutterSecureStorage _storage;

  const SecureKeyStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
                resetOnError: true,
              ),
            );

  Future<void> saveTuyaCredentials({
    required String clientId,
    required String clientSecret,
    String endpoint = 'https://openapi.tuyain.com',
  }) async {
    await Future.wait([
      _storage.write(key: keyTuyaClientId, value: clientId),
      _storage.write(key: keyTuyaClientSecret, value: clientSecret),
      _storage.write(key: keyTuyaEndpoint, value: endpoint),
    ]);
  }

  Future<String?> getTuyaClientId() => _storage.read(key: keyTuyaClientId);
  Future<String?> getTuyaClientSecret() =>
      _storage.read(key: keyTuyaClientSecret);
  Future<String> getTuyaEndpoint() async =>
      (await _storage.read(key: keyTuyaEndpoint)) ??
      'https://openapi.tuyain.com';

  Future<void> saveMasterSpreadsheetId(String spreadsheetId) =>
      _storage.write(key: keyGoogleSpreadsheetId, value: spreadsheetId);

  Future<String?> getMasterSpreadsheetId() =>
      _storage.read(key: keyGoogleSpreadsheetId);

  Future<void> clearAllCredentials() => _storage.deleteAll();
}
