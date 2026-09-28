import '../database/telemetry_repository.dart';
import '../models/device_model.dart';
import '../models/telemetry_record_model.dart';

/// Result snapshot produced by a single execution of [DisaggregationUseCase].
class DisaggregationSnapshot {
  final TelemetryRecordModel record;
  final List<DeviceModel> ctDevices;
  final List<DeviceModel> nativeDevices;
  final List<DeviceModel> virtualDevices;

  const DisaggregationSnapshot({
    required this.record,
    required this.ctDevices,
    required this.nativeDevices,
    required this.virtualDevices,
  });
}

/// Core Disaggregation & Math Engine for OmniaEnergy (Task 4).
///
/// Implements the Section 4 Key Calculation Rules:
/// 1. **Native Metering Pass-through:** Takes live Watts directly from devices
///    exposing power Data Points (`DeviceCategory.nativeMetering`).
/// 2. **Virtual Payload Engine:**
///    `Active Watts (P_t) = P_rated * (Current Level / 100) * State`
/// 3. **CT Disaggregation Math:**
///    `P_Residual = P_CT - (∑P_Native + ∑P_Virtual)`
class DisaggregationUseCase {
  final TelemetryRepository _repository;

  const DisaggregationUseCase({
    required TelemetryRepository repository,
  }) : _repository = repository;

  /// Computes the disaggregated household load across [devices] (or loads them
  /// from [TelemetryRepository] if omitted) and persists the resulting
  /// [TelemetryRecordModel] into `local_telemetry_buffer`.
  Future<DisaggregationSnapshot> execute({
    List<DeviceModel>? devices,
    int? timestampMs,
    bool clampNegativeResidual = true,
    bool persistToBuffer = true,
  }) async {
    final allDevices = devices ?? await _repository.fetchAllDevices();
    final nowMs = timestampMs ?? DateTime.now().millisecondsSinceEpoch;

    final ctDevices = <DeviceModel>[];
    final nativeDevices = <DeviceModel>[];
    final virtualDevices = <DeviceModel>[];
    final deviceBreakdown = <String, double>{};

    double pCtWatts = 0.0;
    double pNativeSumWatts = 0.0;
    double pVirtualSumWatts = 0.0;

    for (final device in allDevices) {
      final watts = device.activeWatts;
      deviceBreakdown[device.id] = watts;

      switch (device.category) {
        case DeviceCategory.ctClamp:
          ctDevices.add(device);
          pCtWatts += watts;
          break;
        case DeviceCategory.nativeMetering:
          nativeDevices.add(device);
          pNativeSumWatts += watts;
          break;
        case DeviceCategory.virtualPayload:
          virtualDevices.add(device);
          pVirtualSumWatts += watts;
          break;
      }
    }

    final baseRecord = TelemetryRecordModel.fromDisaggregation(
      timestampMs: nowMs,
      pCtWatts: pCtWatts,
      pNativeSumWatts: pNativeSumWatts,
      pVirtualSumWatts: pVirtualSumWatts,
      deviceBreakdownWatts: deviceBreakdown,
      clampNegativeResidual: clampNegativeResidual,
    );

    int? insertedId;
    if (persistToBuffer) {
      insertedId = await _repository.bufferTelemetryRecord(baseRecord);
    }

    final persistedRecord = TelemetryRecordModel(
      id: insertedId,
      timestampMs: baseRecord.timestampMs,
      pCtWatts: baseRecord.pCtWatts,
      pNativeSumWatts: baseRecord.pNativeSumWatts,
      pVirtualSumWatts: baseRecord.pVirtualSumWatts,
      pResidualWatts: baseRecord.pResidualWatts,
      deviceBreakdownWatts: baseRecord.deviceBreakdownWatts,
      syncStatus: baseRecord.syncStatus,
      retryCount: baseRecord.retryCount,
      syncedAtMs: baseRecord.syncedAtMs,
    );

    return DisaggregationSnapshot(
      record: persistedRecord,
      ctDevices: ctDevices,
      nativeDevices: nativeDevices,
      virtualDevices: virtualDevices,
    );
  }
}
