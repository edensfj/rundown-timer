import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rundown/src/core/app_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rundown/src/models/activity_item.dart';
import 'package:rundown/src/models/countdown_phase.dart';
import 'package:rundown/src/models/countdown_snapshot.dart';
import 'package:rundown/src/models/scheduled_activity.dart';
import 'package:rundown/src/state/countdown_provider.dart';
import 'package:rundown/src/ui/theme.dart';
import 'package:rundown/src/ui/widgets/stage_view.dart';

/// Escala de texto con la que se prueban los tamaños.
///
/// En Windows al 125 % —lo más común— todo el texto crece un 25 %, y es la
/// diferencia que hacía que el desbordamiento no apareciera en las pruebas y sí
/// en la app de verdad.
const double _textScale = 1.3;

/// Cuando un widget no cabe, Flutter dibuja una banda amarilla en el borde que
/// se desborda. Eso es exactamente lo que se veía en el escenario: una barra
/// amarilla a todo lo ancho (con 16 px de margen, como el `_DayProgressBar`) y
/// otra bajo el subtítulo.
///
/// En una prueba de widgets el desbordamiento no se ve: **falla**. Así que se
/// puede comprobar sin necesidad de un monitor de 1600x900 ni de Windows.
///
/// Se monta [StageView] a pelo, sustituyendo `countdownProvider` igual que hace
/// la ventana del escenario, para que la prueba cubra el mismo camino.

ActivityItem actividad({DateTime? endTime}) => ActivityItem(
  id: 'a1',
  title: 'Contador · 1 min',
  startTime: DateTime(2026, 10, 14, 16, 36),
  endTime: endTime,
);

/// El caso del pantallazo: contador rápido de 1 minuto, ya en la fase de aviso
/// (amarilla) y **sin actividad siguiente**, que es cuando el pie se queda
/// callado.
CountdownSnapshot contadorRapido({
  required Duration remaining,
  required CountdownPhase phase,
}) {
  final slot = ScheduledActivity(
    item: actividad(endTime: DateTime(2026, 10, 14, 16, 37)),
    startTime: DateTime(2026, 10, 14, 16, 36),
    endTime: DateTime(2026, 10, 14, 16, 37),
    isLast: true,
    hasExplicitEnd: true,
  );

  return CountdownSnapshot(
    current: slot,
    next: null,
    index: 0,
    total: 1,
    remaining: remaining,
    phase: phase,
    isQuickTimer: true,
    startTime: DateTime(2026, 10, 14, 16, 37),
  );
}

/// El caso del pantallazo: una sola actividad, todavía sin empezar, que es
/// cuando el pie dice «Última actividad del día».
CountdownSnapshot unicaActividadEnPrevio() => CountdownSnapshot(
  current: ScheduledActivity(
    item: ActivityItem(
      id: 'a1',
      title: 'ytrytry',
      startTime: DateTime(2026, 10, 14, 17, 0),
      endTime: DateTime(2026, 10, 14, 17, 30),
    ),
    startTime: DateTime(2026, 10, 14, 17, 0),
    endTime: DateTime(2026, 10, 14, 17, 30),
    isLast: true,
    hasExplicitEnd: true,
  ),
  next: null,
  index: 0,
  total: 1,
  remaining: const Duration(minutes: 5, seconds: 24),
  phase: CountdownPhase.preShow,
  startTime: DateTime(2026, 10, 14, 17, 0),
);

