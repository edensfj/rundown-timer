import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

import '../core/app_config.dart';
import '../models/countdown_phase.dart';
import '../models/countdown_snapshot.dart';
import '../state/countdown_provider.dart';
import '../ui/theme.dart';
import '../ui/widgets/stage_view.dart';
import 'window_placement.dart';

/// La ventana del escenario se abre en **su propio motor de Flutter**, así que
/// no comparte memoria con el panel: lo que se proyecta tiene que viajar como
/// datos. Estas son las instrucciones de arranque.
@immutable
class StageWindowArgs {
  const StageWindowArgs({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.fullscreen,
  });

  final double x;
  final double y;
  final double width;
  final double height;

  /// `true` cuando hay una pantalla elegida y el escenario debe ocuparla entera.
  final bool fullscreen;

  Rect get frame => Rect.fromLTWH(x, y, width, height);

  /// El panel abre la ventana con este JSON; el hijo decide con él qué correr.
  String encode() => jsonEncode(toJson());

  Map<String, dynamic> toJson() => {
        'role': 'stage',
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'fullscreen': fullscreen,
      };

  /// `null` cuando los argumentos no son de la ventana del escenario, es decir,
  /// cuando estamos en la ventana principal.
  static StageWindowArgs? tryDecode(String raw) {
    if (raw.isEmpty) return null;

    try {
      final json = jsonDecode(raw);
      if (json is! Map || json['role'] != 'stage') return null;

      return StageWindowArgs(
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        width: (json['width'] as num).toDouble(),
        height: (json['height'] as num).toDouble(),
        fullscreen: json['fullscreen'] as bool? ?? false,
      );
    } catch (_) {
      // Argumentos ilegibles: se prefiere arrancar el panel antes que no abrir
      // nada, así que se trata como ventana principal.
      return null;
    }
  }
}

/// Última instantánea recibida del panel.
///
/// En la ventana del escenario sustituye a [countdownProvider], de modo que
/// [StageView] se reutiliza tal cual sin saber que los datos vienen de fuera.
class RemoteSnapshotNotifier extends Notifier<CountdownSnapshot> {
  @override
  CountdownSnapshot build() => const CountdownSnapshot.empty();

  void push(CountdownSnapshot snapshot) => state = snapshot;
}

final remoteSnapshotProvider =
    NotifierProvider<RemoteSnapshotNotifier, CountdownSnapshot>(
  RemoteSnapshotNotifier.new,
);

/// Orden con la que el panel manda cerrarse al escenario cuando va en su propio
/// proceso: llega por la entrada estándar, como las instantáneas.
const String stageCloseCommand = 'close';

/// Monta la ventana del escenario y no vuelve hasta que se cierra.
///
/// Se llama desde `main` cuando los argumentos del motor indican que esta
/// ventana es el escenario, no el panel. Es el camino de Windows y macOS, donde
/// el escenario es una **segunda ventana del mismo proceso** y habla con el
/// panel por el canal del plugin.
Future<void> runStageWindow(
  WindowController controller,
  StageWindowArgs args,
) async {
  final container = _stageContainer();

  await controller.setWindowMethodHandler((call) async {
    switch (call.method) {
      case 'update':
        final data = (call.arguments as Map).cast<dynamic, dynamic>();
        container
            .read(remoteSnapshotProvider.notifier)
            .push(CountdownSnapshot.fromJson(data));
        return null;

      case 'close':
        await windowManager.destroy();
        return null;

      default:
        throw MissingPluginException('Método no soportado: ${call.method}');
    }
  });

  await _prepareStageWindow(args);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const StageWindowApp(),
    ),
  );
}

/// Monta el escenario **en su propio proceso** y no vuelve hasta que se cierra.
///
/// Es el camino de Linux, donde no se puede tener una segunda vista de Flutter
/// dentro del mismo proceso (ver `stageSecondWindowProvider`) pero sí una
/// segunda instancia de la app. El panel la lanza con la geometría en
/// [AppConfig.stageEnvKey] y le manda el reloj por la entrada estándar: una
/// instantánea por línea, en JSON.
Future<void> runStageProcess(StageWindowArgs args) async {
  final container = _stageContainer();

  // La tubería se cierra cuando el panel se va. Mejor cerrar que quedarse
  // proyectando un reloj congelado en una ventana huérfana.
  stdin
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen(
        (line) => _onStageLine(container, line),
        onDone: windowManager.destroy,
        onError: (_) {},
      );

  await _prepareStageWindow(args);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const StageWindowApp(),
    ),
  );
}

/// Una línea de la entrada estándar: la orden de cerrar o una instantánea.
void _onStageLine(ProviderContainer container, String line) {
  if (line == stageCloseCommand) {
    windowManager.destroy();
    return;
  }

  try {
    final data = jsonDecode(line);
    if (data is! Map) return;

    container
        .read(remoteSnapshotProvider.notifier)
        .push(CountdownSnapshot.fromJson(data.cast<dynamic, dynamic>()));
  } catch (_) {
    // Una línea ilegible no puede tumbar el reloj: se espera la siguiente.
  }
}

/// El contenedor del escenario, con el reloj sustituido por lo que llega de
/// fuera.
ProviderContainer _stageContainer() => ProviderContainer(
      overrides: [
        // Todo lo que pinta el escenario lee de [countdownProvider]; con esta
        // sustitución, lo que llega por el canal se ve exactamente igual que si
        // se hubiera calculado aquí.
        countdownProvider.overrideWith((ref) => ref.watch(remoteSnapshotProvider)),
      ],
    );

/// Pone la ventana del escenario donde le dijeron. Igual en los dos caminos.
Future<void> _prepareStageWindow(StageWindowArgs args) async {
  // La ventana se coloca sola con lo que le mandó el panel: así no hace falta
  // que el otro lado espere a que este motor termine de arrancar.
  await windowManager.ensureInitialized();
  await windowManager.setTitle(AppConfig.stageWindowTitle);
  await placeWindow(args.frame, fullscreen: args.fullscreen);
  await windowManager.show();

  // El escenario puede estar horas proyectándose: la pantalla no se apaga.
  await WakelockPlus.enable();
}

/// La app que corre dentro de la ventana del escenario: **solo el reloj**.
///
/// Sin controles y sin notificaciones: esto es lo que ve el público. El
/// operador manda desde el panel, que sigue abierto en la otra ventana.
///
/// Ojo con el `Material`: no es decorativo. Sin él —o sin un `Scaffold`, que lo
/// crea— el texto cuelga del estilo de error que `MaterialApp` pone por defecto
/// para texto sin `Material`: monoespaciado, rojo y con **subrayado amarillo
/// doble**. Los dígitos, gigantes, convertían ese subrayado en una barra
/// amarilla maciza cruzando la pantalla, y el subtítulo lo enseñaba como una
/// raya bajo las letras. No es un desbordamiento —no depende del tamaño ni del
/// modo debug— y sale igual en el instalador.
///
/// Nota sobre Linux: el embedder tiene un fallo conocido al crear una segunda
/// vista —`Failed to setup compositor shaders, unable to make OpenGL context
/// current`— que se lleva por delante el **texto** (los colores planos sí se
/// pintan), y al destruirla `Failed to cleanup compositor shaders` mata el
/// proceso. Por eso en Linux el escenario es una segunda **instancia** de la app
/// y no una segunda ventana; ver `stageSecondWindowProvider`.
class StageWindowApp extends ConsumerWidget {
  const StageWindowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: AppConfig.stageWindowTitle,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const Material(
        color: StageColors.black,
        child: StageView(),
      ),
    );
  }
}
