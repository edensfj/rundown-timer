import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rundown/src/core/app_config.dart';
import 'package:rundown/src/models/activity_item.dart';
import 'package:rundown/src/models/countdown_phase.dart';
import 'package:rundown/src/models/countdown_snapshot.dart';
import 'package:rundown/src/models/scheduled_activity.dart';
import 'package:rundown/src/state/countdown_provider.dart';
import 'package:rundown/src/window/stage_window.dart';

/// El texto del escenario tiene que salir con **su** estilo.
///
/// `MaterialApp` deja puesto un estilo de error para el texto que no está bajo
/// un `Material`: monoespaciado, rojo y con subrayado amarillo doble. Nuestro
/// escenario colgaba de un `ColoredBox`, así que los dígitos —gigantes—
/// convertían aquel subrayado en una barra amarilla cruzando la pantalla, y el
/// subtítulo lo enseñaba como una raya bajo las letras. Estas pruebas vigilan
/// que nadie vuelva a quitar el `Material`.
void main() {
  setUpAll(() async => initializeDateFormatting('es', null));

  final snapshot = CountdownSnapshot(
    current: ScheduledActivity(
      item: ActivityItem(
        id: 'a1',
        title: 'Oración',
        startTime: DateTime(2026, 10, 14, 16, 15),
      ),
      startTime: DateTime(2026, 10, 14, 16, 15),
      endTime: DateTime(2026, 10, 14, 16, 30),
      isLast: true,
      hasExplicitEnd: true,
    ),
    next: null,
    index: 0,
    total: 1,
    remaining: const Duration(minutes: 12, seconds: 30),
    phase: CountdownPhase.normal,
    startTime: DateTime(2026, 10, 14, 16, 15),
  );

  Future<void> montar(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [countdownProvider.overrideWith((ref) => snapshot)],
        child: const StageWindowApp(),
      ),
    );
    await tester.pump();
  }

  testWidgets('ningún texto hereda el estilo de error de Material',
      (tester) async {
    await montar(tester);

    final textos = tester.widgetList<RichText>(find.byType(RichText)).toList();
    expect(textos, isNotEmpty, reason: 'el escenario tiene que escribir algo');

    for (final texto in textos) {
      final estilo = texto.text.style;
      final contenido = texto.text.toPlainText();

      expect(
        estilo?.decoration,
        anyOf(isNull, TextDecoration.none),
        reason: '«$contenido» sale subrayado: es el estilo de error de '
            'Material, no el nuestro',
      );
      expect(
        estilo?.fontFamily,
        isNot('monospace'),
        reason: '«$contenido» sale en monoespaciada: es el estilo de error de '
            'Material, no el nuestro',
      );
      expect(
        estilo?.decorationColor,
        isNot(const Color(0xFFFFFF00)),
        reason: '«$contenido» sale con el amarillo del estilo de error',
      );
    }
  });

  testWidgets('el reloj sale en blanco y con la tipografía del reloj',
      (tester) async {
    await montar(tester);

    final reloj = tester.widget<RichText>(
      find.descendant(of: find.text('12:30'), matching: find.byType(RichText)),
    );

    expect(reloj.text.style?.fontFamily, AppConfig.countdownFontFamily,
        reason: 'la fuente condensada es lo que hace grande al reloj');
    expect(reloj.text.style?.color, StageColors.white);
  });
}
