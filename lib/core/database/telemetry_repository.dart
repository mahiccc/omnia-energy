import '../models/device_model.dart';
import '../models/telemetry_record_model.dart';
import 'sqlite_local_db.dart';

/// Repository contract for local device state and disaggregated telemetry storage.
abstract class TelemetryRepository {
  Future<void> saveDevice(DeviceModel device);
  Future<void> saveDevices(List<DeviceModel> devices);
  Future<List<DeviceModel>> fetchAllDevices();
  Future<List<DeviceModel>> fetchDevicesByCategory(DeviceCategory category);
  Future<void> removeDevice(String deviceId);

  Future<int> bufferTelemetryRecord(TelemetryRecordModel record);
  Future<TelemetryRecordModel?> fetchLatestTelemetry();
  Future<List<TelemetryRecordModel>> fetchPendingSyncBatch({int limit = 250});
  Future<void> markBatchInFlight(List<int> recordIds);
  Future<void> markBatchSynced(List<int> recordIds);
  Future<void> markBatchFailed(List<int> recordIds);
  Future<int> pruneOldSyncedRecords({Duration retention = const Duration(days: 14)});
}

/// Concrete SQLite implementation of [TelemetryRepository] backed by [SqliteLocalDb].
class SqliteTelemetryRepository implements TelemetryRepository {
  final SqliteLocalDb _localDb;

  SqliteTelemetryRepository({SqliteLocalDb? localDb})
      : _localDb = localDb ?? SqliteLocalDb.instance;

  @override
  Future<void> saveDevice(DeviceModel device) => _localDb.upsertDevice(device);

  @override
  Future<void> saveDevices(List<DeviceModel> devices) =>
      _localDb.upsertDevicesBatch(devices);

  @override
  Future<List<DeviceModel>> fetchAllDevices() => _localDb.getAllDevices();

  @override
  Future<List<DeviceModel>> fetchDevicesByCategory(DeviceCategory category) =>
      _localDb.getDevicesByCategory(category);

  @override
  Future<void> removeDevice(String deviceId) => _localDb.deleteDevice(deviceId);

  @override
  Future<int> bufferTelemetryRecord(TelemetryRecordModel record) =>
      _localDb.insertTelemetryRecord(record);

  @override
  Future<TelemetryRecordModel?> fetchLatestTelemetry() =>
      _localDb.getLatestTelemetryRecord();

  @override
  Future<List<TelemetryRecordModel>> fetchPendingSyncBatch({int limit = 250}) =>
      _localDb.getUnsyncedTelemetryBatch(limit: limit);

  @override
  Future<void> markBatchInFlight(List<int> recordIds) =>
      _localDb.markRecordsInFlight(recordIds);

  @override
  Future<void> markBatchSynced(List<int> recordIds) =>
      _localDb.markRecordsSynced(recordIds);

  @override
  Future<void> markBatchFailed(List<int> recordIds) =>
      _localDb.markRecordsFailed(recordIds);

  @override
  Future<int> pruneOldSyncedRecords({
    Duration retention = const Duration(days: 14),
  }) {
    final cutoffMs =
        DateTime.now().subtract(retention).millisecondsSinceEpoch;
    return _localDb.pruneSyncedTelemetry(olderThanMs: cutoffMs);
  }
}
