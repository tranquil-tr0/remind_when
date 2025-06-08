import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:alarm/alarm.dart';
import '../utils/alarm_storage.dart';

class CustomSoundsManager extends StatefulWidget {
  final String? selectedSoundPath;
  final Function(String soundPath, String soundName) onSoundSelected;

  const CustomSoundsManager({
    super.key,
    this.selectedSoundPath,
    required this.onSoundSelected,
  });

  @override
  State<CustomSoundsManager> createState() => _CustomSoundsManagerState();
}

class _CustomSoundsManagerState extends State<CustomSoundsManager> {
  List<Map<String, String>> _availableSounds = [];
  bool _isLoading = true;
  String? _playingSound;

  @override
  void initState() {
    super.initState();
    _loadSounds();
  }

  Future<void> _loadSounds() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final sounds = await AlarmStorage.getCustomSounds();
      setState(() {
        _availableSounds = sounds;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading sounds: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addCustomSound() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final fileName = result.files.single.name;
        
        // Show dialog to get display name
        final displayName = await _showNameDialog(fileName);
        if (displayName == null || displayName.trim().isEmpty) {
          return;
        }

        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        final savedPath = await AlarmStorage.saveCustomSound(filePath, displayName.trim());
        
        if (!mounted) return;
        
        Navigator.of(context).pop(); // Close loading dialog

        if (savedPath != null) {
          await _loadSounds(); // Refresh the list
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Sound "$displayName" added successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to add custom sound'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding sound: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _showNameDialog(String defaultName) async {
    final controller = TextEditingController(text: defaultName.replaceAll('.mp3', '').replaceAll('.wav', '').replaceAll('.m4a', ''));
    
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Name Your Sound'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Display Name',
            hintText: 'Enter a name for this sound',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSound(String soundPath, String soundName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Sound'),
        content: Text('Are you sure you want to delete "$soundName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await AlarmStorage.deleteCustomSound(soundPath);
      if (success) {
        await _loadSounds();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sound "$soundName" deleted'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete sound'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _previewSound(String soundPath) async {
    try {
      // Stop any currently playing sound
      if (_playingSound != null) {
        await Alarm.stop(999999); // Use a temp ID for preview
        setState(() {
          _playingSound = null;
        });
        return;
      }

      // Play the selected sound for preview
      setState(() {
        _playingSound = soundPath;
      });

      final previewAlarm = AlarmSettings(
        id: 999999, // Temporary ID for preview
        dateTime: DateTime.now().add(const Duration(seconds: 1)),
        assetAudioPath: soundPath,
        loopAudio: false,
        vibrate: false,
        volume: 0.5,
        fadeDuration: 0.0,
        notificationTitle: 'Preview',
        notificationBody: 'Sound preview',
        enableNotificationOnKill: false,
      );

      await Alarm.set(alarmSettings: previewAlarm);

      // Stop preview after 3 seconds
      Future.delayed(const Duration(seconds: 3), () async {
        await Alarm.stop(999999);
        if (mounted) {
          setState(() {
            _playingSound = null;
          });
        }
      });
    } catch (e) {
      setState(() {
        _playingSound = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing sound: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.library_music, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Alarm Sounds',
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
            const Divider(),

            // Add sound button
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _addCustomSound,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Custom Sound'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Sounds list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _availableSounds.length,
                      itemBuilder: (context, index) {
                        final sound = _availableSounds[index];
                        final soundPath = sound['path']!;
                        final soundName = sound['name']!;
                        final soundType = sound['type']!;
                        final isSelected = soundPath == widget.selectedSoundPath;
                        final isPlaying = _playingSound == soundPath;

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: Icon(
                              soundType == 'builtin' ? Icons.music_note : Icons.audio_file,
                              color: isSelected ? Colors.deepPurple : Colors.grey,
                            ),
                            title: Text(
                              soundName,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Colors.deepPurple : null,
                              ),
                            ),
                            subtitle: Text(
                              soundType == 'builtin' ? 'Built-in sound' : 'Custom sound',
                              style: TextStyle(
                                color: isSelected ? Colors.deepPurple.shade300 : Colors.grey,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Preview button
                                IconButton(
                                  onPressed: () => _previewSound(soundPath),
                                  icon: Icon(
                                    isPlaying ? Icons.stop : Icons.play_arrow,
                                    color: isPlaying ? Colors.red : Colors.blue,
                                  ),
                                  tooltip: isPlaying ? 'Stop preview' : 'Preview sound',
                                ),
                                // Delete button (only for custom sounds)
                                if (soundType == 'custom')
                                  IconButton(
                                    onPressed: () => _deleteSound(soundPath, soundName),
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    tooltip: 'Delete sound',
                                  ),
                              ],
                            ),
                            selected: isSelected,
                            selectedTileColor: Colors.deepPurple.withValues(alpha: 0.1),
                            onTap: () {
                              widget.onSoundSelected(soundPath, soundName);
                              Navigator.of(context).pop();
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Stop any playing preview sound
    if (_playingSound != null) {
      Alarm.stop(999999);
    }
    super.dispose();
  }
}