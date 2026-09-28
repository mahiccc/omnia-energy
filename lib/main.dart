import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';

import 'core/database/telemetry_repository.dart';
import 'core/engine/background_sync_worker.dart';
import 'ui/dashboard/dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register WorkManager periodic local disaggregation & Google Drive sync
  try {
    await Workmanager().initialize(
      omniaBackgroundCallbackDispatcher,
      isInDebugMode: false,
    );
    await Workmanager().registerPeriodicTask(
      kOmniaPeriodicSyncTask,
      kOmniaPeriodicSyncTask,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  } catch (_) {
    // WorkManager initialization is ignored on unsupported host test environments
  }

  runApp(const OmniaEnergyApp());
}

class OmniaEnergyApp extends StatelessWidget {
  const OmniaEnergyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OmniaEnergy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00E676),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: DashboardScreen(
        repository: SqliteTelemetryRepository(),
      ),
    );
  }
}
