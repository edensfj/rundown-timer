import 'dart:async';
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
import '../state/run_show_provider.dart';
import '../ui/theme.dart';
import '../ui/widgets/stage_view.dart';
import 'stage_run_command.dart';
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

/// Nombre del canal por el que **el escenario le habla al panel**: sus botones y
/// sus avisos.
///
/// Va aparte del canal por el que el panel le habla al escenario, y no es un
/// capricho de nomenclatura: el plugin deja **un solo motor registrado por nombre
/// de canal** (`unidirectional`: uno registra, todos invocan), así que los dos
/// sentidos no pueden compartir el suyo. Registrándolo los dos, el segundo en
/// llegar se queda fuera con `CHANNEL_LIMIT_REACHED`; y como el panel registra el
/// primero —su motor ya está en marcha, mientras el del escenario acaba de
/// nacer—, el que se quedaba fuera era el escenario. Esa excepción salía del
/// arranque, subía por `main` y mataba la ventana **antes de pintar nada**: de ahí
/// la ventana blanca y vacía, y de ahí que no se mostrara ni sola. Era *el* fallo
/// del escenario en Windows.
String stageRunChannelName(String windowId) => 'rundown/stage-run/$windowId';

/// Método con el que el escenario le cuenta al panel que no ha podido montarse.
///
/// `desktop_multi_window` crea la ventana del escenario **oculta**, para poder
/// colocarla en la pantalla correcta antes de que nadie la vea. El precio de
/// hacerlo así es que cualquier fallo de arranque se queda mudo: la ventana no
/// aparece y el panel cree que todo va bien, porque para él el escenario se
/// «abrió». Con esta orden, un fallo de arranque sale a la luz como lo que es —
/// un aviso con el motivo— en lugar de un botón que dice «cerrar» y nada más.
const String stageFailedCommand = 'stage_failed';

/// Método (o palabra) con la que el panel mueve la ventana del escenario.
const String stageWindowCommand = 'window';

/// Clave que distingue una orden de ventana de una instantánea del reloj, que
/// viaja por el mismo canal.
const String stageWindowCommandKey = 'cmd';

/// Instrucciones para **cambiar la ventana** del escenario.
///
/// Existe por un caso que el sistema no resuelve solo: al **desconectar la
/// pantalla** del escenario —se unpluga la TV—, el sistema no devuelve la ventana
/// a su sitio, la recoloca sobre la pantalla que queda y **mantiene el modo
/// pantalla completa**. El reloj acaba encima del panel del operador, a pantalla
/// completa y sin poder programarse al lado. Quien puede arreglarlo es el panel,
/// que es quien sabe qué pantalla se ha ido, así que se lo dice al escenario.
@immutable
class StageWindowCommand {
  const StageWindowCommand({required this.frame, required this.fullscreen});

  /// La ventana normal de siempre.
  const StageWindowCommand.windowed(this.frame) : fullscreen = false;

  final Rect frame;
  final bool fullscreen;

  String encode() => jsonEncode(toJson());

  Map<String, dynamic> toJson() => {
    stageWindowCommandKey: stageWindowCommand,
    'x': frame.left,
    'y': frame.top,
    'width': frame.width,
    'height': frame.height,
    'fullscreen': fullscreen,
  };

  /// `null` si lo recibido no es una orden de ventana: entonces es una
  /// instantánea del reloj.
  static StageWindowCommand? tryDecode(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      return fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Lo mismo, para cuando la orden llega ya deserializada por el canal del
  /// plugin en vez de como texto.
  static StageWindowCommand? fromJson(Map json) {
    if (json[stageWindowCommandKey] != stageWindowCommand) return null;

    try {
      return StageWindowCommand(
        frame: Rect.fromLTWH(
          (json['x'] as num).toDouble(),
          (json['y'] as num).toDouble(),
          (json['width'] as num).toDouble(),
          (json['height'] as num).toDouble(),
        ),
        fullscreen: json['fullscreen'] as bool? ?? false,
      );
    } catch (_) {
      // Orden sin geometría: no hay nada que colocar.
      return null;
    }
  }
}

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

  // Canal de **vuelta** —del escenario al panel—: los botones y los avisos. Se
  // registra en el panel y se usa desde aquí; ver [stageRunChannelName].
  final vuelta = WindowMethodChannel(
    stageRunChannelName(controller.windowId),
    mode: ChannelMode.unidirectional,
  );

  stageRunSender = (command) {
    unawaited(
      vuelta.invokeMethod(StageRunCommand.channelKey, command.toJson()),
    );
  };

