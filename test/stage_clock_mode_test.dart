import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rundown/src/core/app_config.dart';
import 'package:rundown/src/core/time_formatters.dart';
import 'package:rundown/src/models/activity_item.dart';
import 'package:rundown/src/models/countdown_phase.dart';
import 'package:rundown/src/models/countdown_snapshot.dart';
import 'package:rundown/src/models/run_show_state.dart';
import 'package:rundown/src/models/scheduled_activity.dart';
import 'package:rundown/src/state/clock_provider.dart';
import 'package:rundown/src/state/countdown_provider.dart';
import 'package:rundown/src/state/run_show_provider.dart';
import 'package:rundown/src/state/schedule_provider.dart';
import 'package:rundown/src/state/stage_mode_provider.dart';
import 'package:rundown/src/window/stage_window.dart';

/// Modo reloj del escenario: en vez de la cuenta atrás, la hora actual.
///
/// El modo viaja **dentro de la instantánea** (`showClock`), por el canal de
/// siempre: así llega igual a la segunda ventana de Windows y al proceso
/// aparte de Linux. Los segundos los pone el propio escenario con su reloj
/// local, sin tráfico extra.

ScheduledActivity tramo() => ScheduledActivity(
  item: ActivityItem(
    id: 'a1',
    title: 'Oración',
    startTime: DateTime(2026, 10, 15, 10, 0),
    endTime: DateTime(2026, 10, 15, 10, 30),
  ),
  startTime: DateTime(2026, 10, 15, 10, 0),
  endTime: DateTime(2026, 10, 15, 10, 30),
  isLast: true,
  hasExplicitEnd: true,
);

/// Ejecución quieta: sin pausas ni saltos, para que la prueba solo mida el
/// efecto del modo.
class _RunQuieto extends RunShowNotifier {
  @override
  RunShowState build() => const RunShowState();
}

/// Reloj parado en una hora fija, para que las pruebas no dependan de cuándo
/// se ejecuten.
class _HoraFija extends ClockNotifier {
  _HoraFija(this.hora);

  final DateTime hora;

  @override
  DateTime build() => hora;
}

ProviderContainer contenedor() => ProviderContainer(
  overrides: [
    activeScheduleProvider.overrideWith((ref) => [tramo()]),
    clockProvider.overrideWith(() => _HoraFija(DateTime(2026, 10, 15, 10, 15))),
    runShowProvider.overrideWith(_RunQuieto.new),
  ],
);

