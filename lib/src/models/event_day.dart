import 'package:flutter/foundation.dart';

import 'activity_item.dart';

/// Un día del evento (por ejemplo «Sábado» o «Domingo») con su itinerario.
@immutable
class EventDay {
  EventDay({
    required this.id,
    required this.name,
    required this.date,
    List<ActivityItem> activities = const [],
  }) : activities = List.unmodifiable(activities);

  final String id;

  /// Etiqueta legible del día, por ejemplo «Sábado 18».
  final String name;

  /// Fecha del evento a medianoche. Las actividades cuelgan de esta fecha.
  final DateTime date;

  final List<ActivityItem> activities;

  /// Actividades ordenadas cronológicamente por `startTime`.
  List<ActivityItem> get sortedActivities {
    final sorted = [...activities];
    sorted.sort((a, b) => a.startTime.compareTo(b.startTime));
    return sorted;
  }

  bool get isEmpty => activities.isEmpty;

  EventDay copyWith({
    String? id,
    String? name,
    DateTime? date,
    List<ActivityItem>? activities,
  }) {
    return EventDay(
      id: id ?? this.id,
      name: name ?? this.name,
      date: date ?? this.date,
      activities: activities ?? this.activities,
    );
  }

  /// Inserta o reemplaza [item] conservando el orden cronológico.
  EventDay upsertActivity(ActivityItem item) {
    final next = [...activities];
    final index = next.indexWhere((a) => a.id == item.id);
    if (index >= 0) {
      next[index] = item;
    } else {
      next.add(item);
    }
    return copyWith(activities: next);
  }

  EventDay removeActivity(String activityId) => copyWith(
        activities: activities.where((a) => a.id != activityId).toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'date': date.toIso8601String(),
        'activities': activities.map((a) => a.toJson()).toList(),
      };

  factory EventDay.fromJson(Map<dynamic, dynamic> json) => EventDay(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? '',
        date: DateTime.parse(json['date'] as String),
        activities: ((json['activities'] as List?) ?? const [])
            .map((e) => ActivityItem.fromJson(e as Map<dynamic, dynamic>))
            .toList(),
      );
}