  // Canal de **ida** —del panel al escenario—: el reloj y las órdenes de ventana.
  // Este lo registra el escenario y lo usa el panel. Se reintenta porque el
  // plugin de esta ventana termina de registrarse **después** de que su motor ya
  // está corriendo: preguntar en el primer instante puede contestar «no hay
  // nadie», y ese tropiezo de milisegundos no puede costarle el reloj al
  // operador.
  try {
    await _reintentando(
      'el canal del reloj',
      () => controller.setWindowMethodHandler(_stageMethodHandler(container)),
    );
  } catch (error) {
    await _avisarAlPanel(vuelta, '$error');
  }

  // El arranque **nunca** se aborta antes de pintar. La ventana llega oculta y
  // sin nadie mirándola: si algo falla aquí, el operador se queda sin escenario
  // y sin un solo aviso. Se le cuenta al panel —que es quien puede decirlo— y se
  // dibuja el reloj igual, mejor una ventana mal puesta que ninguna.
  try {
    await _prepareStageWindow(
      args,
      onProblem: (message) => unawaited(_avisarAlPanel(vuelta, message)),
    );
  } catch (error) {
    await _avisarAlPanel(vuelta, '$error');
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const StageWindowApp(),
    ),
  );
}

/// Lo que el escenario atiende cuando le habla el panel.
Future<dynamic> Function(MethodCall) _stageMethodHandler(
  ProviderContainer container,
) {
  return (call) async {
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

      case stageWindowCommand:
        final command = StageWindowCommand.fromJson(
          (call.arguments as Map).cast<dynamic, dynamic>(),
        );
        if (command != null) await applyStageWindowCommand(command);
        return null;

      default:
        throw MissingPluginException('Método no soportado: ${call.method}');
    }
  };
}

/// Reintenta [action] hasta que deje de fallar.
///
/// El plugin de la segunda ventana **termina de registrarse después** de que su
/// motor haya arrancado, así que las primeras llamadas pueden contestar «no hay
/// nadie». Sin estos reintentos, un tropiezo de milisegundos se convierte en una
/// ventana en blanco para siempre.
Future<T> _reintentando<T>(
  String que,
  Future<T> Function() action, {
  int intentos = 40,
}) async {
  Object? ultimo;

  for (var intento = 0; intento < intentos; intento++) {
    try {
      return await action();
    } catch (error) {
      ultimo = error;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  throw Exception('$que no respondió: $ultimo');
}

/// Le cuenta al panel lo que ha fallado al montar el escenario.
///
/// Va por el canal de vuelta y no por el de ida: el de ida lo registra el propio
/// escenario, así que invocarlo desde aquí se lo devolvería a sí mismo.
Future<void> _avisarAlPanel(WindowMethodChannel vuelta, String message) async {
  try {
    await vuelta.invokeMethod(stageFailedCommand, {'error': message});
  } catch (_) {
    // Si ni el aviso llega, no queda más que pintar el reloj: la ventana ya está
    // en pantalla y el operador la ve.
  }
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

  // En Linux el escenario es otro proceso: sus botones salen por su salida
  // estándar, que el panel ya tiene abierta.
  stageRunSender = sendStageRunCommandByStdout;

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

  await _prepareStageWindow(
    args,
    onProblem: (message) => stdout.writeln('escenario: $message'),
  );

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const StageWindowApp(),
    ),
  );
}

