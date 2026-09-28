package com.omniaenergy.omnia_energy;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.os.Bundle;
import android.os.Vibrator;
import android.view.KeyEvent;
import android.view.Window;
import android.webkit.JavascriptInterface;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Arrays;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

/**
 * OmniaEnergy v0.3.0-analytics MainActivity
 *
 * Bridges the Homeowner Smart Energy UI with:
 * 1. Real Android SQLite (`omnia_energy_local.db` -> `local_telemetry_buffer`)
 * 2. Real On-Device HMAC-SHA256 Tuya OpenAPI v2.0 Client (`TuyaOpenApiClient`)
 * 3. Direct Client-to-Drive Sync (`OmniaEnergy_Master_Telemetry`)
 * 4. One-Tap Excel/CSV Bill Report Export & Native Android Share Sheet
 */
public class MainActivity extends Activity {

    private WebView webView;
    private SqliteLocalDb sqliteLocalDb;
    private SharedPreferences securePrefs;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        requestWindowFeature(Window.FEATURE_NO_TITLE);

        sqliteLocalDb = new SqliteLocalDb(this);
        securePrefs = getSharedPreferences("omnia_energy_keystore_prefs", Context.MODE_PRIVATE);

        webView = new WebView(this);
        webView.setBackgroundColor(Color.parseColor("#070B12"));

        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setDatabaseEnabled(true);
        settings.setAllowFileAccess(true);
        settings.setAllowContentAccess(true);
        settings.setLoadWithOverviewMode(true);
        settings.setUseWideViewPort(true);

        webView.setWebViewClient(new WebViewClient());
        webView.setWebChromeClient(new WebChromeClient());
        webView.addJavascriptInterface(
                new OmniaNativeBridge(this, sqliteLocalDb, securePrefs),
                "OmniaNative"
        );

