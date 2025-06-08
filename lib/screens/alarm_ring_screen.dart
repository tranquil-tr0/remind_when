import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart';

class AlarmRingScreen extends StatefulWidget {
  final AlarmSettings alarmSettings;

  const AlarmRingScreen({
    super.key,
    required this.alarmSettings,
  });

  @override
  State<AlarmRingScreen> createState() => _AlarmRingScreenState();
}

class _AlarmRingScreenState extends State<AlarmRingScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _dismissAlarm() async {
    // Stop the alarm
    await Alarm.stop(widget.alarmSettings.id);
    
    // Navigate back to home screen
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _snoozeAlarm() async {
    // Stop current alarm
    await Alarm.stop(widget.alarmSettings.id);
    
    // Set a new alarm for 5 minutes later
    final snoozeDateTime = DateTime.now().add(const Duration(minutes: 5));
    final snoozeSettings = AlarmSettings(
      id: widget.alarmSettings.id,
      dateTime: snoozeDateTime,
      assetAudioPath: widget.alarmSettings.assetAudioPath,
      loopAudio: widget.alarmSettings.loopAudio,
      vibrate: widget.alarmSettings.vibrate,
      volume: widget.alarmSettings.volume,
      fadeDuration: widget.alarmSettings.fadeDuration,
      notificationTitle: '${widget.alarmSettings.notificationTitle} (Snoozed)',
      notificationBody: widget.alarmSettings.notificationBody,
      enableNotificationOnKill: widget.alarmSettings.enableNotificationOnKill,
    );
    
    await Alarm.set(alarmSettings: snoozeSettings);
    
    // Navigate back to home screen
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated alarm icon
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.red,
                          width: 3,
                        ),
                      ),
                      child: const Icon(
                        Icons.alarm,
                        size: 80,
                        color: Colors.red,
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 40),
              
              // Alarm title
              Text(
                widget.alarmSettings.notificationTitle.isNotEmpty
                    ? widget.alarmSettings.notificationTitle
                    : 'Alarm',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              // Alarm time
              Text(
                _formatTime(widget.alarmSettings.dateTime),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 24,
                ),
              ),
              
              const SizedBox(height: 60),
              
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Snooze button
                  GestureDetector(
                    onTap: _snoozeAlarm,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.orange,
                          width: 2,
                        ),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.snooze,
                            size: 40,
                            color: Colors.orange,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Snooze',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Dismiss button
                  GestureDetector(
                    onTap: _dismissAlarm,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.green,
                          width: 2,
                        ),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.stop,
                            size: 40,
                            color: Colors.green,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Dismiss',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 40),
              
              // Alarm body text
              if (widget.alarmSettings.notificationBody.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    widget.alarmSettings.notificationBody,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}