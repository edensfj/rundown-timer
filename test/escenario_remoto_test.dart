import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rundown/src/models/activity_item.dart';
import 'package:rundown/src/models/countdown_phase.dart';
import 'package:rundown/src/models/countdown_snapshot.dart';
import 'package:rundown/src/models/scheduled_activity.dart';

/// La instantánea del escenario tiene que viajar entera entre las dos ventanas:
/// se serializa a JSON y se reconstruye al otro lado. Si algo se pierde por el
/// camino, el reloj proyectado miente sin que nadie se entere, así que esto se
/// prueba con la ida y vuelta de verdad (jsonEncode + jsonDecode), no con el
/// mismo mapa en memoria.

ActivityItem actividad({
  String id = 'a1',
  String title = 'Prédica',
  DateTime? endTime,
  String? responsible,
  String? location,
}) =>
    ActivityItem(
      id: id,
      title: title,
      startTime: DateTime(2026, 10, 18, 10, 0),
      endTime: endTime,
      description: 'Con micrófono de solapa',
      responsible: responsible,
      location: location,
    );

void main() {
  group('ScheduledActivity: ida y vuelta', () {
    test('conserva horas, item y banderas', () {
      final original = ScheduledActivity(
        item: actividad(
          endTime: DateTime(2026, 10, 18, 10, 45),
          responsible: 'Pastor',
          location: 'Auditorio',
        ),
        startTime: DateTime(2026, 10, 18, 10, 0),
        endTime: DateTime(2026, 10, 18, 10, 45),
        isLast: false,
        hasExplicitEnd: true,
      );

      final copia = ScheduledActivity.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<dynamic, dynamic>,
      );

      expect(copia.item.id, original.item.id);
      expect(copia.item.title, 'Prédica');
      expect(copia.item.description, 'Con micrófono de solapa');
      expect(copia.item.responsible, 'Pastor');
      expect(copia.item.location, 'Auditorio');
      expect(copia.item.endTime, DateTime(2026, 10, 18, 10, 45));
      expect(copia.startTime, DateTime(2026, 10, 18, 10, 0));
      expect(copia.endTime, DateTime(2026, 10, 18, 10, 45));
      expect(copia.isLast, isFalse);
      expect(copia.hasExplicitEnd, isTrue);
      expect(copia.plannedDuration, const Duration(minutes: 45));
    });

    test('los campos opcionales vacíos siguen vacíos', () {
      final original = ScheduledActivity(
        item: actividad(),
        startTime: DateTime(2026, 10, 18, 10, 0),
        endTime: DateTime(2026, 10, 18, 10, 30),
        isLast: true,
      );

      final copia = ScheduledActivity.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<dynamic, dynamic>,
      );

      expect(copia.item.endTime, isNull);
      expect(copia.item.responsible, isNull);
      expect(copia.item.location, isNull);
      expect(copia.isLast, isTrue);
      expect(copia.hasExplicitEnd, isFalse);
    });
  });

  group('CountdownSnapshot: ida y vuelta', () {
    final actual = ScheduledActivity(
      item: actividad(title: 'Prédica'),
      startTime: DateTime(2026, 10, 18, 10, 0),
      endTime: DateTime(2026, 10, 18, 10, 45),
      isLast: false,
    );
    final siguiente = ScheduledActivity(
      item: actividad(id: 'a2', title: 'Oración'),
      startTime: DateTime(2026, 10, 18, 10, 45),
      endTime: DateTime(2026, 10, 18, 11, 0),
      isLast: true,
      hasExplicitEnd: true,
    );

    test('conserva todo lo que el reloj necesita para pintarse', () {
      final original = CountdownSnapshot(
        current: actual,
        next: siguiente,
        index: 1,
        total: 3,
        remaining: const Duration(minutes: 12, seconds: 34),
        phase: CountdownPhase.warning,
        isPaused: true,
        isAutomatic: false,
        isFinished: false,
        isQuickTimer: true,
        startTime: DateTime(2026, 10, 18, 10, 45),
      );

      final copia = CountdownSnapshot.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<dynamic, dynamic>,
      );

      expect(copia.index, 1);
      expect(copia.total, 3);
      expect(copia.remaining, const Duration(minutes: 12, seconds: 34));
      expect(copia.phase, CountdownPhase.warning);
      expect(copia.isPaused, isTrue);
      expect(copia.isAutomatic, isFalse);
      expect(copia.isFinished, isFalse);
      expect(copia.isQuickTimer, isTrue);
      expect(copia.startTime, DateTime(2026, 10, 18, 10, 45));

      expect(copia.current!.item.title, 'Prédica');
      expect(copia.next!.item.title, 'Oración');
      expect(copia.next!.hasExplicitEnd, isTrue);
      expect(copia.hasActivities, isTrue);
      expect(copia.isLast, isFalse);
    });

    test('el tiempo excedido viaja en negativo, no se recorta a cero', () {
      final original = CountdownSnapshot(
        current: actual,
        index: 0,
        total: 1,
        remaining: const Duration(minutes: -3, seconds: -20),
        phase: CountdownPhase.overtime,
      );

      final copia = CountdownSnapshot.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<dynamic, dynamic>,
      );

      expect(copia.remaining, const Duration(minutes: -3, seconds: -20));
      expect(copia.remaining.isNegative, isTrue);
      expect(copia.phase, CountdownPhase.overtime);
      expect(copia.phase.isAlert, isTrue,
          reason: 'el escenario debe seguir parpadeando en rojo');
    });

    test('una instantánea vacía se reconstruye vacía', () {
      const original = CountdownSnapshot.empty();

      final copia = CountdownSnapshot.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<dynamic, dynamic>,
      );

      expect(copia.current, isNull);
      expect(copia.next, isNull);
      expect(copia.hasActivities, isFalse);
      expect(copia.remaining, Duration.zero);
      expect(copia.startTime, isNull);
    });

    test('una fase desconocida no tumba el reloj', () {
      // Una app antigua o más nueva puede mandar una fase que aquí no existe;
      // es preferible caer al pre-show que quedarse congelado.
      final copia = CountdownSnapshot.fromJson({
        'phase': 'faseDelFuturo',
        'index': 0,
        'total': 0,
      });

      expect(copia.phase, CountdownPhase.preShow);
    });
  });
}