Future<void> montarEscenario(
  WidgetTester tester,
  CountdownSnapshot snapshot, {
  required Size windowSize,
}) async {
  tester.view.physicalSize = windowSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // La escala de texto del sistema: en Windows al 125 % —lo más común— todo el
  // texto crece un 25 %. Es la diferencia que hacía que el desbordamiento no
  // apareciera en las pruebas y sí en la app de verdad.
  tester.platformDispatcher.textScaleFactorTestValue = _textScale;
  addTearDown(tester.platformDispatcher.clearAllTestValues);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [countdownProvider.overrideWith((ref) => snapshot)],
      child: MaterialApp(
        // El tema de verdad, no el de por defecto: los tamaños de la cabecera
        // salen de `textTheme`, así que sin esto se mide un alto que no es el
        // que tiene la app y un desbordamiento real pasa desapercibido.
        theme: buildAppTheme(),
        home: const ColoredBox(color: Colors.black, child: StageView()),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  // Igual que hace `main`: sin esto, los formatos de hora revientan al
  // construir la cabecera y el test mediría otra cosa.
  //
  // Y se carga la fuente REAL del reloj. En una prueba de widgets las fuentes
  // propias no se cargan solas: se mide con una tipografía de reemplazo, cuyas
  // métricas no son las de Oswald. Si el desbordamiento depende de la altura
  // real de la línea, sin esto no se reproduce nunca.
  setUpAll(() async {
    await initializeDateFormatting('es', null);

    final oswald = FontLoader(AppConfig.countdownFontFamily)
      ..addFont(rootBundle.load('assets/fonts/Oswald-Variable.ttf'));
    await oswald.load();
  });

  final casos = <String, (Size, CountdownSnapshot)>{};
  // Los tamaños reales de portátiles y proyectores: el escenario tiene que
  // aguantar cualquiera de ellos, porque la ventana se ajusta a la pantalla.
  for (final size in const [
    Size(1920, 1080),
    Size(1600, 900),
    Size(1440, 900),
    Size(1440, 864),
    Size(1366, 768),
    Size(1280, 800),
    Size(1280, 720),
    Size(1024, 768),
  ]) {
    final etiqueta = '${size.width.toInt()}x${size.height.toInt()}';
    casos['contador rápido en aviso ($etiqueta)'] = (
      size,
      contadorRapido(
        remaining: const Duration(seconds: 22),
        phase: CountdownPhase.warning,
      ),
    );
    // Y el caso con cabecera completa y pie, que ocupa más alto: es el que
    // tiene menos sitio libre para el reloj.
    casos['una actividad, en previo ($etiqueta)'] = (
      size,
      unicaActividadEnPrevio(),
    );
    // Y el reloj de hora actual, que no lleva ni cabecera ni pie.
    casos['reloj de hora actual ($etiqueta)'] = (
      size,
      const CountdownSnapshot.empty(showClock: true),
    );
  }

  casos.addAll({
    'itinerario de UNA actividad, en previo (1600x900)': (
      const Size(1600, 900),
      CountdownSnapshot(
        current: ScheduledActivity(
          item: ActivityItem(
            id: 'a1',
            title: 'ytrytry',
            startTime: DateTime(2026, 10, 14, 17, 0),
            endTime: DateTime(2026, 10, 14, 17, 30),
          ),
          startTime: DateTime(2026, 10, 14, 17, 0),
          endTime: DateTime(2026, 10, 14, 17, 30),
          isLast: true,
          hasExplicitEnd: true,
        ),
        next: null,
        index: 0,
        total: 1,
        remaining: const Duration(minutes: 5, seconds: 24),
        phase: CountdownPhase.preShow,
        startTime: DateTime(2026, 10, 14, 17, 0),
      ),
    ),
    'contador rápido en tiempo excedido (1600x900)': (
      const Size(1600, 900),
      contadorRapido(
        remaining: const Duration(seconds: -22),
        phase: CountdownPhase.overtime,
      ),
    ),
    'contador rápido en la vista previa del panel': (
      const Size(420, 236),
      contadorRapido(
        remaining: const Duration(seconds: 22),
        phase: CountdownPhase.warning,
      ),
    ),
    'reloj 12 h, con el marcador más largo (1600x900)': (
      const Size(1600, 900),
      const CountdownSnapshot.empty(showClock: true, clockUse24Hour: false),
    ),
  });

  casos.forEach((nombre, caso) {
    testWidgets('no desborda: $nombre', (tester) async {
      await montarEscenario(tester, caso.$2, windowSize: caso.$1);

      // Si algún widget no cabe, Flutter lo reporta como excepción y la prueba
      // falla sola, con el widget culpable y los píxeles exactos en el informe.
    });
  });
}
