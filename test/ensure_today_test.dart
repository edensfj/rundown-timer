import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rundown/src/data/rundown_repository.dart';
import 'package:rundown/src/state/rundown_provider.dart';
import 'package:rundown/src/state/selected_day_provider.dart';

/// `ensureToday`: sin día seleccionado se crea el de hoy para poder programar
/// sin crearlo a mano antes.
///
/// Se prueba contra Hive de verdad en un temporal: el notificador persiste y
/// selecciona a través del repositorio, y eso es justo lo que se quiere
/// comprobar. Nada de esto toca los datos reales.
void main() {
  late Directory dir;

  setUpAll(() async {
    // El nombre del día («miércoles 14») sale de `intl` en español.
    await initializeDateFormatting('es', null);
    dir = await Directory.systemTemp.createTemp('rundown_ensure_today');
    Hive.init(dir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  Future<ProviderContainer> contenedor(String tag) async {
    final repository = RundownRepository(
      await Hive.openBox<Map>('days_$tag'),
      await Hive.openBox<Map>('tpl_$tag'),
      await Hive.openBox<dynamic>('meta_$tag'),
    );
    final container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    // Espera a que el notificador cargue el estado inicial.
    await container.read(rundownProvider.future);
    return container;
  }

  /// 14 de octubre de 2026, miércoles, a las 18:25.
  DateTime tarde() => DateTime(2026, 10, 14, 18, 25);

  test('sin días crea el de hoy, sin hora, y lo selecciona', () async {
    final container = await contenedor('vacio');
    final notifier = container.read(rundownProvider.notifier);

    final day = await notifier.ensureToday(now: tarde(), id: 'hoy');

    expect(day.id, 'hoy');
    expect(
      day.date,
      DateTime(2026, 10, 14),
      reason: 'el día es la fecha, sin la hora de creación',
    );
    expect(day.name, 'miércoles 14');
    expect(container.read(selectedDayProvider), 'hoy');

    final repository = container.read(repositoryProvider);
    expect(repository.loadDays().map((d) => d.id), [
      'hoy',
    ], reason: 'también queda guardado');
    expect(repository.loadSelectedDayId(), 'hoy');
  });

  test('con día seleccionado lo devuelve sin crear nada', () async {
    final container = await contenedor('seleccionado');
    final notifier = container.read(rundownProvider.notifier);
    await notifier.addDay(
      name: 'Sábado 17',
      date: DateTime(2026, 10, 17),
      id: 'sabado',
    );

    final day = await notifier.ensureToday(now: tarde(), id: 'hoy');

    expect(day.id, 'sabado');
    expect(container.read(repositoryProvider).loadDays(), hasLength(1));
  });

  test(
    'si la selección apunta a un día que ya no existe crea el de hoy',
    () async {
      final container = await contenedor('obsoleto');
      final notifier = container.read(rundownProvider.notifier);
      await notifier.addDay(
        name: 'Sábado 17',
        date: DateTime(2026, 10, 17),
        id: 'sabado',
      );
      container.read(selectedDayProvider.notifier).select('fantasma');

      final day = await notifier.ensureToday(now: tarde(), id: 'hoy');

      expect(day.id, 'hoy');
      expect(container.read(selectedDayProvider), 'hoy');
      expect(container.read(repositoryProvider).loadDays().map((d) => d.id), [
        'hoy',
        'sabado',
      ]);
    },
  );
}
