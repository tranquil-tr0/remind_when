import 'dart:async';
import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart';
import 'package:permission_handler/permission_handler.dart';
import 'alarm_ring_screen.dart';
import '../widgets/add_alarm_modal.dart';
import '../utils/alarm_storage.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<AlarmSettings> alarms = [];
  late StreamSubscription subscription;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadAlarms();
    _setupAlarmStream();
  }

  @override
  void dispose() {
    subscription.cancel();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    // Check and request notification permissions
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
    
    // Check and request exact alarm permissions (Android 12+)
    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }
  }

  void _loadAlarms() {
    setState(() {
      alarms = Alarm.getAlarms();
    });
  }

  void _setupAlarmStream() {
    subscription = Alarm.ringStream.stream.listen((alarmSettings) {
      // Navigate to ring screen when alarm rings
      _navigateToRingScreen(alarmSettings);
    });
  }

  void _navigateToRingScreen(AlarmSettings alarmSettings) {
    // Navigate to ring screen when alarm rings
    print('Alarm ringing: ${alarmSettings.id}');
    
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AlarmRingScreen(alarmSettings: alarmSettings),
          fullscreenDialog: true,
        ),
      );
    }
  }

  void _addAlarm() {
    showDialog(
      context: context,
      builder: (context) => const AddAlarmModal(),
    ).then((result) {
      // Refresh alarms list if an alarm was added
      if (result == true) {
        _loadAlarms();
      }
    });
  }

  void _triggerDebugAlarm() {
    // Create a debug alarm that rings immediately
    final now = DateTime.now();
    
    // Generate a smaller ID by using a simple counter (1-1000 range)
    final alarmId = (now.millisecondsSinceEpoch % 1000) + 1;
    
    final alarmSettings = AlarmSettings(
      id: alarmId,
      dateTime: now.add(const Duration(seconds: 3)),
      assetAudioPath: 'assets/alarm.mp3',
      loopAudio: true,
      vibrate: true,
      volume: 0.8,
      fadeDuration: 3.0,
      notificationTitle: 'Debug Alarm',
      notificationBody: 'This is a debug alarm - should ring now!',
      enableNotificationOnKill: true,
    );

    Alarm.set(alarmSettings: alarmSettings).then((success) {
      if (success) {
        _loadAlarms();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Debug alarm set for 3 seconds')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to set debug alarm')),
          );
        }
      }
    });
  }

  void _deleteAlarm(int alarmId) {
    Alarm.stop(alarmId).then((success) async {
      if (success) {
        // Clean up stored snooze data for this alarm
        await AlarmStorage.removeSnoozeData(alarmId);
        _loadAlarms();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Alarm deleted')),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Remind When'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _buildBody(),
      floatingActionButton: _buildFloatingActionButtons(),
    );
  }

  Widget _buildBody() {
    if (alarms.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.alarm_off,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No alarms set',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Tap the + button to add your first alarm',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: alarms.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final alarm = alarms[index];
        return _buildAlarmCard(alarm);
      },
    );
  }

  Widget _buildAlarmCard(AlarmSettings alarm) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.alarm, color: Colors.deepPurple),
        title: Text(
          _formatTime(alarm.dateTime),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          alarm.notificationTitle.isNotEmpty ? alarm.notificationTitle : 'Alarm',
          style: const TextStyle(fontSize: 14),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _deleteAlarm(alarm.id),
        ),
        onTap: () {
          // TODO: Navigate to edit alarm
          print('Edit alarm: ${alarm.id}');
        },
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildFloatingActionButtons() {
    return Stack(
      children: [
        // Add alarm button (bottom right)
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            onPressed: _addAlarm,
            tooltip: 'Add Alarm',
            child: const Icon(Icons.add),
          ),
        ),
        // Debug ring button (bottom left)
        Positioned(
          bottom: 16,
          left: 32,
          child: FloatingActionButton(
            onPressed: _triggerDebugAlarm,
            tooltip: 'Test Ring',
            backgroundColor: Colors.orange,
            child: const Icon(Icons.ring_volume),
          ),
        ),
      ],
    );
  }
}