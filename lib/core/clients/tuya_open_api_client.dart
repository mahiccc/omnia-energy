import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../models/device_model.dart';
import '../security/secure_key_store.dart';

/// Serverless Tuya OpenAPI v2.0 client with on-device HMAC-SHA256 signing.
///
/// Communicates directly from the user's Android device to Tuya regional cloud
/// endpoints without any middleman backend server.
class TuyaOpenApiClient {
  final SecureKeyStore _keyStore;
  final http.Client _httpClient;

  String? _cachedAccessToken;
  int _tokenExpiryEpochMs = 0;

  TuyaOpenApiClient({
    required SecureKeyStore keyStore,
    http.Client? httpClient,
  })  : _keyStore = keyStore,
        _httpClient = httpClient ?? http.Client();

  /// Computes the Tuya OpenAPI v2.0 HMAC-SHA256 signature in uppercase hex.
  ///
  /// Formula:
  /// - `contentSha256 = SHA256(body)`
  /// - `stringToSign = METHOD + "\n" + contentSha256 + "\n" + headers + "\n" + pathWithQuery`
  /// - `payload = clientId + (accessToken ?? "") + timestampMs + nonce + stringToSign`
  /// - `sign = HMAC_SHA256(payload, clientSecret).toUpperCase()`
  static String generateHmacSha256Signature({
    required String clientId,
    required String clientSecret,
    required String httpMethod,
    required String pathWithQuery,
    required String timestampMs,
    String nonce = '',
    String? accessToken,
    String body = '',
  }) {
    final bodyBytes = utf8.encode(body);
    final contentSha256 = sha256.convert(bodyBytes).toString();

    final stringToSign = [
      httpMethod.toUpperCase(),
      contentSha256,
      '', // Optional custom signature headers
      pathWithQuery,
    ].join('\n');

    final signPayload = StringBuffer()
      ..write(clientId)
      ..write(accessToken ?? '')
      ..write(timestampMs)
      ..write(nonce)
      ..write(stringToSign);

    final hmac = Hmac(sha256, utf8.encode(clientSecret));
    final digest = hmac.convert(utf8.encode(signPayload.toString()));
    return digest.toString().toUpperCase();
  }

  /// Obtains or refreshes the Tuya OAuth access token directly from `/v1.0/token?grant_type=1`.
  Future<String> getValidAccessToken() async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (_cachedAccessToken != null && nowMs < _tokenExpiryEpochMs - 60000) {
      return _cachedAccessToken!;
    }

    final clientId = await _keyStore.getTuyaClientId();
    final clientSecret = await _keyStore.getTuyaClientSecret();
    final endpoint = await _keyStore.getTuyaEndpoint();

    if (clientId == null || clientSecret == null) {
      throw StateError('Tuya credentials are not configured in SecureKeyStore.');
    }

    const path = '/v1.0/token?grant_type=1';
    final timestampMs = nowMs.toString();
    final signature = generateHmacSha256Signature(
      clientId: clientId,
      clientSecret: clientSecret,
      httpMethod: 'GET',
      pathWithQuery: path,
      timestampMs: timestampMs,
    );

    final response = await _httpClient.get(
      Uri.parse('$endpoint$path'),
      headers: {
        'client_id': clientId,
        'sign': signature,
        't': timestampMs,
        'sign_method': 'HMAC-SHA256',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Tuya token request failed (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (decoded['success'] != true) {
      throw Exception(
        'Tuya token error: ${decoded['msg'] ?? decoded['code']}',
      );
    }

    final result = decoded['result'] as Map<String, dynamic>;
    _cachedAccessToken = result['access_token'] as String;
    final expireSeconds = (result['expire_time'] as num?)?.toInt() ?? 7200;
    _tokenExpiryEpochMs = nowMs + (expireSeconds * 1000);

    return _cachedAccessToken!;
  }

  /// Fetches live Data Points (DPs) for a device and updates its [DeviceModel].
  ///
  /// Handles both:
  /// - **Native Metering Pass-through:** Reads `cur_power` (normalized from deciwatts if needed).
  /// - **Virtual Payload State:** Reads `switch_1` / `switch` / `fan_speed_percent` / `bright_value`.
  Future<DeviceModel> refreshDeviceTelemetry(DeviceModel device) async {
    final clientId = await _keyStore.getTuyaClientId();
    final clientSecret = await _keyStore.getTuyaClientSecret();
    final endpoint = await _keyStore.getTuyaEndpoint();

    if (clientId == null || clientSecret == null) {
      throw StateError('Tuya credentials are not configured in SecureKeyStore.');
    }

    final accessToken = await getValidAccessToken();
    final path = '/v1.0/iot-03/devices/${device.id}/status';
    final timestampMs = DateTime.now().millisecondsSinceEpoch.toString();

    final signature = generateHmacSha256Signature(
      clientId: clientId,
      clientSecret: clientSecret,
      httpMethod: 'GET',
      pathWithQuery: path,
      timestampMs: timestampMs,
      accessToken: accessToken,
    );

    final response = await _httpClient.get(
      Uri.parse('$endpoint$path'),
      headers: {
        'client_id': clientId,
        'access_token': accessToken,
        'sign': signature,
        't': timestampMs,
        'sign_method': 'HMAC-SHA256',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Tuya status poll failed for ${device.id}: HTTP ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (decoded['success'] != true) {
      throw Exception(
        'Tuya status error for ${device.id}: ${decoded['msg']}',
      );
    }

    final statusList = (decoded['result'] as List<dynamic>? ?? const []);
    return applyTuyaStatusList(device, statusList);
  }

  /// Parses Tuya DP status entries (`[{"code": "cur_power", "value": 1250}, ...]`)
  /// into an updated [DeviceModel].
  static DeviceModel applyTuyaStatusList(
    DeviceModel device,
    List<dynamic> statusList,
  ) {
    bool isOn = device.isOn;
    double levelPercent = device.currentLevelPercent;
    double? liveWatts = device.livePowerWatts;

    // Default Tuya cur_power scale is deciwatts (0.1W) unless overridden in metadata
    final powerScale =
        (device.metadata['power_scale'] as num?)?.toDouble() ?? 0.1;

    for (final entry in statusList) {
      if (entry is! Map<String, dynamic>) continue;
      final code = entry['code'] as String?;
      final value = entry['value'];

      switch (code) {
        case 'switch':
        case 'switch_1':
        case 'switch_led':
        case 'fan_switch':
          if (value is bool) isOn = value;
          break;
        case 'cur_power':
        case 'total_power':
        case 'phase_a_power':
          if (value is num) {
            liveWatts = value.toDouble() * powerScale;
            isOn = liveWatts > 0.5;
          }
          break;
        case 'fan_speed_percent':
        case 'percent_control':
          if (value is num) {
            levelPercent = value.toDouble().clamp(0.0, 100.0);
          }
          break;
        case 'bright_value':
          if (value is num) {
            // Tuya brightness typically spans 10..1000 or 0..100
            final raw = value.toDouble();
            levelPercent =
                (raw > 100.0 ? (raw / 10.0) : raw).clamp(0.0, 100.0);
          }
          break;
      }
    }

    return device.copyWith(
      isOn: isOn,
      currentLevelPercent: levelPercent,
      livePowerWatts: liveWatts,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }
}
