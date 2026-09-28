# OmniaEnergy ⚡🏡

**Serverless & Universal Home Energy Analytics for Android**

OmniaEnergy is a zero-backend, privacy-first Smart Home Energy & Bill Disaggregation app for Android. All telemetry ingestion, HMAC-SHA256 signing, disaggregation math, and offline SQLite buffering run **100% locally on your phone**, with optional direct backup to your personal Google Drive (`OmniaEnergy_Master_Telemetry`).

---

## Key Features

- **⚡ Live Main CT Clamp & Dual-Phase Metering:** Real-time polling of Tuya PJ-1103A Dual-Channel CT Clamp Meters (`/v2.0/cloud/thing/{id}/shadow/properties`) for Phase A & Phase B Watts, RMS Voltage, Frequency, and cumulative kWh.
- **🛋️ 29 Real-Time Room Switch Gangs & Two-Way Control:** Live status sync across all room switches plus instant physical switch ON/OFF control directly from the app.
- **🌀 Atomberg BLDC Smart Fan Connector:** Native integration with `api.developer.atomberg-iot.com` mapping Speeds 1–6 (`3.5W – 28W`) to real-time power draw.
- **🧮 Disaggregation & Virtual Payload Engine:**
  $$\text{Active Watts } (P_t) = P_{\text{rated}} \times \left(\frac{\text{Current Level}}{100}\right) \times \text{State}$$
  $$P_{\text{Residual}} = P_{\text{CT}} - \left(\sum P_{\text{Native}} + \sum P_{\text{Virtual}}\right)$$
- **🗄️ Local SQLite Offline Buffer (`omnia_energy_local.db`):** Automatic local persistence (`local_telemetry_buffer`) with one-tap Google Drive backup, Excel/CSV report export, and WhatsApp bill summary sharing.

---

## Releases

| Tag | APK | Highlights |
| :--- | :--- | :--- |
| `v0.4.0-live` | `releases/OmniaEnergy-v0.4.0-live.apk` | Live auto-sync with Tuya Cloud, two-way physical switch control, and dedicated **Connectors** tab (Tuya, Atomberg, Google Drive) |
| `v0.3.0-analytics` | `releases/OmniaEnergy-v0.3.0-analytics.apk` | 1-second runtime & ₹ counter per appliance, 7-day & monthly BESCOM bill charts, Excel CSV export, and native Android Share sheet |
| `v0.2.0-home` | `releases/OmniaEnergy-v0.2.0-home.apk` | Homeowner-friendly UI with room filters, ₹/hr burn rate, fan speed steps, and smart money-saving tips |
| `v0.1.0-mvp` | `releases/OmniaEnergy-v0.1.0-mvp.apk` | Initial MVP with radial load gauge, disaggregation math engine, native SQLite helper, and on-device Tuya HMAC-SHA256 |

---

## Build & Install via ADB

```bash
./build_and_install_apk.sh 0.4.0-live
```
