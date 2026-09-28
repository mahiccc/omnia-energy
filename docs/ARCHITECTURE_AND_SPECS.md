# OmniaEnergy - System Architecture & Technical Specifications

## 1. Product Vision & Principles
- **Name:** OmniaEnergy (Serverless & Universal Energy Analytics)
- **Target Platform:** Flutter Android (Play Store Compliant)
- **Zero-Backend Constraint:** STRICTLY NO middleman backend servers or databases. All processing runs locally on the user's mobile device.
- **Data Sovereignty:** All telemetry and credentials exist only in local device memory/SQLite and the user's personal Google Drive.

## 2. Technical Stack
- **Framework:** Flutter (Dart)
- **Local Database:** `sqflite` (Encrypted/Local storage)
- **Secure Key Storage:** `flutter_secure_storage` (Android Keystore)
- **Cloud API Integration:** `googleapis` (`sheets/v4.dart` with `drive.file` OAuth scope)
- **Networking & HMAC:** `http`, `crypto`
- **Background Tasks:** `workmanager` (Periodic local syncs)

## 3. Core Engine Architecture
```text
[Hardware CT Clamps]  [Tuya OpenAPI]  [Google Home APIs]  [Atomberg BLE]
         |                 |                  |                |
         +-----------------+------------------+----------------+
                                   |
                         [Ingestion Engine]
                                   |
                  [Disaggregation & Math Engine]
               (P_Residual = P_CT - ∑P_Native - ∑P_Virtual)
                                   |
                  [SQLite Local Offline Buffer]
                                   |
            [Direct Client-to-Drive Sync Engine]
                                   |
        [User Google Drive: "OmniaEnergy_Master_Telemetry"]
```

## 4. Key Calculation Rules
- **Native Metering Pass-through:** If a device exposes power Data Points (DPs), take live Watts directly.
- **Virtual Payload Engine:**
  $$\text{Active Watts } (P_t) = P_{\text{rated}} \times \left(\frac{\text{Current Level}}{100}\right) \times \text{State}$$
- **CT Disaggregation Math:**
  $$P_{\text{Residual}} = P_{\text{CT}} - \left( \sum P_{\text{Native}} + \sum P_{\text{Virtual}} \right)$$
