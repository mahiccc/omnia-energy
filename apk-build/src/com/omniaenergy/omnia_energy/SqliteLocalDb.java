package com.omniaenergy.omnia_energy;

import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteOpenHelper;

import java.io.File;

/**
 * Native Android SQLite helper implementing OmniaEnergy's local_telemetry_buffer
 * and devices schema on-device (Zero-Backend Data Sovereignty).
 */
public class SqliteLocalDb extends SQLiteOpenHelper {

    public static final String DATABASE_NAME = "omnia_energy_local.db";
    public static final int DATABASE_VERSION = 1;

    public static final String TABLE_DEVICES = "devices";
    public static final String TABLE_TELEMETRY_BUFFER = "local_telemetry_buffer";

    private final Context appContext;

    public SqliteLocalDb(Context context) {
        super(context, DATABASE_NAME, null, DATABASE_VERSION);
        this.appContext = context.getApplicationContext();
    }

    @Override
    public void onCreate(SQLiteDatabase db) {
        db.execSQL(
                "CREATE TABLE IF NOT EXISTS " + TABLE_DEVICES + " ("
                        + "device_id TEXT PRIMARY KEY, "
                        + "name TEXT NOT NULL, "
                        + "category TEXT NOT NULL, "
                        + "vendor TEXT NOT NULL, "
                        + "rated_watts REAL NOT NULL DEFAULT 0.0, "
                        + "current_level_percent REAL NOT NULL DEFAULT 100.0, "
                        + "is_on INTEGER NOT NULL DEFAULT 0, "
                        + "live_power_watts REAL, "
                        + "metadata_json TEXT NOT NULL DEFAULT '{}', "
                        + "updated_at_ms INTEGER NOT NULL"
                        + ")"
        );

        db.execSQL(
                "CREATE TABLE IF NOT EXISTS " + TABLE_TELEMETRY_BUFFER + " ("
                        + "id INTEGER PRIMARY KEY AUTOINCREMENT, "
                        + "timestamp_ms INTEGER NOT NULL, "
                        + "p_ct_watts REAL NOT NULL, "
                        + "p_native_sum_watts REAL NOT NULL, "
                        + "p_virtual_sum_watts REAL NOT NULL, "
                        + "p_residual_watts REAL NOT NULL, "
                        + "device_breakdown_json TEXT NOT NULL DEFAULT '{}', "
                        + "sync_status TEXT NOT NULL DEFAULT 'PENDING', "
                        + "retry_count INTEGER NOT NULL DEFAULT 0, "
                        + "synced_at_ms INTEGER"
                        + ")"
        );

        db.execSQL(
                "CREATE INDEX IF NOT EXISTS idx_telemetry_sync_status "
                        + "ON " + TABLE_TELEMETRY_BUFFER + " (sync_status, timestamp_ms ASC)"
        );

        db.execSQL(
                "CREATE INDEX IF NOT EXISTS idx_telemetry_timestamp "
                        + "ON " + TABLE_TELEMETRY_BUFFER + " (timestamp_ms DESC)"
        );
    }

    @Override
    public void onUpgrade(SQLiteDatabase db, int oldVersion, int newVersion) {
        onCreate(db);
    }

    public synchronized long insertTelemetryRecord(
            long timestampMs,
            double pCtWatts,
            double pNativeSumWatts,
            double pVirtualSumWatts,
            double pResidualWatts,
            String deviceBreakdownJson
    ) {
        SQLiteDatabase db = getWritableDatabase();
        ContentValues cv = new ContentValues();
        cv.put("timestamp_ms", timestampMs);
        cv.put("p_ct_watts", pCtWatts);
        cv.put("p_native_sum_watts", pNativeSumWatts);
        cv.put("p_virtual_sum_watts", pVirtualSumWatts);
        cv.put("p_residual_watts", pResidualWatts);
        cv.put("device_breakdown_json", deviceBreakdownJson == null ? "{}" : deviceBreakdownJson);
        cv.put("sync_status", "PENDING");
        cv.put("retry_count", 0);
        return db.insert(TABLE_TELEMETRY_BUFFER, null, cv);
    }

