import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/rundown_repository.dart';
import '../models/event_day.dart';
import '../models/rundown_template.dart';

/// Plantillas reutilizables guardadas por el usuario.
class TemplatesNotifier extends AsyncNotifier<List<RundownTemplate>> {
  @override
  Future<List<RundownTemplate>> build() async {
    return ref.read(repositoryProvider).loadTemplates();
  }

  Future<void> save(RundownTemplate template) async {
    if (template.name.trim().isEmpty) return;
    await ref.read(repositoryProvider).saveTemplate(template);
    await _reload();
  }

  Future<void> delete(String templateId) async {
    await ref.read(repositoryProvider).deleteTemplate(templateId);
    await _reload();
  }

  /// Guarda un día ya armado como plantilla, conservando sus duraciones.
  Future<RundownTemplate> saveFromDay(
    EventDay day, {
    required String id,
    required String name,
  }) async {
    final template = RundownTemplate.fromDay(day, id: id, name: name);
    await save(template);
    return template;
  }

  Future<void> _reload() async {
    state = AsyncData(ref.read(repositoryProvider).loadTemplates());
  }
}

final templatesProvider =
    AsyncNotifierProvider<TemplatesNotifier, List<RundownTemplate>>(
      TemplatesNotifier.new,
    );

/// Plantillas ordenadas por nombre, o lista vacía mientras carga.
final sortedTemplatesProvider = Provider<List<RundownTemplate>>((ref) {
  return ref.watch(templatesProvider).value ?? const [];
});
