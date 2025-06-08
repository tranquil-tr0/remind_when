import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/alarm_service.dart';
import 'screens/alarm_list_screen.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('DEBUG: Starting app initialization');
  
  await AndroidAlarmManager.initialize();
  
  // Initialize alarm service
  final alarmService = AlarmService();
  await alarmService.initialize();
  
  print('DEBUG: Alarm service initialized');
  
  // Request necessary permissions
  await _requestPermissions();
  
  print('DEBUG: About to run app');
  
  runApp(const AlarmApp());
}

Future<void> _requestPermissions() async {
  print('DEBUG: Requesting permissions...');
  
  // Request notification permission
  final notificationStatus = await Permission.notification.request();
  print('DEBUG: Notification permission status: $notificationStatus');
  
  // Request schedule exact alarm permission (Android 12+)
  final exactAlarmStatus = await Permission.scheduleExactAlarm.status;
  print('DEBUG: Schedule exact alarm permission status: $exactAlarmStatus');
  
  if (await Permission.scheduleExactAlarm.isDenied) {
    final exactAlarmResult = await Permission.scheduleExactAlarm.request();
    print('DEBUG: Schedule exact alarm permission request result: $exactAlarmResult');
  }
  
  // Request system alert window permission
  final systemAlertStatus = await Permission.systemAlertWindow.status;
  print('DEBUG: System alert window permission status: $systemAlertStatus');
  
  if (await Permission.systemAlertWindow.isDenied) {
    final systemAlertResult = await Permission.systemAlertWindow.request();
    print('DEBUG: System alert window permission request result: $systemAlertResult');
  }
  
  print('DEBUG: Permission requests completed');
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
