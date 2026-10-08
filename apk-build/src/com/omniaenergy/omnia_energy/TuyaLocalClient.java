package com.omniaenergy.omnia_energy;

import android.util.Log;

import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Arrays;
import java.util.zip.CRC32;
import javax.crypto.Cipher;
import javax.crypto.spec.SecretKeySpec;

/**
 * High-performance, zero-dependency Tuya Local Protocol v3.3 & v3.4 TCP Client.
 * Queries dual-clamp CT meters directly over LAN in ~50ms without cloud latency.
 */
public class TuyaLocalClient {

    private static final String TAG = "TuyaLocalClient";
    private static final byte[] PREFIX = new byte[]{0x00, 0x00, 0x55, (byte) 0xAA};
    private static final byte[] SUFFIX = new byte[]{0x00, 0x00, (byte) 0xAA, 0x55};

    private static final int CMD_DP_QUERY = 0x0A; // 10
    private static final int CMD_STATUS = 0x08;   // 8
    private static final int CMD_HEARTBEAT = 0x09;// 9

    /**
     * Fetch status dictionary from a local Tuya device over LAN TCP socket.
     *
     * @param devId    Tuya device ID (gwId)
     * @param localKey 16-byte local key provisioned by Tuya Cloud
     * @param ip       Local IP address (e.g. "192.168.29.83")
     * @param version  "3.3" or "3.4"
     * @param timeoutMs Socket timeout in milliseconds (e.g. 1500)
     * @return JSON string of device status, e.g. {"dps":{"101":1181,"105":1086,"115":2267,...}}
     */
    public static String getDeviceStatusSync(String devId, String localKey, String ip, String version, int timeoutMs) {
        if (ip == null || ip.isEmpty() || devId == null || devId.isEmpty() || localKey == null || localKey.length() < 16) {
            return "{\"error\":\"Invalid device parameters\"}";
        }

        Socket socket = null;
        try {
            socket = new Socket();
            socket.connect(new InetSocketAddress(ip, 6668), timeoutMs);
            socket.setSoTimeout(timeoutMs);

            OutputStream out = socket.getOutputStream();
            InputStream in = socket.getInputStream();

            // Construct payload: {"gwId":"...","devId":"..."}
            String payloadStr = "{\"gwId\":\"" + devId + "\",\"devId\":\"" + devId + "\"}";
            byte[] payloadBytes = payloadStr.getBytes(StandardCharsets.UTF_8);

            byte[] keyBytes = localKey.substring(0, 16).getBytes(StandardCharsets.UTF_8);
            boolean isV34 = "3.4".equals(version);

            byte[] encryptedPayload;
            if (isV34) {
                // v3.4 payload: "3.4" (header) + 12 zero bytes + encrypted(payload)
                byte[] enc = encryptAesEcbPkcs7(payloadBytes, keyBytes);
                byte[] vHeader = new byte[15]; // "3.4" + 12 zeros = 3 + 12 = 15 bytes
                byte[] verBytes = "3.4".getBytes(StandardCharsets.UTF_8);
                System.arraycopy(verBytes, 0, vHeader, 0, verBytes.length);
                encryptedPayload = new byte[vHeader.length + enc.length];
                System.arraycopy(vHeader, 0, encryptedPayload, 0, vHeader.length);
                System.arraycopy(enc, 0, encryptedPayload, vHeader.length, enc.length);
            } else {
                // v3.3 payload: encrypted(payload) directly
                encryptedPayload = encryptAesEcbPkcs7(payloadBytes, keyBytes);
            }

            // Packet frame:
            // Prefix: 4 bytes (0x000055AA)
            // Seq: 4 bytes (0)
            // Cmd: 4 bytes (CMD_DP_QUERY = 10)
            // Length: 4 bytes (len(payload) + 8 for crc & suffix)
            // Payload: N bytes
            // CRC32: 4 bytes
            // Suffix: 4 bytes (0x0000AA55)
            int bodyLen = encryptedPayload.length + 8;
            byte[] frame = new byte[16 + encryptedPayload.length + 8];

            System.arraycopy(PREFIX, 0, frame, 0, 4);
            writeInt32(0, frame, 4); // seq
            writeInt32(CMD_DP_QUERY, frame, 8); // cmd
            writeInt32(bodyLen, frame, 12); // length
            System.arraycopy(encryptedPayload, 0, frame, 16, encryptedPayload.length);

            // Compute CRC over frame[0 .. 16 + payloadLen]
            CRC32 crc = new CRC32();
            crc.update(frame, 0, 16 + encryptedPayload.length);
            long crcVal = crc.getValue();
            writeInt32((int) crcVal, frame, 16 + encryptedPayload.length);
            System.arraycopy(SUFFIX, 0, frame, 16 + encryptedPayload.length + 4, 4);

            out.write(frame);
            out.flush();

            // Read response
            byte[] respHeader = new byte[16];
            int read = readFully(in, respHeader, 16);
            if (read < 16) {
                return "{\"error\":\"Truncated response header\"}";
            }

            if (respHeader[0] != 0x00 || respHeader[1] != 0x00 || respHeader[2] != 0x55 || respHeader[3] != (byte) 0xAA) {
                return "{\"error\":\"Invalid response magic prefix\"}";
            }

            int respLen = readInt32(respHeader, 12);
            if (respLen <= 0 || respLen > 65536) {
                return "{\"error\":\"Invalid response length: " + respLen + "\"}";
            }

            byte[] respBody = new byte[respLen];
            readFully(in, respBody, respLen);

            // Strip 8 bytes (CRC & Suffix)
            int encRespLen = respLen - 8;
            if (encRespLen <= 0) {
                return "{\"error\":\"Empty payload in response\"}";
            }

            byte[] encData = new byte[encRespLen];
            System.arraycopy(respBody, 0, encData, 0, encRespLen);

            // Handle retcode or v3.4 header offset
            int offset = 0;
            // Check for retcode: 4 bytes if retcode != 0
            if (encData.length >= 4) {
                int possibleRet = readInt32(encData, 0);
                if (possibleRet == 0 && encData.length % 16 != 0) {
                    offset = 4;
                }
            }

            // In v3.4, payload might start with "3.4"
            if (encData.length >= 15 && encData[offset] == '3' && encData[offset + 1] == '.' && encData[offset + 2] == '4') {
                offset += 15;
            }

            byte[] cipherBlock = Arrays.copyOfRange(encData, offset, encData.length);
            if (cipherBlock.length == 0) {
                return "{\"error\":\"No cipher payload extracted\"}";
            }

            if (cipherBlock.length % 16 != 0) {
                // If not block aligned, maybe plaintext json
                String asStr = new String(cipherBlock, StandardCharsets.UTF_8).trim();
                if (asStr.startsWith("{") && asStr.endsWith("}")) {
                    return asStr;
                }
            }

            byte[] decrypted = decryptAesEcbPkcs7(cipherBlock, keyBytes);
            if (decrypted == null) {
                return "{\"error\":\"AES decryption failed\"}";
            }

            String jsonStr = new String(decrypted, StandardCharsets.UTF_8).trim();
            return jsonStr;

        } catch (Exception e) {
            return "{\"error\":\"" + e.getMessage() + "\"}";
        } finally {
            if (socket != null) {
                try {
                    socket.close();
                } catch (Exception ignored) {
                }
            }
        }
    }

