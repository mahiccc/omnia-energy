import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;

import '../database/telemetry_repository.dart';
import '../models/telemetry_record_model.dart';
import '../security/secure_key_store.dart';

/// Authenticated HTTP client wrapper injecting Google OAuth 2.0 headers.
class _GoogleAuthHttpClient extends http.BaseClient {
  final Map<String, String> _authHeaders;
  final http.Client _inner;

  _GoogleAuthHttpClient(this._authHeaders, [http.Client? inner])
      : _inner = inner ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_authHeaders);
    return _inner.send(request);
  }
}

/// Direct Client-to-Drive Sync Engine for OmniaEnergy.
///
/// Uses the Play Store-compliant `drive.file` OAuth scope to provision and append
/// disaggregated telemetry rows directly into `"OmniaEnergy_Master_Telemetry"`
/// in the user's personal Google Drive.
class GoogleSheetsSyncClient {
  static const String masterSpreadsheetTitle = 'OmniaEnergy_Master_Telemetry';
  static const String telemetryTabName = 'Telemetry_Log';
  static const String driveFileScope =
      'https://www.googleapis.com/auth/drive.file';

  final GoogleSignIn _googleSignIn;
  final SecureKeyStore _keyStore;
  final TelemetryRepository _telemetryRepository;

  GoogleSheetsSyncClient({
    GoogleSignIn? googleSignIn,
    required SecureKeyStore keyStore,
    required TelemetryRepository telemetryRepository,
  })  : _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: const [driveFileScope],
            ),
        _keyStore = keyStore,
        _telemetryRepository = telemetryRepository;

  /// Signs in silently or interactively with the `drive.file` scope.
  Future<GoogleSignInAccount?> ensureAuthenticated({
    bool interactiveFallback = true,
  }) async {
    GoogleSignInAccount? account = await _googleSignIn.signInSilently();
    if (account == null && interactiveFallback) {
      account = await _googleSignIn.signIn();
    }
    return account;
  }

  /// Resolves or creates the `"OmniaEnergy_Master_Telemetry"` spreadsheet in the
  /// user's Google Drive and caches its `spreadsheetId` in [SecureKeyStore].
  Future<String> resolveOrCreateMasterSheet(
    http.Client authenticatedClient,
  ) async {
    final cachedId = await _keyStore.getMasterSpreadsheetId();
    if (cachedId != null && cachedId.isNotEmpty) {
      return cachedId;
    }

    final driveApi = drive.DriveApi(authenticatedClient);
    final query = "name = '$masterSpreadsheetTitle' "
        "and mimeType = 'application/vnd.google-apps.spreadsheet' "
        "and trashed = false";

    final fileList = await driveApi.files.list(
      q: query,
      spaces: 'drive',
      $fields: 'files(id, name)',
    );

    if (fileList.files != null && fileList.files!.isNotEmpty) {
      final existingId = fileList.files!.first.id!;
      await _keyStore.saveMasterSpreadsheetId(existingId);
      return existingId;
    }

    // Create a new spreadsheet with header row
    final sheetsApi = sheets.SheetsApi(authenticatedClient);
    final created = await sheetsApi.spreadsheets.create(
      sheets.Spreadsheet(
        properties: sheets.SpreadsheetProperties(
          title: masterSpreadsheetTitle,
        ),
        sheets: [
          sheets.Sheet(
            properties: sheets.SheetProperties(
              title: telemetryTabName,
              gridProperties: sheets.GridProperties(frozenRowCount: 1),
            ),
          ),
        ],
      ),
    );

    final spreadsheetId = created.spreadsheetId!;
    await sheetsApi.spreadsheets.values.append(
      sheets.ValueRange(
        values: const [
          [
            'Timestamp_UTC',
            'Epoch_Ms',
            'P_CT_Watts',
            'P_Native_Sum_Watts',
            'P_Virtual_Sum_Watts',
            'P_Residual_Watts',
            'Device_Breakdown_JSON',
          ],
        ],
      ),
      spreadsheetId,
      '$telemetryTabName!A1:G1',
      valueInputOption: 'USER_ENTERED',
    );

    await _keyStore.saveMasterSpreadsheetId(spreadsheetId);
    return spreadsheetId;
  }

  /// Flushes a batch of pending records from `local_telemetry_buffer` to
  /// `"OmniaEnergy_Master_Telemetry"`.
  ///
  /// Returns the number of rows successfully synced.
  Future<int> syncPendingTelemetryBatch({
    int batchSize = 250,
    bool interactiveAuth = false,
  }) async {
    final List<TelemetryRecordModel> pending =
        await _telemetryRepository.fetchPendingSyncBatch(limit: batchSize);
    if (pending.isEmpty) return 0;

    final recordIds =
        pending.map((r) => r.id).whereType<int>().toList(growable: false);

    final account = await ensureAuthenticated(
      interactiveFallback: interactiveAuth,
    );
    if (account == null) {
      return 0;
    }

    final authHeaders = await account.authHeaders;
    final authClient = _GoogleAuthHttpClient(authHeaders);

    try {
      await _telemetryRepository.markBatchInFlight(recordIds);

      final spreadsheetId = await resolveOrCreateMasterSheet(authClient);
      final sheetsApi = sheets.SheetsApi(authClient);

      final rows = pending.map((r) => r.toGoogleSheetRow()).toList();
      await sheetsApi.spreadsheets.values.append(
        sheets.ValueRange(values: rows),
        spreadsheetId,
        '$telemetryTabName!A:G',
        valueInputOption: 'USER_ENTERED',
        insertDataOption: 'INSERT_ROWS',
      );

      await _telemetryRepository.markBatchSynced(recordIds);
      return pending.length;
    } catch (_) {
      await _telemetryRepository.markBatchFailed(recordIds);
      rethrow;
    } finally {
      authClient.close();
    }
  }
}
