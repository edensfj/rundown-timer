import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../app.dart';
import '../data/hive_boxes.dart';

/// Arranque de la versión web.
///
/// No hay ventanas nativas ni segundo proceso: el escenario se proyecta dentro
/// de la misma pestaña. Hive guarda en IndexedDB, así que la programación
/// persiste igual que en escritorio.
Future<void> bootstrap(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('es', null);
  await initHive();

  runApp(const ProviderScope(child: RundownApp()));
}
