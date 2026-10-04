# OmniaEnergy ⚡🏡
**Universal, Privacy-First Smart Home Energy & Bill Disaggregation for Android**

[![Release](https://img.shields.io/badge/Release-v1.0.0-emerald.svg)](https://github.com/mahiccc/omnia-energy/releases)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android_8.0+-orange.svg)](https://developer.android.com)
[![Privacy](https://img.shields.io/badge/Privacy-100%25_On--Device_Local-brightgreen.svg)](#privacy--data-sovereignty)

OmniaEnergy is a modern, zero-backend, privacy-first smart home energy monitoring and bill disaggregation app for Android. It bridges the gap between whole-home utility meters and individual appliances, giving homeowners around the world complete transparency over where their electricity and money go.

All telemetry ingestion, HMAC-SHA256 signature generation, disaggregation math, on-device Edge AI inference, and SQLite buffering run **100% locally on your smartphone**, with optional direct backup to your personal Google Drive.

---

## ✨ Key Features

### ⚡ Live Whole-Home Energy & CT Disaggregation
* **Dual-Channel CT Clamp Ingestion:** Real-time polling of whole-home current transformer (CT) meters (e.g., Tuya PJ-1103A, Shelly EM, Emporia Vue, ESPHome) for Phase A & B Watts, RMS Voltage, Power Factor, and cumulative kWh.
* **Intelligent Mathematical Disaggregation:** Separates total grid draw into active switched appliances, continuous baseline loads, and residual unmonitored circuits.
  $$\text{Active Watts } (P_t) = P_{\text{rated}} \times \left(\frac{\text{Current Level}}{100}\right) \times \text{State}$$
  $$P_{\text{Residual}} = P_{\text{CT}} - \left(\sum P_{\text{Native}} + \sum P_{\text{Virtual}}\right)$$
* **Virtual Power Synthesis:** Accurately models real-time burn rate and hourly costs even without a physical CT clamp by summing active switched loads and baseline baseload.

---

### 🧠 On-Device "Ask Omnia" Edge AI
* **Natural Language Queries:** Ask questions about your home in plain English:
  * *"Which switches are currently turned on?"*
  * *"Which appliance is consuming the highest power right now?"*
  * *"What is the wattage of my Kitchen Refrigerator?"*
  * *"What are my miscellaneous unmonitored loads?"*
* **100% Local Inference:** Operates completely on-device without sending your personal home data or questions to remote cloud LLMs. Zero latency, zero external API costs, and full offline availability.

---

### 🤖 Autonomous Whole-Home CT Auto-Sweep & Calibration
* **Autonomous Circuit Calibration:** Sequentially cycles each switched circuit across your home, measures the real-time delta jump on your main CT clamp, and automatically saves calibrated physical wattages to local memory.
* **House State Guard:** Takes a snapshot of all home switches prior to calibration and automatically restores every switch to its exact pre-sweep state once calibration completes.
* **Guided 2-Step Interactive Learner:** Manually train any appliance by comparing baseline CT load before and after switching on the device.

---

### 🔌 Miscellaneous & Baseload Loads Configurator
* **Interactive Residual Reconciliation:** Customize and select all unmonitored baseload appliances in your home (Wi-Fi router, TV standby, water purifier / RO, phone chargers, smart doorbell/CCTV, microwave clock, custom appliances).
* **Live Reconcile Meter:** Compares configured miscellaneous wattage against real-time CT residual delta to pinpoint unexplained phantom loads.

---

### 🧊 Accurate Single Refrigerator Modeling
* **Inverter Frost-Free Baseline:** Dedicated continuous baseline calculation for your primary refrigerator (e.g., 160W rated with 35% duty cycle = 56W continuous baseline), preventing double-counting while maintaining 24×7 energy tracking.

---

### 🧾 Electricity Bill Auditor & Meter Scanner
* **Optical Meter Scanner:** Scan physical utility LCD meters or paper electricity bills using OCR, or enter tariff readings manually.
* **Universal Slab Tariff Engine:** Computes utility bills across tiered slab rates (e.g., ₹0–100 units, ₹101–200 units), fixed charges, fuel cost adjustments, and taxes.
* **Government Subsidy Calculations:** Built-in support for energy subsidy schemes (such as Karnataka Gruha Jyothi / Gruha Lakshmi 60–200 unit quotas), forecasting net payable amounts in real-time.

---

### 🌐 Universal Multi-Protocol Connectors
OmniaEnergy supports universal hardware protocols right out of the box:
* **Tuya & Smart Life OpenAPI:** Direct HMAC-SHA256 authenticated REST polling for switches, sockets, and CT clamps.
* **Shelly & ESPHome LAN:** Direct local network polling without cloud dependency.
* **Atomberg Smart BLDC Fans:** Native speed-to-wattage profile mapping (Speeds 1–6: 3.5W – 28W).
* **Bosch / Siemens Home Connect:** Dishwashers, washing machines, and ovens.
* **Built-In Showcase Demo Mode:** Try out the complete multi-room experience immediately without any physical hardware.

---

## 🔒 Privacy & Data Sovereignty

* **Zero Application Servers:** OmniaEnergy has no central backend servers or analytics trackers.
* **Local Sandboxed Storage:** All credentials (API client IDs, secrets), device configurations, room mappings, and historical telemetry are stored exclusively inside your Android device's private SQLite database and encrypted storage.
* **Direct Cloud Backup:** Optional one-tap export to your personal Google Drive account in open CSV/JSON formats.

---

## 📱 Installation & Setup

### Option 1: Install Pre-Built APK via ADB

```bash
# Connect your Android phone with USB Debugging enabled
adb install -r releases/OmniaEnergy-v1.0.0.apk
```

### Option 2: Build & Install from Source

```bash
# Build standalone APK and install directly to connected device
./build_and_install_apk.sh 1.0.0

# Build signed Android App Bundle (.aab) for Google Play Console distribution
./build_release_bundle.sh 1.0.0
```

---

## 🛠️ Project Structure

```text
omnia_energy/
├── apk-build/               # Native Android WebView shell & Web assets
│   ├── assets/index.html    # Core SPA (Engine, Edge AI, UI, Math, SQLite bridge)
│   ├── src/                 # Native Android Java wrapper & SQLite helper
│   ├── AndroidManifest.xml  # Android manifest & hardware permissions
│   └── debug.keystore       # Build signing keystore
├── store_assets/            # Google Play Store listing & graphic assets
│   ├── STORE_LISTING.md     # Store description, tags & policy declarations
│   ├── icon_512.png         # 512x512 High-res app icon
│   ├── feature_graphic.png  # 1024x500 Feature graphic banner
│   └── screenshots/         # Verified on-device Play Store screenshots
├── docs/                    # Public documentation & GitHub Pages privacy policy
│   ├── privacy-policy.html  # Official public privacy policy
│   └── index.html           # GitHub Pages root
├── build_and_install_apk.sh # One-command APK builder & ADB installer
├── build_release_bundle.sh  # One-command signed .AAB release builder
└── README.md                # Project documentation
```

---

## 📄 License & Disclaimer

* **License:** Distributed under the [MIT License](LICENSE).
* **Disclaimer:** OmniaEnergy is an independent smart home energy monitoring and analytics tool. It is not affiliated with, endorsed by, or connected to any government electricity distribution board or utility company. Tariff calculations are estimates provided for household budgeting and energy conservation purposes.
