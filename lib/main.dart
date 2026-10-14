import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:window_manager/window_manager.dart';

import 'src/app.dart';
import 'src/data/hive_boxes.dart';
import 'src/window/stage_window.dart';

const Size _initialWindowSize = Size(1320, 860);
const Size _minimumWindowSize = Size(960, 640);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Datos de locale español para los formatos de intl («sábado», «a. m.»).
  await initializeDateFormatting('es', null);

  // ¿Esta ventana es el panel o el escenario? Lo dicen los argumentos del
  // motor: el panel arranca sin ninguno, y el escenario con la geometría que
  // le mandó el panel al abrirlo.
  final controller = await WindowController.fromCurrentEngine();
  final stageArgs = StageWindowArgs.tryDecode(controller.arguments);

  if (stageArgs != null) {
    await runStageWindow(controller, stageArgs);
    return;
  }

  // Solo el panel abre la base de datos. El escenario recibe por mensajes lo
  // que tiene que pintar, y dos motores abriendo las mismas cajas de Hive a la
  // vez es pedir problemas.
  await initHive();

  // Ventana principal: tamaño inicial, tamaño mínimo y centrado. La app
  // arranca VACÍA: no se precarga ningún itinerario.
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