        setContentView(webView);
        webView.loadUrl("file:///android_asset/index.html");
    }

    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event) {
        if (keyCode == KeyEvent.KEYCODE_BACK && webView != null && webView.canGoBack()) {
            webView.goBack();
            return true;
        }
        return super.onKeyDown(keyCode, event);
    }

    @Override
    protected void onDestroy() {
        if (sqliteLocalDb != null) {
            sqliteLocalDb.close();
        }
        super.onDestroy();
    }

    public static class OmniaNativeBridge {
        private final Context context;
        private final SqliteLocalDb db;
        private final SharedPreferences prefs;

        public OmniaNativeBridge(Context context, SqliteLocalDb db, SharedPreferences prefs) {
            this.context = context;
            this.db = db;
            this.prefs = prefs;
        }

        @JavascriptInterface
        public void hapticTick(int ms) {
            try {
                Vibrator v = (Vibrator) context.getSystemService(Context.VIBRATOR_SERVICE);
                if (v != null) {
                    v.vibrate(Math.max(10, Math.min(ms, 60)));
                }
            } catch (Exception ignored) {
            }
        }

        @JavascriptInterface
        public void saveSecurePref(String key, String value) {
            prefs.edit().putString(key, value).apply();
        }

        @JavascriptInterface
        public String getSecurePref(String key, String defaultValue) {
            return prefs.getString(key, defaultValue);
        }

        @JavascriptInterface
        public long insertTelemetryRecord(
                double pCtWatts,
                double pNativeSumWatts,
                double pVirtualSumWatts,
                double pResidualWatts,
                String breakdownJson
        ) {
            long ts = System.currentTimeMillis();
            return db.insertTelemetryRecord(
                    ts,
                    pCtWatts,
                    pNativeSumWatts,
                    pVirtualSumWatts,
                    pResidualWatts,
                    breakdownJson
            );
        }

        @JavascriptInterface
        public String getTelemetryBufferJson(int limit) {
            return db.getRecentTelemetryRecordsJson(limit);
        }

        @JavascriptInterface
        public String getDatabaseStatsJson() {
            return db.getDatabaseStatsJson();
        }

        @JavascriptInterface
        public int markBatchSynced(int batchSize) {
            return db.markPendingRecordsSynced(batchSize);
        }

        @JavascriptInterface
        public int clearTelemetryBuffer() {
            return db.clearAllBufferRecords();
        }

        /**
         * Exports a clean Excel-compatible CSV energy report to the phone's Downloads
         * folder (`/sdcard/Download/OmniaEnergy_Home_Report.csv`) and app storage.
         */
        @JavascriptInterface
        public String exportEnergyReportCsv(String csvContent) {
            String savedPath = "";
            try {
                File dlFile = new File("/sdcard/Download/OmniaEnergy_Home_Report.csv");
                FileOutputStream fos = new FileOutputStream(dlFile, false);
                fos.write(csvContent.getBytes(StandardCharsets.UTF_8));
                fos.flush();
                fos.close();
                savedPath = dlFile.getAbsolutePath();
            } catch (Exception ignored) {
            }
            try {
                File extDir = context.getExternalFilesDir(null);
                if (extDir != null) {
                    File extFile = new File(extDir, "OmniaEnergy_Home_Report.csv");
                    FileOutputStream efos = new FileOutputStream(extFile, false);
                    efos.write(csvContent.getBytes(StandardCharsets.UTF_8));
                    efos.flush();
                    efos.close();
                    if (savedPath.isEmpty()) {
                        savedPath = extFile.getAbsolutePath();
                    }
                }
            } catch (Exception ignored) {
            }
            try {
                File internalFile = new File(context.getFilesDir(), "OmniaEnergy_Home_Report.csv");
                FileOutputStream ifos = new FileOutputStream(internalFile, false);
                ifos.write(csvContent.getBytes(StandardCharsets.UTF_8));
                ifos.flush();
                ifos.close();
                if (savedPath.isEmpty()) {
                    savedPath = internalFile.getAbsolutePath();
                }
            } catch (Exception ignored) {
            }
            return savedPath;
        }

        /**
         * Launches the native Android Share Sheet so homeowners can share their
         * energy bill report via WhatsApp, Gmail, Google Drive, or Telegram.
         */
        @JavascriptInterface
        public void shareEnergySummaryText(String summaryText) {
            try {
                Intent sendIntent = new Intent(Intent.ACTION_SEND);
                sendIntent.setType("text/plain");
                sendIntent.putExtra(Intent.EXTRA_SUBJECT, "My Home Energy Report — OmniaEnergy");
                sendIntent.putExtra(Intent.EXTRA_TEXT, summaryText);
                Intent chooser = Intent.createChooser(sendIntent, "Share Home Energy Report");
                chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                context.startActivity(chooser);
            } catch (Exception ignored) {
            }
        }

        @JavascriptInterface
        public String tuyaSignedRequest(
                String endpoint,
                String clientId,
                String clientSecret,
                String accessToken,
                String method,
                String pathWithQuery,
                String body
        ) {
            try {
                String canonicalPath = canonicalizePath(pathWithQuery);
                String timestamp = String.valueOf(System.currentTimeMillis());
                String safeBody = body == null ? "" : body;
                String contentSha256 = sha256Hex(safeBody);

                String stringToSign = method.toUpperCase() + "\n"
                        + contentSha256 + "\n"
                        + "\n"
                        + canonicalPath;

                String signPayload = clientId
                        + (accessToken == null ? "" : accessToken)
                        + timestamp
                        + stringToSign;

                String sign = hmacSha256Upper(signPayload, clientSecret);

                URL url = new URL(endpoint + canonicalPath);
                HttpURLConnection conn = (HttpURLConnection) url.openConnection();
                conn.setRequestMethod(method.toUpperCase());
                conn.setConnectTimeout(8000);
                conn.setReadTimeout(8000);
                conn.setRequestProperty("client_id", clientId);
                if (accessToken != null && !accessToken.isEmpty()) {
                    conn.setRequestProperty("access_token", accessToken);
                }
                conn.setRequestProperty("sign", sign);
                conn.setRequestProperty("t", timestamp);
                conn.setRequestProperty("sign_method", "HMAC-SHA256");
                conn.setRequestProperty("Content-Type", "application/json; charset=utf-8");

                if ("POST".equalsIgnoreCase(method) && !safeBody.isEmpty()) {
                    conn.setDoOutput(true);
                    OutputStream os = conn.getOutputStream();
                    os.write(safeBody.getBytes(StandardCharsets.UTF_8));
                    os.flush();
                    os.close();
                }

                int code = conn.getResponseCode();
                InputStream is = (code >= 200 && code < 400) ? conn.getInputStream() : conn.getErrorStream();
                BufferedReader reader = new BufferedReader(new InputStreamReader(is, StandardCharsets.UTF_8));
                StringBuilder sb = new StringBuilder();
                String line;
                while ((line = reader.readLine()) != null) {
                    sb.append(line);
                }
                reader.close();
                return sb.toString();
            } catch (Exception e) {
                return "{\"success\":false,\"msg\":\"" + e.getMessage() + "\"}";
            }
        }

        @JavascriptInterface
        public String pushBatchToGoogleDrive(String driveEndpointUrl, String payloadJson, int batchSize) {
            try {
                if (driveEndpointUrl != null && !driveEndpointUrl.trim().isEmpty()) {
                    URL url = new URL(driveEndpointUrl.trim());
                    HttpURLConnection conn = (HttpURLConnection) url.openConnection();
                    conn.setRequestMethod("POST");
                    conn.setConnectTimeout(10000);
                    conn.setReadTimeout(10000);
                    conn.setInstanceFollowRedirects(true);
                    conn.setRequestProperty("Content-Type", "application/json; charset=utf-8");
                    conn.setDoOutput(true);
                    OutputStream os = conn.getOutputStream();
                    os.write(payloadJson.getBytes(StandardCharsets.UTF_8));
                    os.flush();
                    os.close();
                    int code = conn.getResponseCode();
                    if (code < 200 || code >= 400) {
                        return "{\"ok\":false,\"httpCode\":" + code + "}";
                    }
                }
                int syncedCount = db.markPendingRecordsSynced(batchSize);
                return "{\"ok\":true,\"syncedCount\":" + syncedCount + "}";
            } catch (Exception e) {
                return "{\"ok\":false,\"error\":\"" + e.getMessage() + "\"}";
            }
        }

        private static String canonicalizePath(String pathWithQuery) {
            if (pathWithQuery == null || !pathWithQuery.contains("?")) {
                return pathWithQuery == null ? "" : pathWithQuery;
            }
            int qIdx = pathWithQuery.indexOf('?');
            String path = pathWithQuery.substring(0, qIdx);
            String query = pathWithQuery.substring(qIdx + 1);
            if (query.isEmpty()) return path;
            String[] parts = query.split("&");
            Arrays.sort(parts);
            StringBuilder sb = new StringBuilder(path).append("?");
            for (int i = 0; i < parts.length; i++) {
                if (i > 0) sb.append("&");
                sb.append(parts[i]);
            }
            return sb.toString();
        }

        private static String sha256Hex(String input) throws Exception {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] digest = md.digest(input.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            for (byte b : digest) {
                sb.append(String.format("%02x", b));
            }
            return sb.toString();
        }

        private static String hmacSha256Upper(String message, String secret) throws Exception {
            Mac mac = Mac.getInstance("HmacSHA256");
            SecretKeySpec spec = new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256");
            mac.init(spec);
            byte[] raw = mac.doFinal(message.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            for (byte b : raw) {
                sb.append(String.format("%02X", b));
            }
            return sb.toString();
        }
    }
}
