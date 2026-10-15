import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rundown/src/models/activity_item.dart';
import 'package:rundown/src/models/countdown_phase.dart';
import 'package:rundown/src/models/countdown_snapshot.dart';
import 'package:rundown/src/models/scheduled_activity.dart';
import 'package:rundown/src/state/schedule_provider.dart';
import 'package:rundown/src/ui/widgets/activity_card.dart';
import 'package:rundown/src/ui/widgets/activity_preview_dialog.dart';

/// Vista previa por actividad: el ojo de la tarjeta enseña cómo se vería esa
/// actividad en el escenario, sin tocar lo que está al aire.

ScheduledActivity turno({
  required String id,
  required String title,
  required int startMinutes,
  required int endMinutes,
  bool isLast = false,
}) {
  DateTime at(int minutes) =>
      DateTime(2026, 10, 18, 19, 0).add(Duration(minutes: minutes));
  return ScheduledActivity(
    item: ActivityItem(id: id, title: title, startTime: at(startMinutes)),
    startTime: at(startMinutes),
    endTime: at(endMinutes),
    isLast: isLast,
    hasExplicitEnd: isLast,
  );
}

List<ScheduledActivity> turnos() => [
  turno(id: 'a1', title: 'Llegada', startMinutes: 30, endMinutes: 50),
  turno(id: 'a2', title: 'Acomodación', startMinutes: 50, endMinutes: 60),
  turno(
    id: 'a3',
    title: 'Bienvenida',
    startMinutes: 60,
    endMinutes: 80,
    isLast: true,
  ),
];

void main() {
  // La cabecera y el pie del escenario formatean horas en español.
  setUpAll(() async => initializeDateFormatting('es', null));

  group('CountdownSnapshot.preview', () {
    test('muestra la actividad con su duración completa por delante', () {
      final snapshot = CountdownSnapshot.preview(slots: turnos(), index: 1);

      expect(snapshot.current?.item.id, 'a2');
      expect(snapshot.next?.item.id, 'a3');
      expect(snapshot.index, 1);
      expect(snapshot.total, 3);
      expect(snapshot.remaining, const Duration(minutes: 10));
      expect(snapshot.phase, CountdownPhase.normal);
      expect(snapshot.startTime, DateTime(2026, 10, 18, 19, 50));
      expect(snapshot.hasActivities, isTrue);
    });

    test('la última no tiene siguiente', () {
      final snapshot = CountdownSnapshot.preview(slots: turnos(), index: 2);

      expect(snapshot.current?.item.id, 'a3');
      expect(snapshot.next, isNull);
      expect(snapshot.isLast, isTrue);
      expect(snapshot.remaining, const Duration(minutes: 20));
    });

    test('el índice fuera de rango se recorta', () {
      expect(
        CountdownSnapshot.preview(slots: turnos(), index: 99).current?.item.id,
        'a3',
      );
      expect(
        CountdownSnapshot.preview(slots: turnos(), index: -1).current?.item.id,
        'a1',
      );
    });

    test('sin actividades no hay nada que previsualizar', () {
      expect(
        () => CountdownSnapshot.preview(slots: const [], index: 0),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('showActivityPreview', () {
    Future<void> montar(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showActivityPreview(
                  context,
                  CountdownSnapshot.preview(slots: turnos(), index: 0),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    testWidgets('pinta el escenario de esa actividad', (tester) async {
      await montar(tester);

      // La cuenta atrás enseña la duración completa: 20 minutos.
      expect(find.text('20:00'), findsOneWidget);
      expect(find.text('Llegada'), findsOneWidget);
      expect(find.textContaining('ACTIVIDAD 1 DE 3'), findsOneWidget);
    });

    testWidgets('se cierra con su aspa', (tester) async {
      await montar(tester);
      expect(find.text('20:00'), findsOneWidget);

      await tester.tap(find.byTooltip('Cerrar vista previa'));
      await tester.pumpAndSettle();

      expect(find.text('20:00'), findsNothing);
    });
  });

  group('ActivityCard', () {
    Future<void> montar(
      WidgetTester tester, {
      required VoidCallback onPreview,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activityStatusProvider.overrideWith(
              (ref) => const {'a1': ActivityStatus.upcoming},
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ActivityCard(
                slot: turnos()[0],
                onTap: () {},
                onDelete: () {},
                onPreview: onPreview,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('el play avisa sin borrar ni editar', (tester) async {
      var avisos = 0;
      await montar(tester, onPreview: () => avisos++);

      // Las acciones se revelan al pasar el ratón sobre la tarjeta.
      final raton = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await raton.addPointer(location: tester.getCenter(find.text('Llegada')));
      await tester.pump();
      addTearDown(raton.removePointer);

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(
        find.byIcon(Icons.delete_outline_rounded),
        findsOneWidget,
        reason: 'eliminar sigue junto al play',
      );

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));

      expect(avisos, 1);
    });
    testWidgets('ocultas no interceptan: sin hover el play no avisa', (
      tester,
    ) async {
      var avisos = 0;
      await montar(tester, onPreview: () => avisos++);

      // Sin pasar el ratón las acciones están ocultas e ignoran el toque:
      // pulsar ahí no dispara la vista previa por accidente.
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));

      expect(avisos, 0);
    });
  });
}
