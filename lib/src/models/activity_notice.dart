import 'package:flutter/foundation.dart';

/// Cuándo sale el aviso de una actividad.
enum NoticeTrigger {
  /// En cuanto la actividad se pone en el escenario.
  onStart('Al empezar'),

  /// Cuando la actividad se da por acabada o se pasa a la siguiente.
  onEnd('Al terminar');

  const NoticeTrigger(this.label);

  final String label;
}

/// Cómo se limita el aviso: por tiempo o por número de pasadas.
enum NoticeLimit {
  /// Cruza en bucle durante un rato y se quita.
  duration('Por tiempo'),

  /// Cruza un número de veces exacto y se quita.
  repeats('Por repeticiones');

  const NoticeLimit(this.label);

  final String label;
}

/// Un texto que sale a la pantalla cuando una actividad empieza o termina.
///
/// Es la marquesina, pero disparada por la propia actividad: un DESCANSO manda
/// su «pueden salir del salón» sin que nadie tenga que escribirlo en el chat, y
/// una preparación avisa al acabar sin que el operador se acuerde. El texto cruza
/// con los ajustes de la marquesina —velocidad, tamaño, dirección— y se quita
/// solo al cumplir su límite; no hay que acordarse de pararlo.
///
/// El aviso **no** entra en el chat de la marquesina: es de la actividad, no un
/// mensaje suelto, y ensuciar la lista con textos automáticos la haría inútil.
@immutable
class ActivityNotice {
  const ActivityNotice({
    required this.text,
    this.trigger = NoticeTrigger.onStart,
    this.limit = NoticeLimit.duration,
    this.duration = const Duration(minutes: 1),
    this.repeats = 2,
    this.showTimer = true,
  });

  /// Lo que se lee en la pantalla.
  final String text;

  final NoticeTrigger trigger;
  final NoticeLimit limit;

  /// Cuánto cruza el texto cuando [limit] es [NoticeLimit.duration].
  final Duration duration;

  /// Cuántas veces cruza cuando [limit] es [NoticeLimit.repeats].
  final int repeats;

  /// Si el reloj sigue viéndose mientras el aviso cruza. Se ajusta **por aviso**
  /// y no solo en los ajustes de la marquesina porque no es lo mismo un aviso
  /// sobre una actividad en curso que uno que ocupa la pantalla entera.
  final bool showTimer;

  /// `true` si hay algo que mandar. Un aviso sin texto no existe.
  bool get isUsable => text.trim().isNotEmpty;

  /// Cuánto dura el aviso, en pasadas o en tiempo, sabiendo lo que tarda el
  /// texto en cruzar la pantalla con [passDuration].
  ///
  /// Las repeticiones se traducen a tiempo aquí y no al revés: el motor de la
  /// marquesina solo sabe de un pase con final, y así «2 veces» son exactamente
  /// dos cruces completos.
  Duration totalDuration(Duration passDuration) =>
      limit == NoticeLimit.repeats ? passDuration * repeats : duration;

  ActivityNotice copyWith({
    String? text,
    NoticeTrigger? trigger,
    NoticeLimit? limit,
    Duration? duration,
    int? repeats,
    bool? showTimer,
  }) => ActivityNotice(
    text: text ?? this.text,
    trigger: trigger ?? this.trigger,
    limit: limit ?? this.limit,
    duration: duration ?? this.duration,
    repeats: repeats ?? this.repeats,
    showTimer: showTimer ?? this.showTimer,
  );

  Map<String, dynamic> toJson() => {
    'text': text,
    'trigger': trigger.name,
    'limit': limit.name,
    'durationSeconds': duration.inSeconds,
    'repeats': repeats,
    'showTimer': showTimer,
  };

  factory ActivityNotice.fromJson(Map<dynamic, dynamic> json) => ActivityNotice(
    text: (json['text'] as String?) ?? '',
    trigger: _enum(
      json['trigger'],
      NoticeTrigger.values,
      NoticeTrigger.onStart,
    ),
    limit: _enum(json['limit'], NoticeLimit.values, NoticeLimit.duration),
    duration: Duration(seconds: _asInt(json['durationSeconds']) ?? 60),
    repeats: (_asInt(json['repeats']) ?? 2).clamp(1, 99),
    showTimer: json['showTimer'] as bool? ?? true,
  );

  // Un dato corrupto no puede tumbar la app en mitad de un evento: se ignora y
  // se usa el valor de fábrica.
  static int? _asInt(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value');

  static T _enum<T extends Enum>(Object? value, List<T> values, T fallback) {
    for (final option in values) {
      if (option.name == value) return option;
    }
    return fallback;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActivityNotice &&
          other.text == text &&
          other.trigger == trigger &&
          other.limit == limit &&
          other.duration == duration &&
          other.repeats == repeats &&
          other.showTimer == showTimer;

  @override
  int get hashCode =>
      Object.hash(text, trigger, limit, duration, repeats, showTimer);
}