    public synchronized String getRecentTelemetryRecordsJson(int limit) {
        SQLiteDatabase db = getReadableDatabase();
        StringBuilder sb = new StringBuilder();
        sb.append("[");
        Cursor cursor = null;
        try {
            cursor = db.rawQuery(
                    "SELECT id, timestamp_ms, p_ct_watts, p_native_sum_watts, "
                            + "p_virtual_sum_watts, p_residual_watts, sync_status, "
                            + "retry_count, synced_at_ms "
                            + "FROM " + TABLE_TELEMETRY_BUFFER
                            + " ORDER BY timestamp_ms DESC LIMIT " + Math.max(1, Math.min(limit, 200)),
                    null
            );
            boolean first = true;
            while (cursor.moveToNext()) {
                if (!first) sb.append(",");
                first = false;
                long id = cursor.getLong(0);
                long ts = cursor.getLong(1);
                double pCt = cursor.getDouble(2);
                double pNat = cursor.getDouble(3);
                double pVirt = cursor.getDouble(4);
                double pRes = cursor.getDouble(5);
                String status = cursor.getString(6);
                int retries = cursor.getInt(7);
                long syncedAt = cursor.isNull(8) ? 0L : cursor.getLong(8);

                sb.append("{")
                        .append("\"id\":").append(id).append(",")
                        .append("\"timestampMs\":").append(ts).append(",")
                        .append("\"pCtWatts\":").append(String.format(java.util.Locale.US, "%.2f", pCt)).append(",")
                        .append("\"pNativeSumWatts\":").append(String.format(java.util.Locale.US, "%.2f", pNat)).append(",")
                        .append("\"pVirtualSumWatts\":").append(String.format(java.util.Locale.US, "%.2f", pVirt)).append(",")
                        .append("\"pResidualWatts\":").append(String.format(java.util.Locale.US, "%.2f", pRes)).append(",")
                        .append("\"syncStatus\":\"").append(escapeJson(status)).append("\",")
                        .append("\"retryCount\":").append(retries).append(",")
                        .append("\"syncedAtMs\":").append(syncedAt)
                        .append("}");
            }
        } catch (Exception ignored) {
        } finally {
            if (cursor != null) cursor.close();
        }
        sb.append("]");
        return sb.toString();
    }

    public synchronized String getDatabaseStatsJson() {
        SQLiteDatabase db = getReadableDatabase();
        int totalRows = queryScalarInt(db, "SELECT COUNT(*) FROM " + TABLE_TELEMETRY_BUFFER);
        int pendingRows = queryScalarInt(
                db,
                "SELECT COUNT(*) FROM " + TABLE_TELEMETRY_BUFFER + " WHERE sync_status = 'PENDING'"
        );
        int syncedRows = queryScalarInt(
                db,
                "SELECT COUNT(*) FROM " + TABLE_TELEMETRY_BUFFER + " WHERE sync_status = 'SYNCED'"
        );
        File dbFile = appContext.getDatabasePath(DATABASE_NAME);
        long bytes = (dbFile != null && dbFile.exists()) ? dbFile.length() : 0L;
        String path = (dbFile != null) ? dbFile.getAbsolutePath() : "";

        return "{"
                + "\"dbPath\":\"" + escapeJson(path) + "\","
                + "\"dbSizeBytes\":" + bytes + ","
                + "\"totalRows\":" + totalRows + ","
                + "\"pendingRows\":" + pendingRows + ","
                + "\"syncedRows\":" + syncedRows
                + "}";
    }

    public synchronized int markPendingRecordsSynced(int maxBatchSize) {
        SQLiteDatabase db = getWritableDatabase();
        long nowMs = System.currentTimeMillis();
        db.execSQL(
                "UPDATE " + TABLE_TELEMETRY_BUFFER
                        + " SET sync_status = 'SYNCED', synced_at_ms = " + nowMs
                        + " WHERE id IN ("
                        + "SELECT id FROM " + TABLE_TELEMETRY_BUFFER
                        + " WHERE sync_status = 'PENDING' ORDER BY timestamp_ms ASC LIMIT "
                        + Math.max(1, maxBatchSize)
                        + ")"
        );
        return queryScalarInt(
                db,
                "SELECT COUNT(*) FROM " + TABLE_TELEMETRY_BUFFER + " WHERE synced_at_ms = " + nowMs
        );
    }

    public synchronized int clearAllBufferRecords() {
        SQLiteDatabase db = getWritableDatabase();
        return db.delete(TABLE_TELEMETRY_BUFFER, null, null);
    }

    private int queryScalarInt(SQLiteDatabase db, String sql) {
        Cursor c = null;
        try {
            c = db.rawQuery(sql, null);
            if (c.moveToFirst()) {
                return c.getInt(0);
            }
        } catch (Exception ignored) {
        } finally {
            if (c != null) c.close();
        }
        return 0;
    }

    private static String escapeJson(String raw) {
        if (raw == null) return "";
        return raw.replace("\\", "\\\\").replace("\"", "\\\"");
    }
}
