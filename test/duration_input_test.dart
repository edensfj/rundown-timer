import 'package:flutter_test/flutter_test.dart';
import 'package:rundown/src/core/duration_input.dart';
import 'package:rundown/src/models/activity_item.dart';
import 'package:rundown/src/models/event_day.dart';
import 'package:rundown/src/models/rundown_template.dart';
import 'package:rundown/src/models/scheduled_activity.dart';

void main() {
  group('parseDuration: lo que la gente escribe', () {
    test('minutos solos o con sufijo', () {
      expect(parseDuration('45'), const Duration(minutes: 45));
      expect(parseDuration('45m'), const Duration(minutes: 45));
      expect(parseDuration('45 min'), const Duration(minutes: 45));
      expect(parseDuration('20minutos'), const Duration(minutes: 20));
      expect(parseDuration('90'), const Duration(minutes: 90));
    });

    test('horas y minutos separados por dos puntos', () {
      expect(parseDuration('1:30'), const Duration(minutes: 90));
      expect(parseDuration('2:05'), const Duration(hours: 2, minutes: 5));
      expect(parseDuration('0:45'), const Duration(minutes: 45));
    });

    test('horas con h, juntas o separadas', () {
      expect(parseDuration('2h'), const Duration(hours: 2));
      expect(parseDuration('2 h'), const Duration(hours: 2));
      expect(parseDuration('2h30'), const Duration(hours: 2, minutes: 30));
      expect(parseDuration('2h30m'), const Duration(hours: 2, minutes: 30));
      expect(parseDuration('2 horas'), const Duration(hours: 2));
      expect(parseDuration('2 horas 30 minutos'), const Duration(hours: 2, minutes: 30));
    });

    test('horas decimales, con punto o con coma', () {
      expect(parseDuration('1.5h'), const Duration(hours: 1, minutes: 30));
      expect(parseDuration('1,5h'), const Duration(hours: 1, minutes: 30));
      expect(parseDuration('0.25h'), const Duration(minutes: 15));
    });

    test('mayúsculas y espacios dan igual', () {
      expect(parseDuration('  2H30M  '), const Duration(hours: 2, minutes: 30));
    });

    test('rechaza lo que no se entiende o no es positivo', () {
      expect(parseDuration(''), isNull);
      expect(parseDuration('   '), isNull);
      expect(parseDuration('cero'), isNull);
      expect(parseDuration('0'), isNull, reason: 'una actividad de 0 min no tiene sentido');
      expect(parseDuration('0h'), isNull);
      expect(parseDuration('1:75'), isNull, reason: '75 minutos no es una hora válida');
      expect(parseDuration('2:60'), isNull);
      expect(parseDuration('-30'), isNull);
    });
  });

  group('formatDurationInput: ida y vuelta', () {
    test('menos de una hora, en minutos', () {
      expect(formatDurationInput(const Duration(minutes: 45)), '45');
      expect(formatDurationInput(const Duration(minutes: 5)), '5');
    });

    test('hora exacta, con h', () {
      expect(formatDurationInput(const Duration(hours: 2)), '2h');
    });

    test('hora y media, como reloj', () {
      expect(formatDurationInput(const Duration(minutes: 90)), '1:30');
      expect(formatDurationInput(const Duration(hours: 2, minutes: 5)), '2:05');
    });

    test('lo formateado se vuelve a entender igual', () {
      for (final d in const [
        Duration(minutes: 5),
        Duration(minutes: 45),
        Duration(minutes: 90),
        Duration(hours: 2),
        Duration(hours: 2, minutes: 5),
        Duration(hours: 3, minutes: 15),
      ]) {
        expect(parseDuration(formatDurationInput(d)), d, reason: 'falló con $d');
      }
    });
  });

  group('materializeTemplate: encadena las duraciones', () {
    final plantilla = RundownTemplate(
      id: 't1',
      name: 'Culto dominical',
      activities: const [
        TemplateActivity(title: 'Alabanza', duration: Duration(minutes: 20)),
        TemplateActivity(title: 'Prédica', duration: Duration(minutes: 45)),
        TemplateActivity(title: 'Oración', duration: Duration(minutes: 15)),
      ],
    );

    test('cada una empieza cuando acaba la anterior', () {
      final inicio = DateTime(2026, 10, 18, 10, 0);
      final items = materializeTemplate(
        plantilla,
        inicio,
        nextId: (i) => 'id-$i',
      );

      expect(items.length, 3);
      expect(items[0].startTime, DateTime(2026, 10, 18, 10, 0));
      expect(items[1].startTime, DateTime(2026, 10, 18, 10, 20));
      expect(items[2].startTime, DateTime(2026, 10, 18, 11, 5));
      expect(items[2].endTime, DateTime(2026, 10, 18, 11, 20));
      expect(items.map((a) => a.title), ['Alabanza', 'Prédica', 'Oración']);
    });

    test('la última conserva SU duración, no la de por defecto', () {
      final items = materializeTemplate(
        plantilla,
        DateTime(2026, 10, 18, 10, 0),
        nextId: (i) => 'id-$i',
      );

      // Al tener hora de fin explícita, resolveSchedule no la recorta a 30 min.
      final programadas = resolveSchedule(items);
      expect(programadas.last.plannedDuration, const Duration(minutes: 15));
      expect(programadas.last.hasExplicitEnd, isTrue);
    });

    test('plantilla vacía no genera nada', () {
      final vacia = RundownTemplate(id: 'x', name: 'vacía');
      expect(
        materializeTemplate(vacia, DateTime(2026, 10, 18), nextId: (_) => 'x'),
        isEmpty,
      );
    });
  });

  group('RundownTemplate.fromDay: guardar un día como plantilla', () {
    test('conserva las duraciones reales del día', () {
      final fecha = DateTime(2026, 10, 18);
      final dia = EventDay(
        id: 'd',
        name: 'Domingo 18',
        date: fecha,
        activities: [
          ActivityItem(
            id: 'a1',
            title: 'Alabanza',
            startTime: DateTime(2026, 10, 18, 10, 0),
          ),
          ActivityItem(
            id: 'a2',
            title: 'Prédica',
            startTime: DateTime(2026, 10, 18, 11, 0),
          ),
          ActivityItem(
            id: 'a3',
            title: 'Oración',
            startTime: DateTime(2026, 10, 18, 12, 0),
          ),
        ],
      );

      final plantilla =
          RundownTemplate.fromDay(dia, id: 't', name: 'Domingo');

      expect(
        plantilla.activities.map((a) => a.title),
        ['Alabanza', 'Prédica', 'Oración'],
      );
      expect(plantilla.activities[0].duration, const Duration(hours: 1));
      expect(plantilla.activities[1].duration, const Duration(hours: 1));
      // La última no tiene fin propio, así que cae en la duración por defecto.
      expect(plantilla.activities[2].duration, const Duration(minutes: 30));
      expect(plantilla.totalDuration, const Duration(hours: 2, minutes: 30));
    });

    test('una ida y vuelta por JSON preserva todo', () {
      final original = RundownTemplate(
        id: 't1',
        name: 'Culto',
        activities: const [
          TemplateActivity(
            title: 'Prédica',
            duration: Duration(minutes: 45),
            responsible: 'Pastor',
            location: 'Auditorio',
          ),
        ],
      );

      final copia = RundownTemplate.fromJson(original.toJson());

      expect(copia.id, original.id);
      expect(copia.name, original.name);
      expect(copia.activities.single.title, 'Prédica');
      expect(copia.activities.single.duration, const Duration(minutes: 45));
      expect(copia.activities.single.responsible, 'Pastor');
      expect(copia.activities.single.location, 'Auditorio');
    });
  });
}
