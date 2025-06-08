import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AlarmStorage {
  static const String _snoozeKey = 'snooze_durations';
  
  // Store snooze duration for an alarm
  static Future<void> setSnoozeData(int alarmId, int snoozeDurationMinutes) async {
    final prefs = await SharedPreferences.getInstance();
    final existingData = prefs.getString(_snoozeKey) ?? '{}';
    final Map<String, dynamic> snoozeData = json.decode(existingData);
    
    snoozeData[alarmId.toString()] = snoozeDurationMinutes;
    
    await prefs.setString(_snoozeKey, json.encode(snoozeData));
  }
  
  // Get snooze duration for an alarm (default 5 minutes if not found)
  static Future<int> getSnoozeData(int alarmId) async {
    final prefs = await SharedPreferences.getInstance();
    final existingData = prefs.getString(_snoozeKey) ?? '{}';
    final Map<String, dynamic> snoozeData = json.decode(existingData);
    
    return snoozeData[alarmId.toString()] as int? ?? 5; // Default 5 minutes
  }
  
  // Remove snooze data for an alarm
  static Future<void> removeSnoozeData(int alarmId) async {
    final prefs = await SharedPreferences.getInstance();
    final existingData = prefs.getString(_snoozeKey) ?? '{}';
    final Map<String, dynamic> snoozeData = json.decode(existingData);
    
    snoozeData.remove(alarmId.toString());
    
    await prefs.setString(_snoozeKey, json.encode(snoozeData));
  }
}