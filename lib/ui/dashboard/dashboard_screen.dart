import 'package:flutter/material.dart';

import '../../core/database/telemetry_repository.dart';
import '../../core/engine/disaggregation_use_case.dart';
import '../../core/models/device_model.dart';
import '../widgets/disaggregation_breakdown_chart.dart';
import '../widgets/live_load_gauge_widget.dart';

/// Main dashboard screen for OmniaEnergy displaying:
/// 1. Live CT household load gauge (`LiveLoadGaugeWidget`)
/// 2. Disaggregation breakdown chart (`DisaggregationBreakdownChart`)
/// 3. Interactive device telemetry controls (CT Clamp, Tuya Native Plugs,
///    Atomberg BLE & Google Home Virtual Payload devices)
class DashboardScreen extends StatefulWidget {
  final TelemetryRepository repository;

  const DashboardScreen({
    super.key,
    required this.repository,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final DisaggregationUseCase _disaggregationUseCase;
  List<DeviceModel> _devices = [];
  DisaggregationSnapshot? _snapshot;
  int _pendingSyncCount = 0;

  @override
  void initState() {
    super.initState();
    _disaggregationUseCase = DisaggregationUseCase(
      repository: widget.repository,
    );
    _seedDefaultDevicesAndCompute();
  }

  Future<void> _seedDefaultDevicesAndCompute() async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final defaultDevices = <DeviceModel>[
      DeviceModel(
        id: 'ct_main_01',
        name: 'Main Breaker CT Clamp',
        category: DeviceCategory.ctClamp,
        vendor: DeviceVendor.hardwareCt,
        isOn: true,
        livePowerWatts: 1850.0,
        updatedAtMs: nowMs,
      ),
      DeviceModel(
        id: 'tuya_ac_plug_01',
        name: 'Master Bedroom Inverter AC (Tuya DP)',
        category: DeviceCategory.nativeMetering,
        vendor: DeviceVendor.tuyaOpenApi,
        isOn: true,
        livePowerWatts: 1120.0,
        updatedAtMs: nowMs,
      ),
      DeviceModel(
        id: 'tuya_fridge_plug_02',
        name: 'Kitchen Refrigerator (Tuya DP)',
        category: DeviceCategory.nativeMetering,
        vendor: DeviceVendor.tuyaOpenApi,
        isOn: true,
        livePowerWatts: 165.0,
        updatedAtMs: nowMs,
      ),
      DeviceModel(
        id: 'atomberg_fan_living',
        name: 'Atomberg Renesa BLDC Fan (BLE)',
        category: DeviceCategory.virtualPayload,
        vendor: DeviceVendor.atombergBle,
        ratedWatts: 35.0,
        currentLevelPercent: 60.0,
        isOn: true,
        updatedAtMs: nowMs,
      ),
      DeviceModel(
        id: 'ghome_living_lights',
        name: 'Living Room Smart Chandelier (Google Home)',
        category: DeviceCategory.virtualPayload,
        vendor: DeviceVendor.googleHome,
        ratedWatts: 60.0,
        currentLevelPercent: 80.0,
        isOn: true,
        updatedAtMs: nowMs,
      ),
    ];

    _devices = defaultDevices;
    await _recalculate(persistToSqlite: false);
  }

  Future<void> _recalculate({bool persistToSqlite = false}) async {
    final snapshot = await _disaggregationUseCase.execute(
      devices: _devices,
      persistToBuffer: persistToSqlite,
    );
    if (persistToSqlite) {
      final pending = await widget.repository.fetchPendingSyncBatch();
      _pendingSyncCount = pending.length;
    }
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
    });
  }

  void _toggleDeviceState(int index, bool isOn) {
    setState(() {
      _devices[index] = _devices[index].copyWith(
        isOn: isOn,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
    });
    _recalculate(persistToSqlite: false);
  }

  void _updateDeviceLevel(int index, double newPercent) {
    setState(() {
      _devices[index] = _devices[index].copyWith(
        currentLevelPercent: newPercent,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
    });
    _recalculate(persistToSqlite: false);
  }

  @override
  Widget build(BuildContext context) {
    final record = _snapshot?.record;
    final pCt = record?.pCtWatts ?? 0.0;
    final pNative = record?.pNativeSumWatts ?? 0.0;
    final pVirtual = record?.pVirtualSumWatts ?? 0.0;
    final pResidual = record?.pResidualWatts ?? 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F17),
        title: const Text(
          'OmniaEnergy',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.tonalIcon(
              onPressed: () => _recalculate(persistToSqlite: true),
              icon: const Icon(Icons.storage_rounded, size: 18),
              label: Text('Buffer to SQLite ($_pendingSyncCount)'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LiveLoadGaugeWidget(
            pCtWatts: pCt,
            pNativeWatts: pNative,
            pVirtualWatts: pVirtual,
            pResidualWatts: pResidual,
          ),
          const SizedBox(height: 16),
          DisaggregationBreakdownChart(
            pCtWatts: pCt,
            pNativeWatts: pNative,
            pVirtualWatts: pVirtual,
            pResidualWatts: pResidual,
          ),
          const SizedBox(height: 20),
          const Text(
            'ACTIVE INGESTION SOURCES',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: Colors.white60,
            ),
          ),
          const SizedBox(height: 10),
          ...List.generate(_devices.length, (index) {
            final device = _devices[index];
            return Card(
              color: const Color(0xFF141A24),
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                device.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${device.vendor.dbValue} • ${device.category.dbValue}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${device.activeWatts.toStringAsFixed(1)} W',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00E676),
                          ),
                        ),
                        if (device.category == DeviceCategory.virtualPayload)
                          Switch(
                            value: device.isOn,
                            onChanged: (v) => _toggleDeviceState(index, v),
                          ),
                      ],
                    ),
                    if (device.category == DeviceCategory.virtualPayload) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            'Level: ${device.currentLevelPercent.toStringAsFixed(0)}% '
                            '(P_rated: ${device.ratedWatts.toStringAsFixed(0)}W)',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                          Expanded(
                            child: Slider(
                              value: device.currentLevelPercent,
                              min: 0,
                              max: 100,
                              divisions: 20,
                              onChanged: device.isOn
                                  ? (v) => _updateDeviceLevel(index, v)
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
