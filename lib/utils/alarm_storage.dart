import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

class AlarmStorage {
  static const String _snoozeKey = 'snooze_durations';
  static const String _customSoundsKey = 'custom_alarm_sounds';
  
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
  
  // Get the app's documents directory for storing custom sounds
  static Future<Directory> get _customSoundsDirectory async {
    final appDir = await getApplicationDocumentsDirectory();
    final customSoundsDir = Directory('${appDir.path}/custom_sounds');
    if (!await customSoundsDir.exists()) {
      await customSoundsDir.create(recursive: true);
    }
    return customSoundsDir;
  }
  
  // Save a custom alarm sound
  static Future<String?> saveCustomSound(String originalPath, String displayName) async {
    try {
      final customDir = await _customSoundsDirectory;
      final originalFile = File(originalPath);
      
      if (!await originalFile.exists()) {
        return null;
      }
      
      // Generate a unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = originalPath.split('.').last;
      final newFilename = 'custom_$timestamp.$extension';
      final newPath = '${customDir.path}/$newFilename';
      
      // Copy the file to the custom sounds directory
      await originalFile.copy(newPath);
      
      // Store the mapping in shared preferences
      final prefs = await SharedPreferences.getInstance();
      final existingData = prefs.getString(_customSoundsKey) ?? '{}';
      final Map<String, dynamic> customSounds = json.decode(existingData);
      
      customSounds[newPath] = {
        'displayName': displayName,
        'originalPath': originalPath,
        'addedAt': DateTime.now().toIso8601String(),
      };
      
      await prefs.setString(_customSoundsKey, json.encode(customSounds));
      
      return newPath;
    } catch (e) {
      print('Error saving custom sound: $e');
      return null;
    }
  }
  
  // Get all custom alarm sounds
  static Future<List<Map<String, String>>> getCustomSounds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingData = prefs.getString(_customSoundsKey) ?? '{}';
      final Map<String, dynamic> customSounds = json.decode(existingData);
      
      final List<Map<String, String>> sounds = [];
      
      // Add default sound
      sounds.add({
        'name': 'Default Alarm',
        'path': 'assets/alarm.mp3',
        'type': 'builtin',
      });
      
      // Add custom sounds, but verify they still exist
      final validSounds = <String, dynamic>{};
      for (final entry in customSounds.entries) {
        final soundPath = entry.key;
        final soundData = entry.value as Map<String, dynamic>;
        
        // Check if the file still exists
        if (await File(soundPath).exists()) {
          sounds.add({
            'name': soundData['displayName'] as String,
            'path': soundPath,
            'type': 'custom',
          });
          validSounds[soundPath] = soundData;
        }
      }
      
      // Update stored data to remove invalid entries
      if (validSounds.length != customSounds.length) {
        await prefs.setString(_customSoundsKey, json.encode(validSounds));
      }
      
      return sounds;
    } catch (e) {
      print('Error getting custom sounds: $e');
      // Return default sound if there's an error
      return [
        {
          'name': 'Default Alarm',
          'path': 'assets/alarm.mp3',
          'type': 'builtin',
        }
      ];
    }
  }
  
  // Delete a custom alarm sound
  static Future<bool> deleteCustomSound(String soundPath) async {
    try {
      // Don't allow deletion of builtin sounds
      if (soundPath.startsWith('assets/')) {
        return false;
      }
      
      final prefs = await SharedPreferences.getInstance();
      final existingData = prefs.getString(_customSoundsKey) ?? '{}';
      final Map<String, dynamic> customSounds = json.decode(existingData);
      
      // Remove from storage
      customSounds.remove(soundPath);
      await prefs.setString(_customSoundsKey, json.encode(customSounds));
      
      // Delete the actual file
      final file = File(soundPath);
      if (await file.exists()) {
        await file.delete();
      }
      
      return true;
    } catch (e) {
      print('Error deleting custom sound: $e');
      return false;
    }
  }
  
  // Get display name for a sound path
  static Future<String> getSoundDisplayName(String soundPath) async {
    if (soundPath.startsWith('assets/')) {
      return 'Default Alarm';
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingData = prefs.getString(_customSoundsKey) ?? '{}';
      final Map<String, dynamic> customSounds = json.decode(existingData);
      
      final soundData = customSounds[soundPath] as Map<String, dynamic>?;
      return soundData?['displayName'] as String? ?? 'Unknown Sound';
    } catch (e) {
      return 'Unknown Sound';
    }
  }
}