void main() {
  // El formato 12 h sale de `intl` con locale español: sin esto revienta.
  setUpAll(() async => initializeDateFormatting('es', null));

  group('TimeFormatters.stageClock', () {
    test('forma 24 h con dos dígitos', () {
      expect(
        TimeFormatters.stageClock(DateTime(2026, 10, 15, 9, 5, 7)),
        '09:05:07',
      );
    });

    test('medianoche es 00:00:00', () {
      expect(
        TimeFormatters.stageClock(DateTime(2026, 10, 15, 0, 0, 0)),
        '00:00:00',
      );
    });

    test('la tarde no vuelve a empezar', () {
      expect(
        TimeFormatters.stageClock(DateTime(2026, 10, 15, 23, 59, 58)),
        '23:59:58',
      );
    });
  });

  group('TimeFormatters.stageClock12', () {
    test('la tarde lleva p.\u202fm.', () {
      expect(
        TimeFormatters.stageClock12(DateTime(2026, 10, 15, 14, 5, 7)),
        '2:05:07 p. m.',
      );
    });

    test('la medianoche es 12 a.\u202fm.', () {
      expect(
        TimeFormatters.stageClock12(DateTime(2026, 10, 15, 0, 0, 0)),
        '12:00:00 a.\u202fm.',
      );
    });
  });

  group('CountdownSnapshot.showClock', () {
    test('sobrevive a la ida y vuelta entre ventanas', () {
      final original = CountdownSnapshot(
        current: tramo(),
        next: null,
        index: 0,
        total: 1,
        remaining: const Duration(minutes: 15),
        phase: CountdownPhase.normal,
        startTime: DateTime(2026, 10, 15, 10, 0),
        showClock: true,
      );

      final copia = CountdownSnapshot.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<dynamic, dynamic>,
      );

      expect(copia.showClock, isTrue);
    });

    test('si falta la clave se cuenta atrás (panel viejo, reloj nuevo)', () {
      final mapa = CountdownSnapshot.empty().toJson()..remove('showClock');

      expect(CountdownSnapshot.fromJson(mapa).showClock, isFalse);
    });

    test('el formato elegido sobrevive a la ida y vuelta', () {
      final original = CountdownSnapshot(
        current: tramo(),
        next: null,
        index: 0,
        total: 1,
        remaining: const Duration(minutes: 15),
        phase: CountdownPhase.normal,
        startTime: DateTime(2026, 10, 15, 10, 0),
        showClock: true,
        clockUse24Hour: false,
      );

      final copia = CountdownSnapshot.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<dynamic, dynamic>,
      );

      expect(copia.showClock, isTrue);
      expect(copia.clockUse24Hour, isFalse);
    });

    test('sin la clave de formato se asume 24 h', () {
      final mapa = CountdownSnapshot.empty().toJson()..remove('clockUse24Hour');

      expect(CountdownSnapshot.fromJson(mapa).clockUse24Hour, isTrue);
    });
  });

  group('countdownProvider', () {
    test('por defecto manda contar atrás', () {
      final container = contenedor();
      addTearDown(container.dispose);

      expect(container.read(stageModeProvider), StageMode.countdown);
      expect(container.read(countdownProvider).showClock, isFalse);
    });

    test('al elegir hora actual la instantánea lo marca', () {
      final container = contenedor();
      addTearDown(container.dispose);

      container.read(stageModeProvider.notifier).setMode(StageMode.clock);

      expect(container.read(countdownProvider).showClock, isTrue);
    });

    test('por defecto el reloj va en 24 h', () {
      final container = contenedor();
      addTearDown(container.dispose);

      expect(container.read(stageClockFormatProvider), StageClockFormat.h24);
      expect(container.read(countdownProvider).clockUse24Hour, isTrue);
    });

    test('al elegir 12 h la instantánea lo marca', () {
      final container = contenedor();
      addTearDown(container.dispose);

      container
          .read(stageClockFormatProvider.notifier)
          .setFormat(StageClockFormat.h12);

      expect(container.read(countdownProvider).clockUse24Hour, isFalse);
    });

    test('el reloj no necesita actividades', () {
      final container = ProviderContainer(
        overrides: [
          activeScheduleProvider.overrideWith((ref) => const []),
          clockProvider.overrideWith(
            () => _HoraFija(DateTime(2026, 10, 15, 10, 15)),
          ),
          runShowProvider.overrideWith(_RunQuieto.new),
          stageModeProvider.overrideWith(_RelojFijo.new),
        ],
      );
      addTearDown(container.dispose);

      final snapshot = container.read(countdownProvider);

      expect(snapshot.hasActivities, isFalse);
      expect(snapshot.showClock, isTrue);
    });
  });

  group('StageView en modo reloj', () {
    Future<void> montar(
      WidgetTester tester, {
      CountdownSnapshot snapshot = const CountdownSnapshot.empty(
        showClock: true,
      ),
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [countdownProvider.overrideWith((ref) => snapshot)],
          child: const StageWindowApp(),
        ),
      );
      await tester.pump();
    }

    Finder horaEnPantalla() => find.byWidgetPredicate(
      (widget) =>
          widget is RichText &&
          RegExp(r'^\d{2}:\d{2}:\d{2}$').hasMatch(widget.text.toPlainText()),
    );

    testWidgets('enseña la hora con dígitos gigantes', (tester) async {
      await montar(tester);

      final reloj = tester.widget<RichText>(horaEnPantalla()).text;

      expect(reloj.style?.fontFamily, AppConfig.countdownFontFamily);
      expect(reloj.style?.color, StageColors.white);
    });

    testWidgets('no enseña la cuenta atrás', (tester) async {
      await montar(tester);

      expect(horaEnPantalla(), findsOneWidget);
      expect(find.textContaining('ACTIVIDAD'), findsNothing);
      expect(find.textContaining('PRÓXIMA'), findsNothing);
      expect(find.textContaining('CONTADOR'), findsNothing);
    });

    testWidgets('en 12 h enseña el marcador con a.\u202fm. o p.\u202fm.', (tester) async {
      await montar(
        tester,
        snapshot: const CountdownSnapshot.empty(
          showClock: true,
          clockUse24Hour: false,
        ),
      );

      expect(find.textContaining('m.', findRichText: true), findsOneWidget);
      expect(horaEnPantalla(), findsNothing);
    });
  });
}

/// Modo fijado en reloj, para el caso sin actividades.
class _RelojFijo extends StageModeNotifier {
  @override
  StageMode build() => StageMode.clock;
}
