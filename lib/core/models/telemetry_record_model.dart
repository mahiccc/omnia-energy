import 'dart:convert';

/// Synchronization status of a buffered telemetry record in `local_telemetry_buffer`.
enum TelemetrySyncStatus {
  pending('PENDING'),
  inFlight('IN_FLIGHT'),
  synced('SYNCED'),
  failed('FAILED');

  final String dbValue;
  const TelemetrySyncStatus(this.dbValue);

  static TelemetrySyncStatus fromDbValue(String value) {
    return TelemetrySyncStatus.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => TelemetrySyncStatus.pending,
    );
  }
}

/// Represents a single disaggregated telemetry snapshot stored in `local_telemetry_buffer`
/// and queued for direct client-to-Drive synchronization into
/// `OmniaEnergy_Master_Telemetry`.
///
/// Follows the core CT Disaggregation Math:
/// $$P_{\text{Residual}} = P_{\text{CT}} - \left(\sum P_{\text{Native}} + \sum P_{\text{Virtual}}\right)$$
class TelemetryRecordModel {
  final int? id;
  final int timestampMs;

  /// Main Hardware CT Clamp reading (P_CT in Watts).
  final double pCtWatts;

  /// Sum of all Native Metering devices (∑ P_Native in Watts).
  final double pNativeSumWatts;

  /// Sum of all Virtual Payload devices (∑ P_Virtual in Watts).
  final double pVirtualSumWatts;

  /// Unmonitored Residual load: P_CT - (∑ P_Native + ∑ P_Virtual).
  final double pResidualWatts;

  /// Per-device active wattage snapshot (`{deviceId: activeWatts}`).
  final Map<String, double> deviceBreakdownWatts;

  /// Current synchronization state for the Google Drive Sync Engine.
  final TelemetrySyncStatus syncStatus;

  /// Number of failed sync attempts.
  final int retryCount;

  /// Epoch milliseconds when this record was successfully flushed to Google Sheets.
  final int? syncedAtMs;

  const TelemetryRecordModel({
    this.id,
    required this.timestampMs,
    required this.pCtWatts,
    required this.pNativeSumWatts,
    required this.pVirtualSumWatts,
    required this.pResidualWatts,
    this.deviceBreakdownWatts = const {},
    this.syncStatus = TelemetrySyncStatus.pending,
    this.retryCount = 0,
    this.syncedAtMs,
  });

  /// Factory that computes [pResidualWatts] directly from [pCtWatts],
  /// [pNativeSumWatts], and [pVirtualSumWatts] using:
  /// `P_Residual = P_CT - (∑P_Native + ∑P_Virtual)`
  factory TelemetryRecordModel.fromDisaggregation({
    int? id,
    required int timestampMs,
    required double pCtWatts,
    required double pNativeSumWatts,
    required double pVirtualSumWatts,
    Map<String, double> deviceBreakdownWatts = const {},
    bool clampNegativeResidual = true,
  }) {
    final rawResidual = pCtWatts - (pNativeSumWatts + pVirtualSumWatts);
    final residual = clampNegativeResidual
        ? (rawResidual < 0.0 ? 0.0 : rawResidual)
        : rawResidual;

    return TelemetryRecordModel(
      id: id,
      timestampMs: timestampMs,
      pCtWatts: pCtWatts,
      pNativeSumWatts: pNativeSumWatts,
      pVirtualSumWatts: pVirtualSumWatts,
      pResidualWatts: residual,
      deviceBreakdownWatts: deviceBreakdownWatts,
    );
  }

  /// Formats this record as a row for appending to the Google Sheet
  /// `OmniaEnergy_Master_Telemetry`.
  List<Object?> toGoogleSheetRow() {
    return [
      DateTime.fromMillisecondsSinceEpoch(timestampMs, isUtc: true)
          .toIso8601String(),
      timestampMs,
      pCtWatts.toStringAsFixed(2),
      pNativeSumWatts.toStringAsFixed(2),
      pVirtualSumWatts.toStringAsFixed(2),
      pResidualWatts.toStringAsFixed(2),
      jsonEncode(deviceBreakdownWatts),
    ];
  }

  Map<String, Object?> toSqlMap() {
    return {
      if (id != null) 'id': id,
      'timestamp_ms': timestampMs,
      'p_ct_watts': pCtWatts,
      'p_native_sum_watts': pNativeSumWatts,
      'p_virtual_sum_watts': pVirtualSumWatts,
      'p_residual_watts': pResidualWatts,
      'device_breakdown_json': jsonEncode(deviceBreakdownWatts),
      'sync_status': syncStatus.dbValue,
      'retry_count': retryCount,
      'synced_at_ms': syncedAtMs,
    };
  }

  factory TelemetryRecordModel.fromSqlMap(Map<String, Object?> map) {
    final rawBreakdown = map['device_breakdown_json'] as String?;
    final Map<String, double> parsedBreakdown = {};
    if (rawBreakdown != null && rawBreakdown.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawBreakdown) as Map<String, dynamic>;
        decoded.forEach((key, value) {
          if (value is num) {
            parsedBreakdown[key] = value.toDouble();
          }
        });
      } catch (_) {}
    }

    return TelemetryRecordModel(
      id: map['id'] as int?,
      timestampMs: map['timestamp_ms'] as int,
      pCtWatts: (map['p_ct_watts'] as num).toDouble(),
      pNativeSumWatts: (map['p_native_sum_watts'] as num).toDouble(),
      pVirtualSumWatts: (map['p_virtual_sum_watts'] as num).toDouble(),
      pResidualWatts: (map['p_residual_watts'] as num).toDouble(),
      deviceBreakdownWatts: parsedBreakdown,
      syncStatus: TelemetrySyncStatus.fromDbValue(
        (map['sync_status'] as String?) ?? 'PENDING',
      ),
      retryCount: (map['retry_count'] as int?) ?? 0,
      syncedAtMs: map['synced_at_ms'] as int?,
    );
  }
}
