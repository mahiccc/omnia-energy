import 'dart:convert';

/// Classification of devices in the OmniaEnergy disaggregation pipeline.
enum DeviceCategory {
  /// Whole-home or circuit-level Hardware CT Clamp measuring P_CT.
  ctClamp('CT_CLAMP'),

  /// Smart plug or appliance exposing live power Data Points (P_Native).
  nativeMetering('NATIVE_METERING'),

  /// Non-metering smart appliance (e.g., Atomberg BLE fan, smart bulb)
  /// whose active wattage is computed via the Virtual Payload Engine (P_Virtual).
  virtualPayload('VIRTUAL_PAYLOAD');

  final String dbValue;
  const DeviceCategory(this.dbValue);

  static DeviceCategory fromDbValue(String value) {
    return DeviceCategory.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => DeviceCategory.virtualPayload,
    );
  }
}

/// Supported vendor/protocol sources in the Ingestion Engine.
enum DeviceVendor {
  hardwareCt('HARDWARE_CT'),
  tuyaOpenApi('TUYA_OPENAPI'),
  googleHome('GOOGLE_HOME'),
  atombergBle('ATOMBERG_BLE');

  final String dbValue;
  const DeviceVendor(this.dbValue);

  static DeviceVendor fromDbValue(String value) {
    return DeviceVendor.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => DeviceVendor.tuyaOpenApi,
    );
  }
}

/// Represents a physical or virtual energy-tracked device in OmniaEnergy.
///
/// Implements the Section 4 Key Calculation Rules:
/// - **Native Metering Pass-through:** Uses [livePowerWatts] directly when
///   [category] is [DeviceCategory.nativeMetering] or [DeviceCategory.ctClamp].
/// - **Virtual Payload Engine:**
///   `Active Watts (P_t) = P_rated * (Current Level / 100.0) * State`
class DeviceModel {
  final String id;
  final String name;
  final DeviceCategory category;
  final DeviceVendor vendor;

  /// Rated maximum power (P_rated in Watts) used by the Virtual Payload Engine.
  final double ratedWatts;

  /// Current operating level in [0.0 .. 100.0] (e.g., fan speed %, dimmer %).
  final double currentLevelPercent;

  /// Binary operational state: true = ON (1), false = OFF (0).
  final bool isOn;

  /// Live wattage reported directly by hardware Data Points (DPs) for CT/Native devices.
  final double? livePowerWatts;

  /// Optional extra vendor metadata (e.g., BLE MAC address, Tuya DP mapping).
  final Map<String, dynamic> metadata;

  /// Epoch milliseconds of the last telemetry update.
  final int updatedAtMs;

  const DeviceModel({
    required this.id,
    required this.name,
    required this.category,
    required this.vendor,
    this.ratedWatts = 0.0,
    this.currentLevelPercent = 100.0,
    this.isOn = false,
    this.livePowerWatts,
    this.metadata = const {},
    required this.updatedAtMs,
  });

  /// Numeric state multiplier (`1.0` when ON, `0.0` when OFF).
  double get stateMultiplier => isOn ? 1.0 : 0.0;

  /// Computes instantaneous Active Watts (`P_t`) according to Section 4 rules:
  /// - **CT Clamp & Native Metering Pass-through:** Returns [livePowerWatts] (or `0.0` if null).
  /// - **Virtual Payload Engine:**
  ///   $$P_t = P_{\text{rated}} \times \left(\frac{\text{Current Level}}{100}\right) \times \text{State}$$
  double get activeWatts {
    switch (category) {
      case DeviceCategory.ctClamp:
      case DeviceCategory.nativeMetering:
        return (livePowerWatts ?? 0.0).clamp(0.0, double.infinity);
      case DeviceCategory.virtualPayload:
        final normalizedLevel = (currentLevelPercent.clamp(0.0, 100.0)) / 100.0;
        return ratedWatts * normalizedLevel * stateMultiplier;
    }
  }

  DeviceModel copyWith({
    String? id,
    String? name,
    DeviceCategory? category,
    DeviceVendor? vendor,
    double? ratedWatts,
    double? currentLevelPercent,
    bool? isOn,
    double? livePowerWatts,
    Map<String, dynamic>? metadata,
    int? updatedAtMs,
  }) {
    return DeviceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      vendor: vendor ?? this.vendor,
      ratedWatts: ratedWatts ?? this.ratedWatts,
      currentLevelPercent: currentLevelPercent ?? this.currentLevelPercent,
      isOn: isOn ?? this.isOn,
      livePowerWatts: livePowerWatts ?? this.livePowerWatts,
      metadata: metadata ?? this.metadata,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  Map<String, Object?> toSqlMap() {
    return {
      'device_id': id,
      'name': name,
      'category': category.dbValue,
      'vendor': vendor.dbValue,
      'rated_watts': ratedWatts,
      'current_level_percent': currentLevelPercent,
      'is_on': isOn ? 1 : 0,
      'live_power_watts': livePowerWatts,
      'metadata_json': jsonEncode(metadata),
      'updated_at_ms': updatedAtMs,
    };
  }

  factory DeviceModel.fromSqlMap(Map<String, Object?> map) {
    final rawMeta = map['metadata_json'] as String?;
    Map<String, dynamic> parsedMeta = const {};
    if (rawMeta != null && rawMeta.isNotEmpty) {
      try {
        parsedMeta = Map<String, dynamic>.from(jsonDecode(rawMeta) as Map);
      } catch (_) {
        parsedMeta = const {};
      }
    }

    return DeviceModel(
      id: map['device_id'] as String,
      name: map['name'] as String,
      category: DeviceCategory.fromDbValue(map['category'] as String),
      vendor: DeviceVendor.fromDbValue(map['vendor'] as String),
      ratedWatts: (map['rated_watts'] as num?)?.toDouble() ?? 0.0,
      currentLevelPercent:
          (map['current_level_percent'] as num?)?.toDouble() ?? 100.0,
      isOn: (map['is_on'] as int? ?? 0) == 1,
      livePowerWatts: (map['live_power_watts'] as num?)?.toDouble(),
      metadata: parsedMeta,
      updatedAtMs: (map['updated_at_ms'] as int?) ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }
}
