import 'package:flutter/foundation.dart';

import 'activity_notice.dart';

/// Una actividad del cronograma.
///
/// Normalmente **no** lleva hora de fin: se deduce del `startTime` de la
/// siguiente actividad (ver `resolveSchedule`). [endTime] es una excepción
/// opcional: cuando está presente manda sobre la deducción, para los casos en
/// que el itinerario real sí define un cierre (por ejemplo, una actividad que
/// dura 70 minutos y es la última del día).
@immutable
class ActivityItem {
  const ActivityItem({
    required this.id,
    required this.title,
    required this.startTime,
    this.endTime,
    this.description,
    this.responsible,
    this.location,
    this.notice,
  });

  final String id;

  /// Título o descripción principal. Obligatorio.
  final String title;

  /// Hora de inicio. Siempre incluye la fecha del evento.
  final DateTime startTime;

  /// Hora de fin explícita. Opcional: si es `null`, se deduce de la siguiente
  /// actividad o, en la última, de la duración por defecto.
  final DateTime? endTime;

  /// Detalle o notas adicionales. Opcional.
  final String? description;

  /// Persona o equipo a cargo. Opcional.
  final String? responsible;

  /// Lugar o espacio. Opcional.
  final String? location;

  /// Texto que sale a la pantalla al empezar o al terminar la actividad.
  /// Opcional: sin aviso, la actividad se comporta como siempre.
  final ActivityNotice? notice;

  bool get hasExplicitEnd => endTime != null;

  ActivityItem copyWith({
    String? id,
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    String? description,
    String? responsible,
    String? location,
    ActivityNotice? notice,
    bool clearEndTime = false,
    bool clearDescription = false,
    bool clearResponsible = false,
    bool clearLocation = false,
    bool clearNotice = false,
  }) {
    return ActivityItem(
      id: id ?? this.id,
      title: title ?? this.title,
      startTime: startTime ?? this.startTime,
      endTime: clearEndTime ? null : (endTime ?? this.endTime),
      description: clearDescription ? null : (description ?? this.description),
      responsible: clearResponsible ? null : (responsible ?? this.responsible),
      location: clearLocation ? null : (location ?? this.location),
      notice: clearNotice ? null : (notice ?? this.notice),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'description': description,
    'responsible': responsible,
    'location': location,
    'notice': notice?.toJson(),
  };

  factory ActivityItem.fromJson(Map<dynamic, dynamic> json) => ActivityItem(
    id: json['id'] as String,
    title: (json['title'] as String?) ?? '',
    startTime: DateTime.parse(json['startTime'] as String),
    endTime: _asDate(json['endTime']),
    description: _asString(json['description']),
    responsible: _asString(json['responsible']),
    location: _asString(json['location']),
    notice: _asNotice(json['notice']),
  );

  static DateTime? _asDate(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static String? _asString(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static ActivityNotice? _asNotice(Object? value) {
    if (value is! Map) return null;
    final notice = ActivityNotice.fromJson(value.cast<dynamic, dynamic>());
    return notice.isUsable ? notice : null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActivityItem &&
          other.id == id &&
          other.title == title &&
          other.startTime == startTime &&
          other.endTime == endTime &&
          other.description == description &&
          other.responsible == responsible &&
          other.location == location &&
          other.notice == notice;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    startTime,
    endTime,
    description,
    responsible,
    location,
    notice,
  );
}
