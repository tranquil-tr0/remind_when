import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart';
import '../utils/alarm_storage.dart';
import 'custom_sounds_manager.dart';

enum RepeatOption {
  once('Once', []),
  daily('Daily', [1, 2, 3, 4, 5, 6, 7]),
  weekdays('Weekdays', [1, 2, 3, 4, 5]),
  weekends('Weekends', [6, 7]),
  weekly('Weekly', []);

  const RepeatOption(this.label, this.days);
  final String label;
  final List<int> days; // 1=Monday, 7=Sunday
}

enum SnoozeDuration {
  minutes5('5 minutes', 5),
  minutes10('10 minutes', 10),
  minutes15('15 minutes', 15),
  minutes30('30 minutes', 30);

  const SnoozeDuration(this.label, this.minutes);
  final String label;
  final int minutes;
}

class AddAlarmModal extends StatefulWidget {
  const AddAlarmModal({super.key});

  @override
  State<AddAlarmModal> createState() => _AddAlarmModalState();
}

class _AddAlarmModalState extends State<AddAlarmModal> {
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _alarmTitle = '';
  RepeatOption _selectedRepeat = RepeatOption.once;
  SnoozeDuration _selectedSnooze = SnoozeDuration.minutes5;
  String _selectedSound = 'assets/alarm.mp3';
  String _selectedSoundName = 'Default Alarm';
  bool _vibrate = true;
  double _volume = 0.8;

  final _titleController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: const TimePickerThemeData(
              backgroundColor: Colors.white,
              hourMinuteTextColor: Colors.black87,
              dayPeriodTextColor: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _showSoundPicker() async {
    await showDialog(
      context: context,
      builder: (context) => CustomSoundsManager(
        selectedSoundPath: _selectedSound,
        onSoundSelected: (soundPath, soundName) {
          setState(() {
            _selectedSound = soundPath;
            _selectedSoundName = soundName;
          });
        },
      ),
    );
  }

  DateTime _getNextAlarmDateTime() {
    final now = DateTime.now();
    var alarmDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    // If the time has already passed today, set it for tomorrow
    if (alarmDateTime.isBefore(now)) {
      alarmDateTime = alarmDateTime.add(const Duration(days: 1));
    }

    return alarmDateTime;
  }

  Future<void> _saveAlarm() async {
    final alarmDateTime = _getNextAlarmDateTime();
    
    // Generate unique ID
    final alarmId = DateTime.now().millisecondsSinceEpoch % 1000000;

    final title = _alarmTitle.isEmpty ? 'Alarm' : _alarmTitle;

    final alarmSettings = AlarmSettings(
      id: alarmId,
      dateTime: alarmDateTime,
      assetAudioPath: _selectedSound,
      loopAudio: true,
      vibrate: _vibrate,
      volume: _volume,
      fadeDuration: 3.0,
      notificationTitle: title,
      notificationBody: 'Alarm set for ${_selectedTime.format(context)}',
      enableNotificationOnKill: true,
    );

    final success = await Alarm.set(alarmSettings: alarmSettings);
    
    if (success) {
      // Store snooze duration for this alarm
      await AlarmStorage.setSnoozeData(alarmId, _selectedSnooze.minutes);
    }
    
    if (mounted) {
      if (success) {
        Navigator.of(context).pop(true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Alarm "$title" set for ${_selectedTime.format(context)}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to set alarm'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.inversePrimary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.alarm_add, size: 28),
                  const SizedBox(width: 12),
                  const Text(
                    'Create Alarm',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Time Picker
                    _buildSection(
                      'Time',
                      GestureDetector(
                        onTap: _selectTime,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time, color: Colors.deepPurple),
                              const SizedBox(width: 12),
                              Text(
                                _selectedTime.format(context),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              const Icon(Icons.arrow_drop_down),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Alarm Title
                    _buildSection(
                      'Alarm Title',
                      TextField(
                        controller: _titleController,
                        onChanged: (value) => _alarmTitle = value,
                        decoration: InputDecoration(
                          hintText: 'Enter alarm name (optional)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.label_outline),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Repeat Schedule
                    _buildSection(
                      'Repeat',
                      DropdownButtonFormField<RepeatOption>(
                        value: _selectedRepeat,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.repeat),
                        ),
                        items: RepeatOption.values.map((option) {
                          return DropdownMenuItem(
                            value: option,
                            child: Text(option.label),
                          );
                        }).toList(),
                        onChanged: (RepeatOption? value) {
                          if (value != null) {
                            setState(() {
                              _selectedRepeat = value;
                            });
                          }
                        },
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Snooze Duration
                    _buildSection(
                      'Snooze Duration',
                      DropdownButtonFormField<SnoozeDuration>(
                        value: _selectedSnooze,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.snooze),
                        ),
                        items: SnoozeDuration.values.map((duration) {
                          return DropdownMenuItem(
                            value: duration,
                            child: Text(duration.label),
                          );
                        }).toList(),
                        onChanged: (SnoozeDuration? value) {
                          if (value != null) {
                            setState(() {
                              _selectedSnooze = value;
                            });
                          }
                        },
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Alarm Sound
                    _buildSection(
                      'Alarm Sound',
                      GestureDetector(
                        onTap: () => _showSoundPicker(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.music_note, color: Colors.deepPurple),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _selectedSoundName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Volume Control
                    _buildSection(
                      'Volume',
                      Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.volume_down, color: Colors.grey),
                              Expanded(
                                child: Slider(
                                  value: _volume,
                                  onChanged: (value) {
                                    setState(() {
                                      _volume = value;
                                    });
                                  },
                                  min: 0.1,
                                  max: 1.0,
                                  divisions: 9,
                                ),
                              ),
                              const Icon(Icons.volume_up, color: Colors.grey),
                            ],
                          ),
                          Text(
                            '${(_volume * 100).round()}%',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Vibration Toggle
                    _buildSection(
                      'Vibration',
                      SwitchListTile(
                        value: _vibrate,
                        onChanged: (value) {
                          setState(() {
                            _vibrate = value;
                          });
                        },
                        title: const Text('Enable vibration'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Action Buttons
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveAlarm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Save Alarm'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        content,
      ],
    );
  }
}