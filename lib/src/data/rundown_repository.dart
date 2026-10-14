import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../models/event_day.dart';
import '../models/rundown_template.dart';
import 'hive_boxes.dart';

/// Acceso a la persistencia. Los boxes ya están abiertos por [initHive], así
/// que todas las operaciones son síncronas salvo la escritura explícita.
class RundownRepository {
  const RundownRepository(this._days, this._templates, this._meta);

  final Box<Map> _days;
  final Box<Map> _templates;
  final Box<dynamic> _meta;

  List<EventDay> loadDays() {
    final days = _days.values
        .whereType<Map<dynamic, dynamic>>()
        .map(EventDay.fromJson)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return days;
  }

  EventDay? loadDay(String id) {
    final raw = _days.get(id);
    return raw == null ? null : EventDay.fromJson(raw);
  }

  /// Reemplaza el contenido completo del box de días.
  ///
  /// Borrar de más y reescribir todo evita tener que llevar un diff de ids
  /// eliminados en la capa de estado.
  Future<void> replaceAllDays(List<EventDay> days) async {
    final ids = days.map((d) => d.id).toSet();
    final stale = _days.keys.where((key) => !ids.contains(key)).toList();
    if (stale.isNotEmpty) await _days.deleteAll(stale);
    await _days.putAll({for (final day in days) day.id: day.toJson()});
  }

  Future<void> saveDay(EventDay day) => _days.put(day.id, day.toJson());

  Future<void> deleteDay(String id) => _days.delete(id);

  String? loadSelectedDayId() => _meta.get(selectedDayKey) as String?;

  Future<void> saveSelectedDayId(String? id) async {
    if (id == null) {
      await _meta.delete(selectedDayKey);
    } else {
      await _meta.put(selectedDayKey, id);
    }
  }

  String? loadSelectedDisplayId() => _meta.get(selectedDisplayKey) as String?;

  Future<void> saveSelectedDisplayId(String? id) async {
    if (id == null) {
      await _meta.delete(selectedDisplayKey);
    } else {
      await _meta.put(selectedDisplayKey, id);
    }
  }

  // --- Plantillas -----------------------------------------------------------

  List<RundownTemplate> loadTemplates() {
    return _templates.values
        .whereType<Map<dynamic, dynamic>>()
        .map(RundownTemplate.fromJson)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<void> saveTemplate(RundownTemplate template) =>
      _templates.put(template.id, template.toJson());

  Future<void> deleteTemplate(String id) => _templates.delete(id);
}

/// Las cajas se abren en `main()` antes de `runApp`, por lo que este provider
/// es seguro y sincrónico.
final repositoryProvider = Provider<RundownRepository>((ref) {
  return RundownRepository(
    Hive.box<Map>(daysBoxName),
    Hive.box<Map>(templatesBoxName),
    Hive.box<dynamic>(metaBoxName),
  );
});
