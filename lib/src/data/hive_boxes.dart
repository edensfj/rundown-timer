import 'package:hive_ce_flutter/hive_flutter.dart';

/// Box con un registro por día del evento, indexado por su id.
const String daysBoxName = 'rundown_days';

/// Box con un registro por plantilla reutilizable, indexado por su id.
const String templatesBoxName = 'rundown_templates';

/// Box con preferencias simples (por ahora, el día seleccionado).
const String metaBoxName = 'rundown_meta';

/// Claves dentro de [metaBoxName].
const String selectedDayKey = 'selectedDayId';
const String selectedDisplayKey = 'selectedDisplayKey';

/// Prepara Hive antes de correr la app.
///
/// Se usan boxes de tipo `Map` con serialización manual a JSON para evitar
/// `TypeAdapter`s generados y `build_runner`. En escritorio Hive escribe
/// archivos; el modelo sigue siendo portable a web sin cambios.
Future<void> initHive() async {
  await Hive.initFlutter('rundown');
  await Future.wait([
    Hive.openBox<Map>(daysBoxName),
    Hive.openBox<Map>(templatesBoxName),
    Hive.openBox<dynamic>(metaBoxName),
  ]);
}
