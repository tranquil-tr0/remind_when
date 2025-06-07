import 'package:flutter/material.dart';
import '../models/alarm.dart';
import '../services/alarm_service.dart';
import 'add_alarm_screen.dart';

class AlarmListScreen extends StatefulWidget {
  const AlarmListScreen({super.key});

  @override
  State<AlarmListScreen> createState() => _AlarmListScreenState();
}

class _AlarmListScreenState extends State<AlarmListScreen> {
  final AlarmService _alarmService = AlarmService();
  List<Alarm> _alarms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlarms();
  }

  Future<void> _loadAlarms() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final alarms = await _alarmService.getAlarms();
      setState(() {
        _alarms = alarms;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading alarms: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleAlarm(String alarmId) async {
    try {
      await _alarmService.toggleAlarm(alarmId);
      await _loadAlarms();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error toggling alarm: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteAlarm(String alarmId) async {
    try {
      await _alarmService.deleteAlarm(alarmId);
      await _loadAlarms();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alarm deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting alarm: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(Alarm alarm) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Alarm'),
          content: Text('Are you sure you want to delete "${alarm.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteAlarm(alarm.id);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    String dateStr;
    if (date == today) {
      dateStr = 'Today';
    } else if (date == tomorrow) {
      dateStr = 'Tomorrow';
    } else {
      dateStr = '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }

    final timeStr = TimeOfDay.fromDateTime(dateTime).format(context);
    return '$dateStr at $timeStr';
  }

  Color _getAlarmColor(Alarm alarm) {
    if (!alarm.isEnabled) {
      return Colors.grey;
    }
    return alarm.dateTime.isBefore(DateTime.now()) ? Colors.red : Colors.green;
  }

  IconData _getAlarmIcon(Alarm alarm) {
    if (!alarm.isEnabled) {
      return Icons.alarm_off;
    }
    return alarm.dateTime.isBefore(DateTime.now()) ? Icons.alarm_off : Icons.alarm;
  }

  Future<void> _addAlarm() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => const AddAlarmScreen()),
    );

    if (result == true) {
      await _loadAlarms();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alarm Clock'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _alarms.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.alarm_add,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No alarms set',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap the + button to add your first alarm',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[500],
                            ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAlarms,
                  child: ListView.builder(
                    itemCount: _alarms.length,
                    itemBuilder: (context, index) {
                      final alarm = _alarms[index];
                      final isExpired = alarm.dateTime.isBefore(DateTime.now());
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: Icon(
                            _getAlarmIcon(alarm),
                            color: _getAlarmColor(alarm),
                            size: 32,
                          ),
                          title: Text(
                            alarm.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: alarm.isEnabled ? null : Colors.grey,
                              decoration: isExpired && alarm.isEnabled
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          subtitle: Text(
                            _formatDateTime(alarm.dateTime),
                            style: TextStyle(
                              color: alarm.isEnabled ? _getAlarmColor(alarm) : Colors.grey,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: alarm.isEnabled,
                                onChanged: (_) => _toggleAlarm(alarm.id),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _showDeleteConfirmation(alarm),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addAlarm,
        tooltip: 'Add Alarm',
        child: const Icon(Icons.add),
      ),
    );
  }
}