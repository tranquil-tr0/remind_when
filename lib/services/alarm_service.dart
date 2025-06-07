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
    
    await AndroidAlarmManager.oneShotAt(
      alarm.dateTime,
      alarmId,
      _alarmCallback,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
      params: {
        'id': alarm.id,
        'title': alarm.title,
      },
    );
  }

  // Cancel a scheduled alarm
  Future<void> _cancelAlarm(Alarm alarm) async {
    final alarmId = alarm.id.hashCode;
    await AndroidAlarmManager.cancel(alarmId);
  }

  // Static callback function for alarm execution
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