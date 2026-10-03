# Google Play Console — Store Listing & Submission Metadata

Use this document to copy-paste metadata directly into your [Google Play Console](https://play.google.com/console) dashboard when creating your app release.

---

## 🏷️ Basic App Information

* **App Name:** `OmniaEnergy: Home Energy AI` *(28 / 30 characters)*
* **Short Description:** `Smart home energy monitor with on-device Edge AI, CT clamp & bill auditor.` *(76 / 80 characters)*
* **Default Language:** `English (United States) — en-US`
* **App Category:** `Tools` or `House & Home`
* **Tags:** `Home automation`, `Energy management`, `Smart home`, `Electricity calculator`, `Internet of Things`

---

## 📝 Full Description (Copy & Paste to Play Console)

```text
OmniaEnergy is a privacy-first, serverless smart home energy monitor and intelligence hub. It bridges the gap between whole-home utility meters and individual appliances, giving you complete clarity over where your electricity goes.

⚡ LIVE WHOLE-HOME ENERGY & DISAGGREGATION
• Real-time monitoring of whole-home power draw via CT clamp energy meters.
• Intelligent load disaggregation: isolates base loads (refrigerators, network gear), high-power thermal appliances (geysers, ACs), and switched lighting.
• Virtual power synthesis: calculates real-time burn rate even without a CT meter by tracking switched circuits.

🧠 ON-DEVICE "ASK OMNIA" EDGE AI
• Ask natural questions about your home in plain English: "Which switches are turned on right now?", "Which device is consuming the most power?", "Is my TV running or in standby?"
• 100% On-Device Inference: Operates completely offline without sending your home telemetry or questions to external cloud LLMs. Zero latency, zero token costs.

🎯 CT CLAMP APPLIANCE WATTAGE LEARNER
• Guided 2-step calibration wizard: measures real delta wattage by comparing baseline CT load before and after turning on a switch.
• Locks physical wattage ratings into local memory, replacing generic assumptions with real-world electrical measurements.

🧾 ELECTRICITY BILL AUDITOR & METER SCANNER
• Scan paper bills or physical electricity meter LCD dials with camera OCR, or enter readings manually.
• Reconciles physical utility charges against Omnia-tracked consumption to calculate billing variances.
• Built-in slab tariff calculators and automatic government subsidy support (e.g. Karnataka Gruha Lakshmi / Gruha Jyothi 60–200 unit quotas).

🔒 100% SERVERLESS, DATA SOVEREIGN & PRIVATE
• Zero intermediate cloud servers: OmniaEnergy connects directly from your phone to your local LAN devices (Shelly, ESPHome) or manufacturer APIs (Tuya OpenAPI, Home Assistant).
• Credentials and historical logs are stored exclusively in your device's private sandboxed database.

⚠️ DISCLAIMER
OmniaEnergy is an independent home energy management and calculation tool. It is not affiliated with, authorized, or endorsed by any electricity distribution company (BESCOM, KPTCL) or government agency. Subsidy calculations are educational estimates based on publicly available tariff schedules.
```

---

## 🎨 Visual Assets Checklist (All Prepared in Repository)

| Play Console Field | Required Specs | Asset File Location |
|---|---|---|
| **App Icon** | 512 x 512 px, 32-bit PNG | `store_assets/icon_512.png` |
| **Feature Graphic** | 1024 x 500 px, 24-bit PNG | `store_assets/feature_graphic_1024x500.png` |
| **Screenshot 1** | Phone (min 1080px, 9:16) | `store_assets/screenshots/1_home_ct_disaggregation.png` |
| **Screenshot 2** | Phone (min 1080px, 9:16) | `store_assets/screenshots/2_edge_ai_assistant.png` |
| **Screenshot 3** | Phone (min 1080px, 9:16) | `store_assets/screenshots/3_rooms_and_appliances.png` |
| **Screenshot 4** | Phone (min 1080px, 9:16) | `store_assets/screenshots/4_ct_wattage_training.png` |
| **Screenshot 5** | Phone (min 1080px, 9:16) | `store_assets/screenshots/5_bill_auditor_subsidy.png` |

---

## 🔒 Policy & Form Responses in Play Console

### 1. Privacy Policy
* **URL:** `https://mahiccc.github.io/omnia-energy/privacy-policy.html`

### 2. Data Safety Form
* **Does your app collect or share any user data?** -> **No**
  *(All data remains on the user's device in private local SQLite storage).*
* **Is data encrypted in transit?** -> **Yes**
  *(Direct calls to external manufacturer APIs use HTTPS/TLS).*
* **Data deletion:** Provide link or note that user can purge all data via in-app "Reset All Data" or by uninstalling.

### 3. Government Apps Declaration
* **Is your app developed by or on behalf of a government agency?** -> **No**
  *(Acknowledge the disclaimer is included in the description and inside the app).*

### 4. Financial Features
* **Does the app offer financial loans, banking, or credit?** -> **No**
  *(Select "None of the above" — it is an energy meter utility calculator).*

### 5. Content Rating (IARC)
* Complete standard questionnaire: No violence, no adult content, no gambling.
* Expected Rating: **Everyone (3+) / PEGI 3**.

---

## 📦 Release Artifact for Play Console Upload

* **Upload File (Android App Bundle):**
  👉 `OmniaEnergy.aab` *(or `releases/OmniaEnergy-v1.0.0.aab`)*
* **Release Name:** `1.0.0`
* **Release Notes (en-US):**
```text
Initial production release of OmniaEnergy:
• Live CT clamp disaggregation & real-time home burn rate tracking.
• "Ask Omnia" On-Device Edge AI assistant for natural language queries.
• CT Smart Appliance Training & Wattage Learner.
• Electricity Bill Auditor & Meter Scanner with Karnataka 60-unit subsidy support.
• 100% serverless, private architecture.
```
