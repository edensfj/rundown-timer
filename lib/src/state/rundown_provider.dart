import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/rundown_repository.dart';
import '../models/activity_item.dart';
import '../models/event_day.dart';
import 'selected_day_provider.dart';

/// Fuente de verdad del itinerario: la lista completa de días del evento.
///
/// Cada mutación actualiza el estado de forma síncrona (para que la UI no
/// parpadee) y luego persiste en Hive.
class RundownNotifier extends AsyncNotifier<List<EventDay>> {
  @override
  Future<List<EventDay>> build() async {
    return ref.read(repositoryProvider).loadDays();
  }

  Future<void> addDay({required String name, required DateTime date, required String id}) async {
    final day = EventDay(id: id, name: name, date: date);
    await _commit([..._days, day]);
    ref.read(selectedDayProvider.notifier).select(day.id);
  }

  Future<void> renameDay(String dayId, String name) async {
    await _commit(
      _days.map((d) => d.id == dayId ? d.copyWith(name: name) : d).toList(),
    );
  }

  Future<void> deleteDay(String dayId) async {
    final remaining = _days.where((d) => d.id != dayId).toList();
    if (selectedDayId == dayId) {
      ref.read(selectedDayProvider.notifier).select(
            remaining.isEmpty ? null : remaining.first.id,
          );
    }
    await _commit(remaining);
  }

  /// Inserta una actividad nueva o actualiza una existente en [dayId].
  Future<void> saveActivity({
    required String dayId,
    required ActivityItem item,
  }) async {
    await _commit(
      _days.map((d) => d.id == dayId ? d.upsertActivity(item) : d).toList(),
    );
  }

  Future<void> deleteActivity(String dayId, String activityId) async {
    await _commit(
      _days.map((d) => d.id == dayId ? d.removeActivity(activityId) : d).toList(),
    );
  }

  /// Reemplaza un día completo (usado al deshacer un borrado).
  Future<void> restoreDay(EventDay day) async {
    final index = _days.indexWhere((d) => d.id == day.id);
    final next = [..._days];
    if (index >= 0) {
      next[index] = day;
    } else {
      next.add(day);
    }
    await _commit(next);
  }

  /// Carga un conjunto de días de golpe, reemplazando lo que hubiera.
  ///
  /// Lo usa el botón «cargar itinerario de ejemplo» del estado vacío.
  Future<void> loadDays(List<EventDay> days) async {
    await _commit(days);
    ref.read(selectedDayProvider.notifier).select(
          days.isEmpty ? null : days.first.id,
        );
  }

  List<EventDay> get _days => state.value ?? const [];

  String? get selectedDayId => ref.read(selectedDayProvider);

  Future<void> _commit(List<EventDay> days) async {
    final sorted = [...days]..sort((a, b) => a.date.compareTo(b.date));
    state = AsyncData(sorted);
    await ref.read(repositoryProvider).replaceAllDays(sorted);
  }
}

final rundownProvider =
    AsyncNotifierProvider<RundownNotifier, List<EventDay>>(RundownNotifier.new);

/// Días ordenados por fecha, o lista vacía mientras carga.
final sortedDaysProvider = Provider<List<EventDay>>((ref) {
  return ref.watch(rundownProvider).value ?? const [];
});
