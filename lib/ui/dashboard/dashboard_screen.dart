import 'package:flutter/material.dart';

import '../../core/database/telemetry_repository.dart';
import '../../core/engine/disaggregation_use_case.dart';
import '../../core/models/device_model.dart';
import '../widgets/disaggregation_breakdown_chart.dart';
import '../widgets/live_load_gauge_widget.dart';

/// Homeowner-friendly Dashboard Screen for OmniaEnergy (v0.2.0-home).
///
/// Presents live household usage in everyday terms (Watts, ₹/hour, estimated
/// monthly bill, room-by-room appliance controls, and smart savings tips) while
/// running the disaggregation math and SQLite buffering automatically in the
/// background.
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
  static const double _defaultTariffInrPerKwh = 8.0;

  late final DisaggregationUseCase _disaggregationUseCase;
  List<DeviceModel> _devices = [];
  DisaggregationSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    _disaggregationUseCase = DisaggregationUseCase(
      repository: widget.repository,
    );
    _seedFriendlyHomeDevices();
  }

  Future<void> _seedFriendlyHomeDevices() async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    _devices = <DeviceModel>[
      DeviceModel(
        id: 'main_home_meter',
        name: 'Main Home Smart Meter',
        category: DeviceCategory.ctClamp,
        vendor: DeviceVendor.hardwareCt,
        isOn: true,
        livePowerWatts: 1850.0,
        metadata: const {'room': 'Main Panel', 'icon': '⚡'},
        updatedAtMs: nowMs,
      ),
      DeviceModel(
        id: 'native_kitchen_fridge',
        name: 'Kitchen Double-Door Fridge',
        category: DeviceCategory.nativeMetering,
        vendor: DeviceVendor.tuyaOpenApi,
        isOn: true,
        livePowerWatts: 145.0,
        metadata: const {'room': 'Kitchen & Dining', 'icon': '🧊'},
        updatedAtMs: nowMs,
      ),
      DeviceModel(
        id: 'master_bath_geyser',
        name: 'Master Bath Water Heater',
        category: DeviceCategory.virtualPayload,
        vendor: DeviceVendor.tuyaOpenApi,
        ratedWatts: 2000.0,
        currentLevelPercent: 50.0,
        isOn: true,
        metadata: const {'room': 'Master Bedroom', 'icon': '🚿'},
        updatedAtMs: nowMs,
      ),
      DeviceModel(
        id: 'atomberg_ble_living',
        name: 'Living Room Atomberg Fan',
        category: DeviceCategory.virtualPayload,
        vendor: DeviceVendor.atombergBle,
        ratedWatts: 35.0,
        currentLevelPercent: 60.0,
        isOn: true,
        metadata: const {'room': 'Living Room', 'icon': '🌀'},
        updatedAtMs: nowMs,
      ),
      DeviceModel(
        id: 'ghome_smart_dimmer',
        name: 'Dining Table Chandelier',
        category: DeviceCategory.virtualPayload,
        vendor: DeviceVendor.googleHome,
        ratedWatts: 60.0,
        currentLevelPercent: 80.0,
        isOn: true,
        metadata: const {'room': 'Kitchen & Dining', 'icon': '💡'},
        updatedAtMs: nowMs,
      ),
    ];

    await _recalculateAndSaveSilently();
  }

  Future<void> _recalculateAndSaveSilently() async {
    final snapshot = await _disaggregationUseCase.execute(
      devices: _devices,
      persistToBuffer: true,
    );
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
    });
  }

  void _toggleAppliance(int index, bool isOn) {
    setState(() {
      _devices[index] = _devices[index].copyWith(
        isOn: isOn,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
    });
    _recalculateAndSaveSilently();
  }

  @override
  Widget build(BuildContext context) {
    final record = _snapshot?.record;
    final pCt = record?.pCtWatts ?? 0.0;
    final pNative = record?.pNativeSumWatts ?? 0.0;
    final pVirtual = record?.pVirtualSumWatts ?? 0.0;
    final pResidual = record?.pResidualWatts ?? 0.0;
    final hourlyCostInr = (pCt / 1000.0) * _defaultTariffInrPerKwh;

    return Scaffold(
      backgroundColor: const Color(0xFF070B12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070B12),
        title: const Text(
          '🏡 OmniaEnergy',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              label: Text(
                '≈ ₹${hourlyCostInr.toStringAsFixed(1)}/hr',
                style: const TextStyle(
                  color: Color(0xFF10B981),
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: const Color(0xFF111827),
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
            'My Home Appliances',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          ...List.generate(_devices.length, (index) {
            final device = _devices[index];
            if (device.category == DeviceCategory.ctClamp) {
              return const SizedBox.shrink();
            }
            final room = (device.metadata['room'] as String?) ?? 'Home';
            final icon = (device.metadata['icon'] as String?) ?? '🔌';
            final costPerHr =
                (device.activeWatts / 1000.0) * _defaultTariffInrPerKwh;

            return Card(
              color: const Color(0xFF111827),
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: ListTile(
                leading: Text(icon, style: const TextStyle(fontSize: 24)),
                title: Text(
                  device.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                subtitle: Text(
                  '$room • ₹${costPerHr.toStringAsFixed(2)}/hr',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                trailing: Switch(
                  value: device.isOn,
                  onChanged: (v) => _toggleAppliance(index, v),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
