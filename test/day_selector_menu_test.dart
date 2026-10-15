import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rundown/src/models/activity_item.dart';
import 'package:rundown/src/models/event_day.dart';
import 'package:rundown/src/state/rundown_provider.dart';
import 'package:rundown/src/state/selected_day_provider.dart';
import 'package:rundown/src/ui/widgets/day_selector.dart';

/// El menú de un día (renombrar / eliminar) tiene que salir con **clic
/// derecho**, que es lo natural con un ratón, y seguir saliendo con pulsación
/// larga para cuando se usa el dedo.
void main() {
  setUpAll(() async => initializeDateFormatting('es', null));

  final dia = EventDay(
    id: 'd1',
    name: 'Sábado 14',
    date: DateTime(2026, 10, 14),
    activities: [
      ActivityItem(
        id: 'a1',
        title: 'Alabanza',
        startTime: DateTime(2026, 10, 14, 18, 10),
      ),
    ],
  );

  Future<void> montar(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rundownProvider.overrideWith(() => _FakeRundown([dia])),
          // El día activo se persiste en Hive, y aquí no hay base de datos: se
          // sustituye para poder montar el selector en una prueba de widgets.
          selectedDayProvider.overrideWith(_FakeSelectedDay.new),
        ],
        child: MaterialApp(
          home: Scaffold(body: DaySelector(onAddDay: () {})),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> clicDerecho(WidgetTester tester) async {
    final raton = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await raton.down(tester.getCenter(find.text('Sábado 14')));
    addTearDown(raton.removePointer);
    await tester.pumpAndSettle();
  }

  testWidgets('el clic derecho abre el menú de ese día', (tester) async {
    await montar(tester);

    expect(find.text('Sábado 14'), findsOneWidget);
    expect(find.text('Renombrar'), findsNothing,
        reason: 'el menú no puede estar abierto sin pedirlo');

    await clicDerecho(tester);

    expect(find.text('Renombrar'), findsOneWidget);
    expect(find.text('Eliminar el día'), findsOneWidget);
  });

  testWidgets('elegir «Renombrar» lleva al diálogo con el nombre actual',
      (tester) async {
    await montar(tester);
    await clicDerecho(tester);

    await tester.tap(find.text('Renombrar'));
    await tester.pumpAndSettle();

    expect(find.text('Renombrar día'), findsOneWidget);
    expect(find.text('Sábado 14'), findsWidgets,
        reason: 'el nombre actual viene de serie, para no reescribirlo');
  });

  testWidgets('la pulsación larga abre lo mismo', (tester) async {
    await montar(tester);

    await tester.longPress(find.text('Sábado 14'));
    await tester.pumpAndSettle();

    expect(find.text('Renombrar'), findsOneWidget);
    expect(find.text('Eliminar el día'), findsOneWidget);
  });
}

/// Itinerario de mentira: a este test solo le importa que haya un día que
/// pulsar, no qué sabe hacer la app con él.
class _FakeRundown extends RundownNotifier {
  _FakeRundown(this._days);

  final List<EventDay> _days;

  @override
  Future<List<EventDay>> build() async => _days;
}

/// El primer día activo, sin tocar Hive.
class _FakeSelectedDay extends SelectedDayNotifier {
  @override
  String? build() => 'd1';
}