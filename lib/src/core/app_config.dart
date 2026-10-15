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
  ///
  /// La marquesina usa la misma: así la banda y el reloj parecen del mismo
  /// cartel.
  static const String countdownFontFamily = 'Oswald';

  /// Alto de la banda de la marquesina cuando el texto va **debajo del reloj**,
  /// como una franja fina, sin quitarle sitio.
  static const double marqueeBandFraction = 0.16;

  /// Alto de la banda cuando el texto es el **protagonista**: se lleva la mayor
  /// parte de la pantalla y el reloj se encoge arriba a un contador pequeño.
  static const double marqueeProminentBandFraction = 0.62;

  /// Tamaño de la ventana que simula el escenario cuando **no** hay una pantalla
  /// externa elegida. Proporción 16:9, igual que un proyector.
  static const Size stageWindowSize = Size(1600, 900);

  /// Título de la ventana del escenario, para distinguirla en la barra de
  /// tareas de la del panel.
  static const String stageWindowTitle = 'Rundown · Escenario';

  /// Variable de entorno con la que el panel lanza el escenario **en su propio
  /// proceso**, con la geometría codificada dentro.
  ///
  /// Se usa donde no se puede abrir una segunda ventana en el mismo proceso
  /// (Linux: ver `stageSecondWindowProvider`) pero sí una segunda instancia de
  /// la app. El que la encuentre definida arranca como escenario y no como panel.
  static const String stageEnvKey = 'RUNDOWN_STAGE';

  static const String appTitle = 'Rundown · Timer';
}
