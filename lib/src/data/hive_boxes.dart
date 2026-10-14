import 'package:hive_ce_flutter/hive_flutter.dart';

import 'sample_rundown.dart';

/// Box con un registro por día del evento, indexado por su id.
const String daysBoxName = 'rundown_days';

/// Box con preferencias simples (por ahora, el día seleccionado).
const String metaBoxName = 'rundown_meta';

/// Claves dentro de [metaBoxName].
const String selectedDayKey = 'selectedDayId';
const String selectedDisplayKey = 'selectedDisplayId';

/// Marca de que el itinerario de ejemplo ya se cargó una vez. Evita que vuelva
/// a aparecer si el usuario borra todos los días.
const String seededKey = 'sampleRundownSeeded';

/// Prepara Hive antes de correr la app.
///
/// Se usan boxes de tipo `Map` con serialización manual a JSON para evitar
/// `TypeAdapter`s generados y `build_runner`. En escritorio Hive escribe
/// archivos; el modelo sigue siendo portable a web sin cambios.
Future<void> initHive() async {
  await Hive.initFlutter('rundown');
  await Future.wait([
    Hive.openBox<Map>(daysBoxName),
    Hive.openBox<dynamic>(metaBoxName),
  ]);
}

/// Carga el itinerario de ejemplo la primera vez que se abre la app.
///
/// Solo actúa una vez: deja marca en [seededKey] para que, si el usuario borra
/// los días de ejemplo, no reaparezcan.
Future<void> seedSampleRundownIfNeeded() async {
  final meta = Hive.box<dynamic>(metaBoxName);
  if (meta.get(seededKey) == true) return;

  final days = Hive.box<Map>(daysBoxName);
  if (days.isEmpty) {
    final sample = buildSampleRundown();
    await days.putAll({for (final day in sample) day.id: day.toJson()});
    await meta.put(selectedDayKey, sample.first.id);
  }

  await meta.put(seededKey, true);
}
