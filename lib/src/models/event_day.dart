import 'package:flutter/foundation.dart';

import 'activity_item.dart';

/// Un día del evento (por ejemplo «Sábado» o «Domingo») con su itinerario.
@immutable
class EventDay {
  EventDay({
    required this.id,
    required this.name,
    required this.date,
    this.forceRunAt,
    List<ActivityItem> activities = const [],
  }) : activities = List.unmodifiable(activities);

  final String id;

  /// Etiqueta legible del día, por ejemplo «Sábado 18».
  final String name;

  /// Fecha del evento a medianoche. Las actividades cuelgan de esta fecha.
  final DateTime date;

  /// Instante en el que el operador decidió **empezar este programa ahora**,
  /// o `null` si el día se ejecuta en su fecha de verdad.
  ///
  /// Es lo que permite ensayar un evento que aún no ha llegado, o repetir uno
  /// pasado, sin tocar el guion: el itinerario no se mueve entero sobre el
  /// día de hoy (eso dejaría todo el programa medio Finished cuando la primera
  /// actividad es de la tarde), sino que se **desplaza** de modo que la primera
  /// actividad empieza en este instante y las siguientes caen donde toque,
  /// respetando su duración y sus huecos.
  ///
  /// Guardar el instante —y no «ahora» a cada lectura— es lo que mantiene el
  /// programa avanzando mientras el operador lo mira: si se recalculara, el
  /// reloj nunca bajaría de la duración de la primera actividad.
  final DateTime? forceRunAt;

  /// `true` si el día se está ejecutando por el operador, fuera de su fecha.
  bool get forceRun => forceRunAt != null;

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
    DateTime? forceRunAt,
    bool clearForceRun = false,
    List<ActivityItem>? activities,
  }) {
    return EventDay(
      id: id ?? this.id,
      name: name ?? this.name,
      date: date ?? this.date,
      forceRunAt: clearForceRun ? null : (forceRunAt ?? this.forceRunAt),
      activities: activities ?? this.activities,
    );
  }

  /// Cuánto hay que adelantar el guion para que la primera actividad
  /// empiece en [anchor].
  ///
  /// Es una resta de instantes, no un cambio de fecha: así el programa mantiene
  /// exactamente sus duraciones y sus huecos, y lo único que cambia es dónde
  /// arranca.
  Duration shiftToStartAt(DateTime anchor) {
    final sorted = sortedActivities;
    if (sorted.isEmpty) return Duration.zero;
    return anchor.difference(sorted.first.startTime);
  }

  /// El itinerario tal y como debe ejecutarse cuando se arranca en [anchor]:
  /// la primera actividad empieza ahí y las demás, donde caigan.
  List<ActivityItem> activitiesStartingAt(DateTime anchor) {
    final shift = shiftToStartAt(anchor);
    if (shift == Duration.zero) return activities;
    return [for (final item in activities) _shifted(item, shift)];
  }

  /// Devuelve [item] tal y como está **guardado**, deshaciendo el desplazamiento
  /// del ensayo.
  ///
  /// Es el camino de vuelta de [activitiesStartingAt]: con el día en marcha, la
  /// lista de actividades ya trae las horas desplazadas, y cualquier cosa que
  /// vaya a **escribir** esa actividad (editarla, deshacer un borrado) tiene que
  /// volver a las suyas. Si no, al guardar se escribiría la hora del ensayo en
  /// el archivo y el evento de verdad se mudaría de hora.
  ActivityItem storedActivity(ActivityItem item) {
    if (!forceRun) return item;
    final shift = shiftToStartAt(forceRunAt!);
    if (shift == Duration.zero) return item;
    return _shifted(item, -shift);
  }

  static ActivityItem _shifted(ActivityItem item, Duration delta) =>
      item.copyWith(
        startTime: item.startTime.add(delta),
        endTime: item.endTime?.add(delta),
      );

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
    'forceRunAt': forceRunAt?.toIso8601String(),
    'activities': activities.map((a) => a.toJson()).toList(),
  };

  factory EventDay.fromJson(Map<dynamic, dynamic> json) => EventDay(
    id: json['id'] as String,
    name: (json['name'] as String?) ?? '',
    date: DateTime.parse(json['date'] as String),
    forceRunAt: _readForceRunAt(json),
    activities: ((json['activities'] as List?) ?? const [])
        .map((e) => ActivityItem.fromJson(e as Map<dynamic, dynamic>))
        .toList(),
  );

  /// Lee el instante de arranque del ensayo.
  ///
  /// Un archivo viejo solo guardaba la marca, sin la hora de arranque: se
  /// reancla al momento de leerlo, que es lo más parecido a lo que se estaba
  /// viendo.
  static DateTime? _readForceRunAt(Map<dynamic, dynamic> json) {
    final raw = json['forceRunAt'];
    if (raw is String) return DateTime.tryParse(raw);
    return json['forceRun'] == true ? DateTime.now() : null;
  }
}
