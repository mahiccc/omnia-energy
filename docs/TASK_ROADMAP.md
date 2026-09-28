# OmniaEnergy - Agent Implementation Roadmap

## Task 1: Environment & Dependency Setup
- [x] Update `pubspec.yaml` with required dependencies: `sqflite`, `path`, `http`, `crypto`, `google_sign_in`, `googleapis`, `flutter_secure_storage`, `workmanager`.
- [x] Configure `android/app/src/main/AndroidManifest.xml` with permissions for Internet, Wi-Fi State, Change Wi-Fi State, and Bluetooth LE scanning.

## Task 2: Data Models & Local SQLite Database
- [x] Implement `DeviceModel` representing native, virtual, and CT devices.
- [x] Create `SqliteLocalDb` helper with schema for `local_telemetry_buffer`.
- [x] Create repository interfaces for local telemetry storage.

## Task 3: Client-Side Vendors & Signatures Engine
- [x] Implement `TuyaOpenApiClient` with client-side HMAC-SHA256 signature generation logic.
- [x] Implement `GoogleSheetsSyncClient` using `googleapis` with scope `drive.file`.

## Task 4: Disaggregation Engine
- [x] Write `DisaggregationUseCase` to process native reads, virtual payloads, and compute residual load against CT main clamp.

## Task 5: UI & Dashboard
- [x] Implement live gauge widget showing total household load.
- [x] Implement breakdown chart for Native vs. Virtual vs. Unmonitored Residual load.
