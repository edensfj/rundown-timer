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
const String marqueeSettingsKey = 'marqueeSettings';
const String marqueeMessagesKey = 'marqueeMessages';
const String flashSettingsKey = 'flashSettings';

/// Si el escenario proyecta la cuenta atrás **antes** de que empiece el evento.
///
/// Apagado por defecto: mientras no haya nada en marcha la pantalla se queda en
/// negro, que es lo que se quiere en una sala esperando. Encendido, es lo de
/// siempre: la cuenta regresiva al primer bloque del guion.
const String showPreShowCountdownKey = 'showPreShowCountdown';

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
