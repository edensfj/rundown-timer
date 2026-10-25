import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:window_manager/window_manager.dart';

import '../app.dart';
import '../core/app_config.dart';
import '../data/hive_boxes.dart';
import '../window/stage_window.dart';

const Size _initialWindowSize = Size(1320, 860);
const Size _minimumWindowSize = Size(960, 640);

/// Con lo que el plugin de la segunda ventana arranca su motor; ver
/// [_stageArgsDelMotor].
const String _multiWindowEntrypoint = 'multi_window';

Future<void> bootstrap(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Datos de locale español para los formatos de intl («sábado», «a. m.»).
    await initializeDateFormatting('es', null);

    await _arrancar(args);
  } catch (error, stack) {
    // Nunca morir en silencio. La ventana del escenario nace **oculta** y su
    // motor no pinta nada hasta que alguien llega a `runApp`: una excepción por
    // el camino se queda en una ventana blanca, vacía y sin una sola pista. Con
    // esto, el fallo se lee.
    runApp(StageStartupErrorApp(error: '$error', stack: '$stack'));
  }
}

/// Decide qué es esta ventana —panel, escenario en segunda ventana o escenario
/// en su propio proceso— y la monta.
Future<void> _arrancar(List<String> args) async {
  // El escenario en **segunda ventana** (Windows y macOS). El motor le pasa sus
  // argumentos al arrancar —`multi_window`, el id de la ventana y la geometría—
  // y esos llegan siempre: son parte del arranque del motor, no de un canal que
  // el plugin todavía tiene que registrar. Preguntar por el canal en su lugar
  // era la causa de la ventana en blanco: en la segunda ventana el plugin
  // termina de registrarse *después* de que este código ya está corriendo, así
  // que la pregunta podía quedarse sin respuesta y la ventana moría sin decir
  // nada.
  final porMotor = _stageArgsDelMotor(args);
  if (porMotor != null) {
    // El id lo da el motor, así que no hace falta preguntar al plugin.
    await runStageWindow(WindowController.fromWindowId(args[1]), porMotor);
    return;
  }

  final controller = await _controladorDeEstaVentana();

  final stageArgs = StageWindowArgs.tryDecode(controller.arguments);
  if (stageArgs != null) {
    await runStageWindow(controller, stageArgs);
    return;
  }

  // Y en Linux, donde el escenario es una segunda **instancia** de la app en vez
  // de una segunda ventana, lo dice la variable de entorno con la que el panel
  // la lanza.
  final enProceso = StageWindowArgs.tryDecode(
    Platform.environment[AppConfig.stageEnvKey] ?? '',
  );

  if (enProceso != null) {
    await runStageProcess(enProceso);
    return;
  }

  await _arrancarPanel();
}

/// La geometría que el motor le pasa a esta ventana al arrancar.
///
/// El plugin de la segunda ventana arranca su motor con
/// `multi_window <id> <geometría>`; el panel arranca con la línea de órdenes del
/// proceso, que no empieza por `multi_window`.
StageWindowArgs? _stageArgsDelMotor(List<String> args) {
  if (args.length < 3 || args.first != _multiWindowEntrypoint) return null;
  return StageWindowArgs.tryDecode(args[2]);
}

/// El controlador de esta ventana, esperando a que el plugin esté listo.
///
/// El plugin registra el canal de cada ventana un instante después de que su
/// motor haya arrancado, así que la primera pregunta puede contestar «no hay
/// nadie». Se le da margen en vez de dar la ventana por perdida.
Future<WindowController> _controladorDeEstaVentana() async {
  Object? ultimo;

  for (var intento = 0; intento < 40; intento++) {
    try {
      return await WindowController.fromCurrentEngine();
    } catch (error) {
      ultimo = error;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  throw Exception('el canal de la ventana no respondió: $ultimo');
}

/// Arranca el panel: es la ventana principal.
Future<void> _arrancarPanel() async {
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