/// Una línea de la entrada estándar: una orden de ventana, la de cerrar o una
/// instantánea del reloj.
void _onStageLine(ProviderContainer container, String line) {
  if (line == stageCloseCommand) {
    windowManager.destroy();
    return;
  }

  // Las órdenes de ventana viajan por la misma tubería que el reloj, y tienen que
  // ganar: si se TOMasen por una instantánea, el reloj se quedaría congelado en
  // el último estado recibido.
  final command = StageWindowCommand.tryDecode(line);
  if (command != null) {
    unawaited(applyStageWindowCommand(command));
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

/// Deja la ventana del escenario como le han mandado.
///
/// Se sale del modo pantalla completa **antes** de colocar nada: mientras siga
/// activo, el sistema sigue recolocando la ventana por su cuenta, y quitarlo
/// después dejaría una ventana con la medida de una pantalla que ya no existe.
Future<void> applyStageWindowCommand(StageWindowCommand command) async {
  try {
    await windowManager.setFullScreen(false);

    // Se quita la maximización **sin preguntar**, en vez de consultarla: al
    // salir de una pantalla completa el sistema devuelve la ventana al estado
    // que tenía antes —normalmente maximizada—, y una ventana maximizada
    // **ignora el tamaño** que se le pida después. Es más, el sistema no
    // responde la verdad: preguntar si estaba maximizada devuelve «no» cuando sí
    // lo está, que es justo lo que pasaba al desenchufar la TV —el reloj se
    // quedaba ocupando la pantalla entera del operador sin que nadie le hubiera
    // pedido maximizarse—, así que aquí no se pregunta: se quita siempre.
    await windowManager.unmaximize();
  } catch (_) {
    // Si el sistema no responde al estado de la ventana, se sigue con la
    // colocación: es el camino que devuelve el reloj a una ventana normal.
  }

  await placeWindow(command.frame, fullscreen: command.fullscreen);

  // Colocarla la deja visible; si el sistema la había escondido al recolocarla
  // tras la desconexión, se enseña otra vez.
  try {
    await windowManager.show();
  } catch (_) {
    // Si ya está visible, no hay nada que rehacer.
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

    // Y los botones no manejan un reloj propio —que no pinta nada—, sino que
    // le piden al panel que lo haga.
    runShowProvider.overrideWith(StageRunBridge.new),
  ],
);

/// Pone la ventana del escenario donde le dijeron. Igual en los dos caminos.
///
/// El orden de estos tres pasos no es cosmético, y en Windows es justo la
/// diferencia entre ver el reloj y no ver nada:
///
/// 1. **Colocar antes de mostrar**: es lo que hace que la pantalla completa se
///    ancle a la pantalla elegida y no a la principal.
/// 2. **Mostrar antes de poner a pantalla completa**: la ventana llega oculta
///    —a propósito, por el punto 1—, así que si el paso 3 falla, la ventana se
///    queda invisible para siempre, sin ventana ni un solo aviso.
/// 3. **Pantalla completa al final**, ya visible y en su sitio.
///
/// Y ningún paso puede impedir que la ventana se vea: si colocar o pantalla
/// completa fallan, se le cuenta al panel y se sigue adelante.
Future<void> _prepareStageWindow(
  StageWindowArgs args, {
  void Function(String message)? onProblem,
}) async {
  await windowManager.ensureInitialized();
  await windowManager.setTitle(AppConfig.stageWindowTitle);

  try {
    await placeWindow(args.frame, fullscreen: false, force: true);
  } catch (error) {
    onProblem?.call('no se pudo colocar la ventana: $error');
  }

  await windowManager.show();

  if (args.fullscreen) {
    unawaited(_irAPantallaCompleta(onProblem));
  }

  // El escenario puede estar horas proyectándose: la pantalla no se apaga.
  await WakelockPlus.enable();
}

/// Se va a pantalla completa cuando se pidió.
///
/// En algunas combinaciones Windows/monitor el primer intento no prende hasta
/// que la ventana se ha mostrado, así que se le da una segunda oportunidad un
/// instante después. Si tampoco funciona, la ventana se queda visible y en su
/// sitio: es un reloj feo, pero el operador lo ve y puede seguir trabajando.
Future<void> _irAPantallaCompleta(void Function(String)? onProblem) async {
  try {
    await windowManager.setFullScreen(true);
  } catch (error) {
    onProblem?.call('no se pudo poner a pantalla completa: $error');
    return;
  }

  await Future<void>.delayed(const Duration(milliseconds: 300));
  try {
    if (!await windowManager.isFullScreen()) {
      await windowManager.setFullScreen(true);
    }
  } catch (_) {
    // Si ya lo está, no hay nada que rehacer.
  }
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
      home: const Material(color: StageColors.black, child: StageView()),
    );
  }
}

/// Lo que se pinta cuando el arranque de una ventana falla.
///
/// Existe para no morir en silencio. En Windows la ventana del escenario nace
/// **oculta** y su motor no pinta nada hasta que alguien llega a `runApp`: una
/// excepción por el camino se queda en una ventana blanca y vacía, sin una sola
/// pista de qué ha pasado y sin haber mostrado nunca la ventana. Con esto, el
/// fallo se lee —y se puede copiar— en vez de adivinarse.
class StageStartupErrorApp extends StatelessWidget {
  const StageStartupErrorApp({super.key, required this.error, this.stack});

  final String error;
  final String? stack;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(
        color: StageColors.black,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SelectableText(
                  'No se pudo arrancar esta ventana',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                SelectableText(
                  error,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                if (stack != null) ...[
                  const SizedBox(height: 24),
                  SelectableText(
                    stack!,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
