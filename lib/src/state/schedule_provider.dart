import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_config.dart';
import '../models/activity_item.dart';
import '../models/event_day.dart';
import '../models/scheduled_activity.dart';
import 'clock_provider.dart';
import 'quick_timer_provider.dart';
import 'rundown_provider.dart';
import 'selected_day_provider.dart';

/// Día actualmente en edición.
///
/// Si el día guardado ya no existe (fue borrado en otra sesión), cae al
/// primero disponible para no dejar al usuario sin contexto.
final activeDayProvider = Provider<EventDay?>((ref) {
  final days = ref.watch(sortedDaysProvider);
  if (days.isEmpty) return null;

  final selectedId = ref.watch(selectedDayProvider);
  if (selectedId != null) {
    for (final day in days) {
      if (day.id == selectedId) return day;
    }
  }
  return days.first;
});

/// Id del día actualmente en edición (o `null` si no hay días).
final activeDayIdProvider = Provider<String?>(
  (ref) => ref.watch(activeDayProvider)?.id,
);

/// Identifica **de dónde sale lo que se está proyectando**: el itinerario del
/// día o un contador suelto.
///
/// El estado del escenario observa este valor para reiniciarse cuando la fuente
/// cambia. Sin esto, al pasar de un contador al itinerario el índice guardado
/// podría apuntar a una actividad que ya no existe.
final stageSourceIdProvider = Provider<String?>((ref) {
  final quick = ref.watch(quickTimerProvider);
  if (quick != null) return 'quick:${quick.id}';
  return 'day:${ref.watch(activeDayProvider)?.id}';
});

/// Cronograma del **día** que se está editando, con las horas de fin inferidas.
///
/// Es lo que pinta la lista del panel: no lo toca el contador rápido, que es
/// algo suelto y no forma parte del programa del día. Si un contador rápido
/// activo cambiara esta lista, la programación del día parecería borrada.
final dayScheduleProvider = Provider<List<ScheduledActivity>>((ref) {
  final day = ref.watch(activeDayProvider);
  if (day == null) return const [];

  return resolveSchedule(
    day.activities,
    lastDuration: AppConfig.defaultLastActivityDuration,
  );
});

/// Cronograma que se está **proyectando**: el del día, o el contador rápido.
///
/// Con un contador rápido activo se construye un cronograma virtual de una sola
/// actividad: así todo el motor del escenario (countdown, fases, alerta roja,
/// pausa, reinicio) funciona igual sin duplicar una línea de lógica. Ojo: esto
/// es solo para el escenario; la lista del panel usa [dayScheduleProvider].
final activeScheduleProvider = Provider<List<ScheduledActivity>>((ref) {
  final quick = ref.watch(quickTimerProvider);

  if (quick != null) {
    return resolveSchedule([
      ActivityItem(
        id: quick.id,
        title: quick.label,
        startTime: quick.startedAt,
        // Con hora de fin explícita, la duración pedida manda.
        endTime: quick.endsAt,
      ),
    ]);
  }

  return ref.watch(dayScheduleProvider);
});

/// Estado de cada actividad (pasada / en curso / futura) en el instante actual.
///
/// Se recalcula cada segundo porque depende del reloj, pero su valor solo
/// cambia cuando algún estado cambia de verdad: las tarjetas observan una
/// única entrada con `select`.
///
/// Va sobre el cronograma **del día**: las tarjetas de la lista son las del
/// programa, no el contador rápido.
final activityStatusProvider = Provider<Map<String, ActivityStatus>>((ref) {
  final now = ref.watch(clockProvider);
  final schedule = ref.watch(dayScheduleProvider);
  return {for (final slot in schedule) slot.item.id: slot.statusAt(now)};
});
