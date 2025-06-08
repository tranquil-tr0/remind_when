import 'dart:math';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/alarm.dart';

class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  static const String _alarmListKey = 'alarm_list';
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Initialize the alarm service
  Future<void> initialize() async {
    await AndroidAlarmManager.initialize();
    await _initializeNotifications();
  }

  // Initialize local notifications
  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(initSettings);

    // Create notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      'alarm_channel',
      'Alarm Notifications',
      description: 'Channel for alarm notifications',
      importance: Importance.max,
      showBadge: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  // Get all alarms from SharedPreferences
  Future<List<Alarm>> getAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final alarmListJson = prefs.getStringList(_alarmListKey) ?? [];
    
    return alarmListJson
        .map((json) => Alarm.fromJson(json))
        .toList()
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  // Save alarms to SharedPreferences
  Future<void> _saveAlarms(List<Alarm> alarms) async {
    final prefs = await SharedPreferences.getInstance();
    final alarmListJson = alarms.map((alarm) => alarm.toJson()).toList();
    await prefs.setStringList(_alarmListKey, alarmListJson);
  }

  // Add a new alarm
  Future<void> addAlarm(Alarm alarm) async {
    final alarms = await getAlarms();
    alarms.add(alarm);
    await _saveAlarms(alarms);
    
    if (alarm.isEnabled) {
      await _scheduleAlarm(alarm);
    }
  }

  // Update an existing alarm
  Future<void> updateAlarm(Alarm alarm) async {
    final alarms = await getAlarms();
    final index = alarms.indexWhere((a) => a.id == alarm.id);
    
    if (index != -1) {
      // Cancel existing alarm
      await _cancelAlarm(alarms[index]);
      
      // Update the alarm
      alarms[index] = alarm;
      await _saveAlarms(alarms);
      
      // Schedule new alarm if enabled
      if (alarm.isEnabled) {
        await _scheduleAlarm(alarm);
      }
    }
  }

  // Delete an alarm
  Future<void> deleteAlarm(String alarmId) async {
    final alarms = await getAlarms();
    final alarmToDelete = alarms.firstWhere((a) => a.id == alarmId);
    
    await _cancelAlarm(alarmToDelete);
    alarms.removeWhere((a) => a.id == alarmId);
    await _saveAlarms(alarms);
  }

  // Toggle alarm enabled/disabled
  Future<void> toggleAlarm(String alarmId) async {
    final alarms = await getAlarms();
    final index = alarms.indexWhere((a) => a.id == alarmId);
    
    if (index != -1) {
      final alarm = alarms[index];
      final updatedAlarm = alarm.copyWith(isEnabled: !alarm.isEnabled);
      
      if (updatedAlarm.isEnabled) {
        await _scheduleAlarm(updatedAlarm);
      } else {
        await _cancelAlarm(alarm);
      }
      
      alarms[index] = updatedAlarm;
      await _saveAlarms(alarms);
    }
  }

  // Schedule an alarm using AndroidAlarmManager
  Future<void> _scheduleAlarm(Alarm alarm) async {
    final alarmId = alarm.id.hashCode;
    final now = DateTime.now();
    final timeUntilAlarm = alarm.dateTime.difference(now);
    
    print('DEBUG: Scheduling alarm with ID: $alarmId for ${alarm.title}');
    print('DEBUG: Current time: $now');
    print('DEBUG: Alarm time: ${alarm.dateTime}');
    print('DEBUG: Time until alarm: ${timeUntilAlarm.inMinutes} minutes');
    print('DEBUG: Alarm is in the ${alarm.dateTime.isAfter(now) ? 'future' : 'past'}');
    
    try {
      // Store alarm data in SharedPreferences for callback access
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('alarm_${alarmId}_title', alarm.title);
      await prefs.setString('alarm_${alarmId}_id', alarm.id);
      
      print('DEBUG: Stored alarm data in SharedPreferences');
      
      // Try AndroidAlarmManager first (primary method)
      try {
        await AndroidAlarmManager.oneShotAt(
          alarm.dateTime,
          alarmId,
          _alarmCallbackWithId,
          exact: true,
          wakeup: true,
          rescheduleOnReboot: true,
        );
        print('DEBUG: Alarm scheduled successfully with AndroidAlarmManager');
        
        // ALSO schedule fallback as backup (for testing/diagnosis)
        print('DEBUG: Also scheduling fallback timer as backup');
        await _scheduleNotificationFallback(alarm, alarmId);
        
      } catch (alarmManagerError) {
        print('DEBUG: AndroidAlarmManager failed: $alarmManagerError');
        print('DEBUG: Falling back to notification-only scheduling');
        
        // Fallback: Schedule immediate notification for testing
        await _scheduleNotificationFallback(alarm, alarmId);
      }
    } catch (e) {
      print('DEBUG: Error scheduling alarm: $e');
      rethrow;
    }
  }

  // Fallback notification scheduling method
  Future<void> _scheduleNotificationFallback(Alarm alarm, int alarmId) async {
    final timeUntilAlarm = alarm.dateTime.difference(DateTime.now());
    
    if (timeUntilAlarm.inSeconds > 0) {
      // Use Future.delayed as a simple fallback for testing
      // Note: This won't survive app restarts, but will help diagnose the issue
      print('DEBUG: Using Future.delayed fallback for ${timeUntilAlarm.inSeconds} seconds');
      
      Future.delayed(timeUntilAlarm, () async {
        print('DEBUG: Fallback timer triggered for alarm $alarmId');
        _alarmCallbackWithId(alarmId);
      });
    } else {
      print('DEBUG: Alarm time is in the past, triggering immediately');
      _alarmCallbackWithId(alarmId);
    }
  }

  // Cancel a scheduled alarm
  Future<void> _cancelAlarm(Alarm alarm) async {
    final alarmId = alarm.id.hashCode;
    await AndroidAlarmManager.cancel(alarmId);
  }

  // Static callback function for alarm execution with ID parameter
  @pragma('vm:entry-point')
  static void _alarmCallbackWithId(int alarmId) async {
    print('=== ALARM CALLBACK START ===');
    print('DEBUG: Alarm callback triggered with ID: $alarmId');
    print('DEBUG: Current time: ${DateTime.now()}');
    print('DEBUG: Callback executing in isolate');
    
    try {
      final notificationsPlugin = FlutterLocalNotificationsPlugin();
      
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);
      await notificationsPlugin.initialize(initSettings);
      
      // Recreate notification channel in callback
      const androidChannel = AndroidNotificationChannel(
        'alarm_channel',
        'Alarm Notifications',
        description: 'Channel for alarm notifications',
        importance: Importance.max,
        showBadge: true,
      );

      await notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
      
      print('DEBUG: Notification plugin initialized and channel created');

      // Retrieve alarm data from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final title = prefs.getString('alarm_${alarmId}_title') ?? 'Alarm';
      final alarmIdString = prefs.getString('alarm_${alarmId}_id') ?? 'unknown';
      
      print('DEBUG: Retrieved alarm title: $title, ID: $alarmIdString');

      final notificationId = Random().nextInt(1000000);

      const androidDetails = AndroidNotificationDetails(
        'alarm_channel',
        'Alarm Notifications',
        channelDescription: 'Channel for alarm notifications',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
      );

      const notificationDetails = NotificationDetails(android: androidDetails);

      print('DEBUG: Attempting to show notification with ID: $notificationId');
      print('DEBUG: Notification title: Alarm: $title');
      print('DEBUG: Notification body: Your alarm is ringing!');
      
      await notificationsPlugin.show(
        notificationId,
        'Alarm: $title',
        'Your alarm is ringing!',
        notificationDetails,
      );
      
      print('DEBUG: Notification show() method completed successfully');
      
      // Additional verification - check if notification was actually created
      final activeNotifications = await notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.getActiveNotifications();
      
      print('DEBUG: Active notifications count: ${activeNotifications?.length ?? 'unknown'}');
      
      // Clean up stored data
      await prefs.remove('alarm_${alarmId}_title');
      await prefs.remove('alarm_${alarmId}_id');
      
    } catch (e) {
      print('DEBUG: Error in alarm callback: $e');
    }
  }

  // Legacy callback function for reference (not used)
  @pragma('vm:entry-point')
  static void _alarmCallback(Map<String, dynamic> params) async {
    final notificationsPlugin = FlutterLocalNotificationsPlugin();
    
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await notificationsPlugin.initialize(initSettings);

    final title = params['title'] ?? 'Alarm';
    final notificationId = Random().nextInt(1000000);

    const androidDetails = AndroidNotificationDetails(
      'alarm_channel',
      'Alarm Notifications',
      channelDescription: 'Channel for alarm notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await notificationsPlugin.show(
      notificationId,
      'Alarm: $title',
      'Your alarm is ringing!',
      notificationDetails,
    );
  }
}