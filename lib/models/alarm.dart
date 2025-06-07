import 'dart:convert';

class Alarm {
  final String id;
  final String title;
  final DateTime dateTime;
  final bool isEnabled;

  Alarm({
    required this.id,
    required this.title,
    required this.dateTime,
    this.isEnabled = true,
  });

  Alarm copyWith({
    String? id,
    String? title,
    DateTime? dateTime,
    bool? isEnabled,
  }) {
    return Alarm(
      id: id ?? this.id,
      title: title ?? this.title,
      dateTime: dateTime ?? this.dateTime,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'dateTime': dateTime.millisecondsSinceEpoch,
      'isEnabled': isEnabled,
    };
  }

  factory Alarm.fromMap(Map<String, dynamic> map) {
    return Alarm(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      dateTime: DateTime.fromMillisecondsSinceEpoch(map['dateTime']),
      isEnabled: map['isEnabled'] ?? true,
    );
  }

  String toJson() => json.encode(toMap());

  factory Alarm.fromJson(String source) => Alarm.fromMap(json.decode(source));
}