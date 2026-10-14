import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_config.dart';
import '../models/event_day.dart';
import '../models/scheduled_activity.dart';
import 'clock_provider.dart';
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
final activeDayIdProvider = Provider<String?>((ref) => ref.watch(activeDayProvider)?.id);

/// Cronograma del día activo con las horas de fin ya inferidas.
///
/// No depende del reloj, así que su valor se cachea y solo se recalcula cuando
/// cambian las actividades o el día.
final activeScheduleProvider = Provider<List<ScheduledActivity>>((ref) {
  final day = ref.watch(activeDayProvider);
  if (day == null) return const [];
  return resolveSchedule(
    day.activities,
    lastDuration: AppConfig.defaultLastActivityDuration,
  );
});

/// Estado de cada actividad (pasada / en curso / futura) en el instante actual.
///
/// Se recalcula cada segundo porque depende del reloj, pero su valor solo
/// cambia cuando algún estado cambia de verdad: las tarjetas observan una
/// única entrada con `select`.
final activityStatusProvider = Provider<Map<String, ActivityStatus>>((ref) {
  final now = ref.watch(clockProvider);
  final schedule = ref.watch(activeScheduleProvider);
  return {
    for (final slot in schedule) slot.item.id: slot.statusAt(now),
  };
});
