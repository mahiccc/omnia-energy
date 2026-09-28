import 'package:workmanager/workmanager.dart';

import '../clients/google_sheets_sync_client.dart';
import '../database/telemetry_repository.dart';
import '../security/secure_key_store.dart';
import 'disaggregation_use_case.dart';

const String kOmniaPeriodicSyncTask = 'com.omniaenergy.periodic_telemetry_sync';

/// Top-level WorkManager entrypoint for periodic local disaggregation and
/// Direct Client-to-Drive synchronization.
@pragma('vm:entry-point')
void omniaBackgroundCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      final repository = SqliteTelemetryRepository();
      final keyStore = const SecureKeyStore();

      // 1. Snapshot & disaggregate current device states into SQLite buffer
      final disaggregation = DisaggregationUseCase(repository: repository);
      await disaggregation.execute(persistToBuffer: true);

      // 2. Opportunistically flush pending SQLite records to Google Drive
      final syncClient = GoogleSheetsSyncClient(
        keyStore: keyStore,
        telemetryRepository: repository,
      );
      await syncClient.syncPendingTelemetryBatch(
        batchSize: 250,
        interactiveAuth: false,
      );

      // 3. Prune synced records older than 14 days
      await repository.pruneOldSyncedRecords();
      return true;
    } catch (_) {
      return false;
    }
  });
}
