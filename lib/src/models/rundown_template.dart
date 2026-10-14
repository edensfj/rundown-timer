import 'package:flutter/foundation.dart';

import 'activity_item.dart';
import 'event_day.dart';
import 'scheduled_activity.dart';

/// Una actividad dentro de una plantilla.
///
/// Guarda una **duración**, no una hora: una plantilla describe el ritmo del
/// programa («20 min alabanza, 45 min prédica»), no un reloj concreto. Las horas
/// se calculan al aplicarla sobre un día, desde la hora de inicio que elijas.
@immutable
class TemplateActivity {
  const TemplateActivity({
    required this.title,
    required this.duration,
    this.description,
    this.responsible,
    this.location,
  });

  final String title;
  final Duration duration;
  final String? description;
  final String? responsible;
  final String? location;

  TemplateActivity copyWith({
    String? title,
    Duration? duration,
    String? description,
    String? responsible,
    String? location,
  }) {
    return TemplateActivity(
      title: title ?? this.title,
      duration: duration ?? this.duration,
      description: description ?? this.description,
      responsible: responsible ?? this.responsible,
      location: location ?? this.location,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'durationSeconds': duration.inSeconds,
        'description': description,
        'responsible': responsible,
        'location': location,
      };

  factory TemplateActivity.fromJson(Map<dynamic, dynamic> json) =>
      TemplateActivity(
        title: (json['title'] as String?) ?? '',
        duration: Duration(seconds: (json['durationSeconds'] as num?)?.toInt() ?? 0),
        description: _asString(json['description']),
        responsible: _asString(json['responsible']),
        location: _asString(json['location']),
      );

  static String? _asString(Object? v) {
    if (v == null) return null;
    final t = v.toString().trim();
    return t.isEmpty ? null : t;
  }
}

/// Un programa reutilizable: una secuencia de actividades con sus duraciones.
///
/// El caso típico es el culto de todos los domingos: se define una vez y se
/// aplica a cada domingo nuevo eligiendo la hora de comienzo.
@immutable
class RundownTemplate {
  RundownTemplate({
    required this.id,
    required this.name,
    List<TemplateActivity> activities = const [],
  }) : activities = List.unmodifiable(activities);

  final String id;
  final String name;
  final List<TemplateActivity> activities;

  Duration get totalDuration => activities.fold(
        Duration.zero,
        (sum, a) => sum + a.duration,
      );

  bool get isEmpty => activities.isEmpty;

  /// Crea una plantilla a partir de un día ya armado, conservando las
  /// duraciones reales que tienen sus actividades.
  ///
  /// Así se puede montar el programa una vez a mano y guardarlo para
  /// reutilizarlo, sin volver a escribirlo.
  factory RundownTemplate.fromDay(
    EventDay day, {
    required String id,
    required String name,
  }) {
    final schedule = resolveSchedule(day.activities);
    return RundownTemplate(
      id: id,
      name: name,
      activities: [
        for (final slot in schedule)
          TemplateActivity(
            title: slot.item.title,
            duration: slot.plannedDuration,
            description: slot.item.description,
            responsible: slot.item.responsible,
            location: slot.item.location,
          ),
      ],
    );
  }

  RundownTemplate copyWith({
    String? id,
    String? name,
    List<TemplateActivity>? activities,
  }) {
    return RundownTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      activities: activities ?? this.activities,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'activities': activities.map((a) => a.toJson()).toList(),
      };

  factory RundownTemplate.fromJson(Map<dynamic, dynamic> json) =>
      RundownTemplate(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? '',
        activities: ((json['activities'] as List?) ?? const [])
            .map((e) => TemplateActivity.fromJson(e as Map<dynamic, dynamic>))
            .toList(),
      );
}

/// Convierte una plantilla en actividades reales de un día.
///
/// Las coloca en cadena desde [start]: cada una empieza cuando acaba la
/// anterior. Se fija la **hora de fin explícita** en lugar de dejar que se
/// deduzca, porque si no la última caería en la duración por defecto y perdería
/// la duración de la plantilla.
///
/// `nextId` permite inyectar los ids para poder probar la función.
List<ActivityItem> materializeTemplate(
  RundownTemplate template,
  DateTime start, {
  required String Function(int index) nextId,
}) {
  final items = <ActivityItem>[];
  var cursor = start;

  for (var i = 0; i < template.activities.length; i++) {
    final activity = template.activities[i];
    final end = cursor.add(activity.duration);

    items.add(ActivityItem(
      id: nextId(i),
      title: activity.title,
      startTime: cursor,
      endTime: end,
      description: activity.description,
      responsible: activity.responsible,
      location: activity.location,
    ));

    cursor = end;
  }
  return items;
}

/// Duración con la que arranca una fila que el usuario añade a mano.
///
/// Solo es un punto de partida editable, no un valor impuesto: el usuario lo
/// cambia al escribir.
const Duration kTemplateDefaultDuration = Duration(minutes: 15);
