import 'dart:ui' show Size;

/// Valores por defecto del cronograma y del modo escenario.
///
/// Se centralizan aquí para que cambiar el comportamiento del timer sea
/// una edición de un solo lugar.
class AppConfig {
  const AppConfig._();

  /// Duración asignada a la última actividad cuando no existe una siguiente
  /// que le defina la hora de fin.
  static const Duration defaultLastActivityDuration = Duration(minutes: 30);

  /// A partir de este tiempo restante el countdown entra en estado de advertencia.
  static const Duration warningThreshold = Duration(minutes: 5);

  /// Bloque usado para redondear hacia arriba la hora de inicio sugerida.
  static const Duration startTimeRounding = Duration(minutes: 5);

  /// Periodo de un ciclo del parpadeo rojo de pantalla completa.
  static const Duration blinkPeriod = Duration(milliseconds: 700);

  /// Tiempo de inactividad antes de ocultar los controles del modo escenario.
  static const Duration controlsIdleTimeout = Duration(seconds: 4);

  /// Tipografía condensada del countdown. Al ser estrecha, los mismos dígitos
  /// caben más altos en pantalla: es lo que hace que el reloj domine la vista.
  static const String countdownFontFamily = 'Oswald';

  /// Tamaño de la ventana que simula el escenario cuando **no** hay una pantalla
  /// externa elegida. Proporción 16:9, igual que un proyector.
  static const Size stageWindowSize = Size(1600, 900);

  static const String appTitle = 'Rundown · Timer';
}
