import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/device_model.dart';
import '../models/telemetry_record_model.dart';

/// Singleton SQLite helper for OmniaEnergy's zero-backend local persistence.
///
/// Manages two core tables:
/// 1. `devices` — Hardware CT clamps, Native metering plugs, and Virtual payload devices.
/// 2. `local_telemetry_buffer` — Offline buffer storing disaggregated telemetry
///    (`P_CT`, `∑P_Native`, `∑P_Virtual`, `P_Residual`) until flushed to the user's
///    personal Google Drive spreadsheet (`OmniaEnergy_Master_Telemetry`).
class SqliteLocalDb {
  SqliteLocalDb._internal();
  static final SqliteLocalDb instance = SqliteLocalDb._internal();

  static const String _databaseName = 'omnia_energy_local.db';
  static const int _databaseVersion = 1;

  static const String tableDevices = 'devices';
  static const String tableTelemetryBuffer = 'local_telemetry_buffer';

  Database? _database;

  /// Returns an active [Database] instance, initializing the schema on first access.
  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbDirectory = await getDatabasesPath();
    final dbPath = p.join(dbDirectory, _databaseName);

    return openDatabase(
      dbPath,
      version: _databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Registered Devices Table (CT, Native, Virtual)
    await db.execute('''
      CREATE TABLE $tableDevices (
        device_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        vendor TEXT NOT NULL,
        rated_watts REAL NOT NULL DEFAULT 0.0,
        current_level_percent REAL NOT NULL DEFAULT 100.0,
        is_on INTEGER NOT NULL DEFAULT 0,
        live_power_watts REAL,
        metadata_json TEXT NOT NULL DEFAULT '{}',
        updated_at_ms INTEGER NOT NULL
      )
    ''');

    // 2. Local Telemetry Offline Buffer Table
    await db.execute('''
      CREATE TABLE $tableTelemetryBuffer (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp_ms INTEGER NOT NULL,
        p_ct_watts REAL NOT NULL,
        p_native_sum_watts REAL NOT NULL,
        p_virtual_sum_watts REAL NOT NULL,
        p_residual_watts REAL NOT NULL,
        device_breakdown_json TEXT NOT NULL DEFAULT '{}',
        sync_status TEXT NOT NULL DEFAULT 'PENDING',
        retry_count INTEGER NOT NULL DEFAULT 0,
        synced_at_ms INTEGER
      )
    ''');

    // Indexes for rapid batch sync queries and time-series lookups
    await db.execute('''
      CREATE INDEX idx_telemetry_sync_status
      ON $tableTelemetryBuffer (sync_status, timestamp_ms ASC)
    ''');

    await db.execute('''
      CREATE INDEX idx_telemetry_timestamp
      ON $tableTelemetryBuffer (timestamp_ms DESC)
    ''');
  }

  // ===========================================================================
  // Device Operations
  // ===========================================================================

