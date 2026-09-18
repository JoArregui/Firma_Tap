import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:workmanager/workmanager.dart';
import 'core/theme/app_theme.dart';
import 'core/offline/queue_service.dart';
import 'core/storage/history_service.dart';
import 'core/push/push_service.dart';
import 'features/pages/login_page.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await Hive.initFlutter();
    await QueueService.init();
    await QueueService.retryAll();
    return Future.value(true);
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  try { await Firebase.initializeApp(); } catch (_) {}
  try { await PushService().init(); } catch (_) {}
  try { await QueueService.init(); } catch (_) {}
  try { await HistoryService.init(); } catch (_) {}
  try {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    await Workmanager().registerPeriodicTask('retryFirmas', 'retryFirmas', frequency: const Duration(minutes: 15), constraints: Constraints(networkType: NetworkType.connected));
  } catch (_) {}
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Control de Albaranes',
      theme: AppTheme.light,
      home: const LoginPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
