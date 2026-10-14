import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:window_manager/window_manager.dart';

import 'src/app.dart';
import 'src/data/hive_boxes.dart';

const Size _initialWindowSize = Size(1320, 860);
const Size _minimumWindowSize = Size(960, 640);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Datos de locale español para los formatos de intl («sábado», «a. m.»).
  await initializeDateFormatting('es', null);

  // Las cajas se abren antes de correr la app: el repositorio es sincrónico.
  // La app arranca VACÍA: no se precarga ningún itinerario.
  await initHive();

  // Ventana de escritorio: tamaño inicial, tamaño mínimo y centrado.
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      size: _initialWindowSize,
      minimumSize: _minimumWindowSize,
      center: true,
      title: 'Rundown · Timer',
      titleBarStyle: TitleBarStyle.normal,
    ),
    () async {
      runApp(const ProviderScope(child: RundownApp()));
    },
  );
}