  /// Inserts or updates a [DeviceModel] in the `devices` table.
  Future<void> upsertDevice(DeviceModel device) async {
    final db = await database;
    await db.insert(
      tableDevices,
      device.toSqlMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Inserts or updates multiple [DeviceModel] instances in a single batch transaction.
  Future<void> upsertDevicesBatch(List<DeviceModel> devices) async {
    if (devices.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final device in devices) {
      batch.insert(
        tableDevices,
        device.toSqlMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Fetches all registered devices ordered by category and name.
  Future<List<DeviceModel>> getAllDevices() async {
    final db = await database;
    final rows = await db.query(
      tableDevices,
      orderBy: 'category ASC, name ASC',
    );
    return rows.map(DeviceModel.fromSqlMap).toList();
  }

  /// Fetches devices filtered by [DeviceCategory].
  Future<List<DeviceModel>> getDevicesByCategory(
    DeviceCategory category,
  ) async {
    final db = await database;
    final rows = await db.query(
      tableDevices,
      where: 'category = ?',
      whereArgs: [category.dbValue],
      orderBy: 'name ASC',
    );
    return rows.map(DeviceModel.fromSqlMap).toList();
  }

  /// Deletes a device by [deviceId].
  Future<int> deleteDevice(String deviceId) async {
    final db = await database;
    return db.delete(
      tableDevices,
      where: 'device_id = ?',
      whereArgs: [deviceId],
    );
  }

  // ===========================================================================
  // Local Telemetry Buffer Operations
  // ===========================================================================

  /// Appends a disaggregated [TelemetryRecordModel] into `local_telemetry_buffer`.
  Future<int> insertTelemetryRecord(TelemetryRecordModel record) async {
    final db = await database;
    return db.insert(
      tableTelemetryBuffer,
      record.toSqlMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieves up to [limit] unsynced records (`PENDING` or `FAILED` below [maxRetries])
  /// ordered chronologically for batch upload to Google Sheets.
  Future<List<TelemetryRecordModel>> getUnsyncedTelemetryBatch({
    int limit = 250,
    int maxRetries = 5,
  }) async {
    final db = await database;
    final rows = await db.query(
      tableTelemetryBuffer,
      where: "(sync_status = ? OR sync_status = ?) AND retry_count < ?",
      whereArgs: [
        TelemetrySyncStatus.pending.dbValue,
        TelemetrySyncStatus.failed.dbValue,
        maxRetries,
      ],
      orderBy: 'timestamp_ms ASC',
      limit: limit,
    );
    return rows.map(TelemetryRecordModel.fromSqlMap).toList();
  }

  /// Marks a batch of record [ids] as `IN_FLIGHT` prior to executing the Google Sheets
  /// network call.
  Future<void> markRecordsInFlight(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.rawUpdate(
      '''
      UPDATE $tableTelemetryBuffer
      SET sync_status = ?
      WHERE id IN ($placeholders)
      ''',
      [TelemetrySyncStatus.inFlight.dbValue, ...ids],
    );
  }

  /// Marks a batch of record [ids] as `SYNCED` once confirmed written to
  /// `OmniaEnergy_Master_Telemetry`.
  Future<void> markRecordsSynced(List<int> ids, {int? syncedAtMs}) async {
    if (ids.isEmpty) return;
    final db = await database;
    final nowMs = syncedAtMs ?? DateTime.now().millisecondsSinceEpoch;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.rawUpdate(
      '''
      UPDATE $tableTelemetryBuffer
      SET sync_status = ?, synced_at_ms = ?
      WHERE id IN ($placeholders)
      ''',
      [TelemetrySyncStatus.synced.dbValue, nowMs, ...ids],
    );
  }

  /// Marks a batch of record [ids] as `FAILED` and increments `retry_count` when
  /// a network or quota error occurs.
  Future<void> markRecordsFailed(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.rawUpdate(
      '''
      UPDATE $tableTelemetryBuffer
      SET sync_status = ?, retry_count = retry_count + 1
      WHERE id IN ($placeholders)
      ''',
      [TelemetrySyncStatus.failed.dbValue, ...ids],
    );
  }

  /// Fetches the most recent disaggregated telemetry record for live UI rendering.
  Future<TelemetryRecordModel?> getLatestTelemetryRecord() async {
    final db = await database;
    final rows = await db.query(
      tableTelemetryBuffer,
      orderBy: 'timestamp_ms DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return TelemetryRecordModel.fromSqlMap(rows.first);
  }

  /// Prunes already-synced telemetry records older than [olderThanMs] to bound
  /// on-device storage growth.
  Future<int> pruneSyncedTelemetry({required int olderThanMs}) async {
    final db = await database;
    return db.delete(
      tableTelemetryBuffer,
      where: 'sync_status = ? AND timestamp_ms < ?',
      whereArgs: [TelemetrySyncStatus.synced.dbValue, olderThanMs],
    );
  }

  /// Closes the active SQLite database connection.
  Future<void> close() async {
    final db = _database;
    if (db != null && db.isOpen) {
      await db.close();
      _database = null;
    }
  }
}
