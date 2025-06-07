import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/alarm_service.dart';
import 'screens/alarm_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize alarm service
  final alarmService = AlarmService();
  await alarmService.initialize();
  
  // Request necessary permissions
  await _requestPermissions();
  
  runApp(const AlarmApp());
}

Future<void> _requestPermissions() async {
  // Request notification permission
  await Permission.notification.request();
  
  // Request schedule exact alarm permission (Android 12+)
  if (await Permission.scheduleExactAlarm.isDenied) {
    await Permission.scheduleExactAlarm.request();
  }
  
  // Request system alert window permission
  if (await Permission.systemAlertWindow.isDenied) {
    await Permission.systemAlertWindow.request();
  }
}

class AlarmApp extends StatelessWidget {
  const AlarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Remind When',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 2,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          elevation: 4,
        ),
      ),
      home: const AlarmListScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
