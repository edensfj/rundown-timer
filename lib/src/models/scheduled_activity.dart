import 'package:flutter/foundation.dart';

import '../core/app_config.dart';
import 'activity_item.dart';

/// Estado visual de una actividad respecto al reloj.
enum ActivityStatus { past, active, upcoming }

/// Una actividad junto con su hora de fin **resuelta**.
///
/// El modelo [ActivityItem] normalmente no conoce su duración; la inferencia
/// ocurre a nivel de lista en [resolveSchedule], que empareja cada actividad con
/// el `startTime` de la siguiente. La única excepción es
/// [ActivityItem.endTime], que cuando está presente manda sobre la deducción.
@immutable
class ScheduledActivity {
  const ScheduledActivity({
    required this.item,
    required this.startTime,
    required this.endTime,
    required this.isLast,
    this.hasExplicitEnd = false,
  });

  final ActivityItem item;
  final DateTime startTime;

  /// `startTime` de la siguiente actividad, `startTime + lastDuration` cuando es
  /// la última, o el [ActivityItem.endTime] explícito si lo hay.
  final DateTime endTime;

  final bool isLast;

  /// `true` cuando la hora de fin la fijó el usuario a mano.
  final bool hasExplicitEnd;

  Duration get plannedDuration => endTime.difference(startTime);

  ActivityStatus statusAt(DateTime now) {
    if (now.isBefore(startTime)) return ActivityStatus.upcoming;
    if (now.isBefore(endTime)) return ActivityStatus.active;
    return ActivityStatus.past;
  }

  /// Posición de la actividad dentro del cronograma.
  int indexOf(List<ScheduledActivity> schedule) =>
      schedule.indexWhere((s) => s.item.id == item.id);

  @override
  String toString() => 'ScheduledActivity(${item.title}, $startTime → $endTime)';
}

/// Ordena las actividades y deduce la hora de fin de cada una.
///
/// Prioridad para la hora de fin:
/// 1. El `endTime` explícito de la actividad, si lo tiene y es posterior al
///    inicio. Permite representar itinerarios reales con cierres propios.
/// 2. El `startTime` de la siguiente actividad (el caso normal).
/// 3. `startTime + lastDuration` para la última, o cuando la siguiente no es
///    posterior (evita duraciones cero que dispararían el tiempo excedido).
List<ScheduledActivity> resolveSchedule(
  List<ActivityItem> items, {
  Duration lastDuration = AppConfig.defaultLastActivityDuration,
}) {
  final sorted = [...items];
  sorted.sort((a, b) => a.startTime.compareTo(b.startTime));

  final resolved = <ScheduledActivity>[];
  for (var i = 0; i < sorted.length; i++) {
    final current = sorted[i];
    final isLast = i == sorted.length - 1;
    final next = isLast ? null : sorted[i + 1];

    final explicitEnd = current.endTime;
    final hasExplicit = explicitEnd != null && explicitEnd.isAfter(current.startTime);

    final DateTime derivedEnd;
    if (hasExplicit) {
      derivedEnd = explicitEnd;
    } else if (next != null && next.startTime.isAfter(current.startTime)) {
      derivedEnd = next.startTime;
    } else {
      derivedEnd = current.startTime.add(lastDuration);
    }

    resolved.add(ScheduledActivity(
      item: current,
      startTime: current.startTime,
      endTime: derivedEnd,
      isLast: isLast,
      hasExplicitEnd: hasExplicit,
    ));
  }
  return resolved;
}

/// Índice de la actividad en curso para un instante dado: la última que ya
/// empezó. Devuelve `-1` si el evento todavía no ha comenzado.
int resolveRunIndex(List<ScheduledActivity> schedule, DateTime now) {
  var found = -1;
  for (var i = 0; i < schedule.length; i++) {
    if (!schedule[i].startTime.isAfter(now)) {
      found = i;
    } else {
      break;
    }
  }
  return found;
}
