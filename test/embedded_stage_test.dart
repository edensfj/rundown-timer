import 'package:flutter/gestures.dart';
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
import 'package:rundown/src/ui/screens/embedded_stage_screen.dart';

/// El escenario del modo de una sola ventana (Linux): lo que se proyecta y
/// cuándo aparecen los controles.
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
        child: const MaterialApp(home: EmbeddedStageScreen()),
      ),
    );
    await tester.pump();
  }

  /// Los controles no se quitan del árbol: se desvanecen y dejan de responder.
  bool visibles(WidgetTester tester) {
    final opacidad = tester.widgetList<AnimatedOpacity>(
      find.byType(AnimatedOpacity),
    );
    return opacidad.any((widget) => widget.opacity > 0);
  }

  testWidgets('se ve el reloj y los controles se esconden solos',
      (tester) async {
    await montar(tester);

    expect(find.text('Oración'), findsOneWidget);
    expect(find.text('12:30'), findsOneWidget);
    expect(visibles(tester), isTrue,
        reason: 'al entrar se ofrecen los controles');

    // Pasa el tiempo de inactividad: el ratón no se ha movido.
    await tester.pump(AppConfig.controlsIdleTimeout);
    await tester.pump(const Duration(milliseconds: 400));

    expect(visibles(tester), isFalse,
        reason: 'sin ratón, la proyección se queda limpia');
  });

  testWidgets('mover el ratón los devuelve', (tester) async {
    await montar(tester);

    await tester.pump(AppConfig.controlsIdleTimeout);
    await tester.pump(const Duration(milliseconds: 400));
    expect(visibles(tester), isFalse);

    final raton = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await raton.addPointer(location: Offset.zero);
    addTearDown(raton.removePointer);
    await raton.moveTo(const Offset(200, 200));
    await tester.pump();

    expect(visibles(tester), isTrue,
        reason: 'el operador tiene que poder recuperar los controles');
  });
}