    private static byte[] encryptAesEcbPkcs7(byte[] src, byte[] key) throws Exception {
        Cipher cipher = Cipher.getInstance("AES/ECB/PKCS5Padding");
        SecretKeySpec keySpec = new SecretKeySpec(key, "AES");
        cipher.init(Cipher.ENCRYPT_MODE, keySpec);
        return cipher.doFinal(src);
    }

    private static byte[] decryptAesEcbPkcs7(byte[] src, byte[] key) {
        try {
            Cipher cipher = Cipher.getInstance("AES/ECB/PKCS5Padding");
            SecretKeySpec keySpec = new SecretKeySpec(key, "AES");
            cipher.init(Cipher.DECRYPT_MODE, keySpec);
            return cipher.doFinal(src);
        } catch (Exception e) {
            try {
                // Try NoPadding and manually trim
                Cipher cipher = Cipher.getInstance("AES/ECB/NoPadding");
                SecretKeySpec keySpec = new SecretKeySpec(key, "AES");
                cipher.init(Cipher.DECRYPT_MODE, keySpec);
                byte[] raw = cipher.doFinal(src);
                int pad = raw[raw.length - 1];
                if (pad > 0 && pad <= 16) {
                    return Arrays.copyOfRange(raw, 0, raw.length - pad);
                }
                return raw;
            } catch (Exception ignored) {
                return null;
            }
        }
    }

    private static void writeInt32(int val, byte[] buf, int offset) {
        buf[offset] = (byte) ((val >> 24) & 0xFF);
        buf[offset + 1] = (byte) ((val >> 16) & 0xFF);
        buf[offset + 2] = (byte) ((val >> 8) & 0xFF);
        buf[offset + 3] = (byte) (val & 0xFF);
    }

    private static int readInt32(byte[] buf, int offset) {
        return ((buf[offset] & 0xFF) << 24) |
               ((buf[offset + 1] & 0xFF) << 16) |
               ((buf[offset + 2] & 0xFF) << 8) |
               (buf[offset + 3] & 0xFF);
    }

    private static int readFully(InputStream in, byte[] buf, int len) throws Exception {
        int total = 0;
        while (total < len) {
            int r = in.read(buf, total, len - total);
            if (r == -1) break;
            total += r;
        }
        return total;
    }
}
