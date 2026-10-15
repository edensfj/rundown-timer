import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import '../core/app_config.dart';
import '../models/countdown_snapshot.dart';
import '../state/countdown_provider.dart';
import '../state/displays_provider.dart';
import 'stage_window.dart';
import 'window_placement.dart';

/// Si el escenario está proyectándose y, si algo falló, por qué.
@immutable
class StageWindowStatus {
  const StageWindowStatus({
    this.isOpen = false,
    this.isEmbedded = false,
    this.error,
  });

  final bool isOpen;

  /// `true` cuando el reloj se proyecta **desde la ventana del panel**, sin
  /// segunda ventana. Es lo que ocurre en Linux; ver
  /// [stageSecondWindowProvider].
  final bool isEmbedded;

  /// Mensaje del último intento fallido de abrir la ventana.
  final String? error;

  bool get hasError => error != null;
}

/// ¿Se puede proyectar el escenario en **su propia ventana**?
///
/// En Windows y macOS sí. En Linux no: el embedder no aguanta dos vistas de
/// Flutter a la vez. Al crear la segunda avisa `Failed to setup compositor
/// shaders, unable to make OpenGL context current` y el escenario se queda sin
/// poder pintar texto (los colores planos sí se ven); al destruirla avisa
/// `Failed to cleanup compositor shaders` —y ahí se lleva por delante el
/// proceso entero, se cierre como se cierre—. Por eso en Linux el escenario se
/// proyecta en modo de una sola ventana: la del panel.
final stageSecondWindowProvider = Provider<bool>((ref) => !Platform.isLinux);

/// Controla **dónde** se proyecta el escenario.
///
/// En Windows y macOS el panel ya no se convierte en escenario: crea una
/// ventana aparte y se queda donde está, para poder seguir programando mientras
/// el reloj se proyecta. En Linux sí se convierte, por lo explicado en
/// [stageSecondWindowProvider].
class StageWindowNotifier extends Notifier<StageWindowStatus> {
  WindowController? _controller;

  /// El escenario como proceso aparte; ver [_openSeparateProcess].
  Process? _process;

  StreamSubscription<void>? _windowEvents;

  /// Geometría que tenía la ventana del panel antes de entrar al escenario, para
  /// devolvérsela al salir. Solo se usa en el modo de una sola ventana.
  Rect? _boundsBeforeStage;

  /// Pantalla en la que se instaló el escenario, por [displayKeyOf].
  ///
  /// Es lo que permite enterarse de que esa pantalla ha desaparecido: al
  /// desenchufar la TV, el sistema deja la ventana **a pantalla completa sobre la
  /// pantalla del operador**, tapando el panel entero.
  String? _stageDisplayKey;

  /// Si el escenario llegó a ocupar una pantalla entera.
  bool _stageFullscreen = false;

  /// Si fue la app quien bajó el escenario a ventana normal al perder la pantalla,
  /// para devolvérsela si esa pantalla vuelve.
  bool _degradedToWindow = false;

  /// Envíos seguidos que han fallado; ver [push].
  int _pushFailures = 0;

  @override
  StageWindowStatus build() {
    // El escenario es un espejo del panel: cada vez que cambia lo que hay que
    // mostrar se le manda. Va aquí y no en la UI para que no se pueda olvidar
    // en algún camino.
    ref.listen(countdownProvider, (_, next) => push(next));

    // Mientras el escenario esté proyectando, el reparto de pantallas manda: si
    // la pantalla de la TV se va, su ventana tiene que volver a ser una ventana
    // normal en vez de quedarse a pantalla completa sobre el panel.
    ref.listen(
      displaysProvider,
      (_, next) => unawaited(_onDisplaysChanged(next.value)),
    );

    // El aspa de la ventana del escenario la cierra sin pasar por nosotros. El
    // plugin avisa de ello (en Windows, al destruirse su motor, `RemoveWindow`
    // recorre las ventanas que quedan y avisa), pero solo hay ventana propia
    // fuera de Linux.
    if (ref.read(stageSecondWindowProvider)) _watchWindows();

    ref.onDispose(() {
      _windowEvents?.cancel();
      _windowEvents = null;
    });

    return const StageWindowStatus();
  }

  Future<void> _watchWindows() async {
    try {
      // `onWindowsChanged` es global: avisa de la creación y la destrucción de
      // cualquier ventana, así que no hace falta el controlador de ninguna.
      _windowEvents = onWindowsChanged.listen(
        (_) => _syncIfClosed(),
        // El canal de eventos no está en todas las partes (ni en las pruebas):
        // si falla, es la clase de aviso que puede faltar sin más. Ya queda el
        // recuento de fallos de envío de [push].
        onError: (_) {},
      );
    } catch (_) {
      // Sin eventos de ventana el panel sigue funcionando; solo se pierde el
      // aviso inmediato de que el escenario se cerró desde fuera. Queda el
      // recuento de fallos de envío de [push].
    }
  }

  /// Pone el estado en «cerrado» si la ventana del escenario ya no está.
  Future<void> _syncIfClosed() async {
    final controller = _controller;
    if (controller == null) return;

    final vivas = await WindowController.getAll();
    final sigueAbierta =
        vivas.any((window) => window.windowId == controller.windowId);
    if (sigueAbierta) return;

    _controller = null;
    _reset();
  }

  /// Deja el estado en «cerrado» y olvida dónde se había proyectado.
  void _reset() {
    _pushFailures = 0;
    _stageDisplayKey = null;
    _stageFullscreen = false;
    _degradedToWindow = false;
    state = const StageWindowStatus();
  }

  /// Abre el escenario donde corresponda: ventana propia en Windows y macOS,
  /// segunda instancia de la app en Linux.
  ///
  /// Si no hay a dónde proyectar (una sola pantalla) se abre igualmente: nunca
  /// se queda sin reloj.
  Future<void> open() async {
    if (state.isOpen) return;

    final segundaVentana = ref.read(stageSecondWindowProvider);

    try {
      final (frame, fullscreen, displayKey) = await _stageFrame();
      _stageDisplayKey = displayKey;
      _stageFullscreen = fullscreen;
      _degradedToWindow = false;

      final args = StageWindowArgs(
        x: frame.left,
        y: frame.top,
        width: frame.width,
        height: frame.height,
        fullscreen: fullscreen,
      );

      if (segundaVentana) {
        await _openSecondWindow(args);
      } else {
        await _openSeparateProcess(args);
      }
    } catch (error) {
      if (!segundaVentana) {
        // Lanzar la segunda instancia puede fallar (un directorio de solo
        // lectura, un AppImage que no deja reejecutarse...). Sin reloj no se
        // queda: se proyecta dentro del panel, que está siempre.
        await _openInPanel();
        return;
      }

      _controller = null;
      state = StageWindowStatus(error: '$error');
    }
  }

  /// Dónde tiene que salir el escenario, si eso es una pantalla completa y en qué
  /// pantalla se instala.
  ///
  /// La pantalla se devuelve porque sin ella no hay forma de enterarse luego de
  /// que esa pantalla ha desaparecido.
  Future<(Rect, bool, String?)> _stageFrame() async {
    // Se pregunta al sistema en el momento de abrir, no se usa la lista cacheada:
    // si la TV se desconectó hace un segundo, con la lista vieja el escenario
    // salía a pantalla completa sobre la pantalla principal.
    final displays = await readDisplaysNow(ref);
    final panel = await _panelBounds();

    final target = chooseStageDisplay(
      displays: displays,
      selectedKey: ref.read(selectedDisplayProvider),
      panelBounds: panel,
    );

    if (target != null) {
      return (visibleRectOf(target), true, displayKeyOf(target));
    }

    // Sin pantalla elegida: se centra un lienzo de proyector en la pantalla
    // donde está el panel, para poder ver las dos cosas.
    return (await _windowedFrame(displays), false, null);
  }

  /// Una ventana normal de escenario, centrada en la pantalla del panel.
  ///
  /// Es lo que se usa cuando no hay una segunda pantalla donde proyectar, y
  /// también lo que se le pasa al escenario cuando la suya se desconecta: sin
  /// pantalla de la TV, lo único razonable es una ventana sobre la del operador.
  Future<Rect> _windowedFrame(List<Display> displays) async {
    return _centeredOn(
      displayContaining(displays, await _panelBounds()) ?? displays.firstOrNull,
      AppConfig.stageWindowSize,
    );
  }

  /// Reacciona a que el reparto de pantallas cambie con el escenario ya abierto.
  ///
  /// El caso que motiva esto: el escenario está a pantalla completa en la TV, el
  /// operador desenchufa el cable y **el sistema deja la ventana a pantalla
  /// completa sobre la pantalla del operador**. El reloj tapa el panel entero y
  /// no hay forma de seguir programando, así que hay que devolverla a una
  /// ventana normal; y si la pantalla vuelve, devolvérsela sin que el operador
  /// tenga que reabrir el modo escenario en mitad del evento.
  Future<void> _onDisplaysChanged(List<Display>? displays) async {
    if (displays == null || !state.isOpen) return;

    switch (stageScreenChangeFor(
      displays: displays,
      stageDisplayKey: _stageDisplayKey,
      wasFullScreen: _stageFullscreen,
      degradedByUs: _degradedToWindow,
    )) {
      case StageScreenChange.none:
        return;

      case StageScreenChange.toWindow:
        _stageFullscreen = false;
        _degradedToWindow = true;

        // En Linux, si no se pudo lanzar la segunda instancia, el escenario se
        // proyecta en la ventana del propio panel: la que hay que devolver a su
        // sitio es esa.
        if (state.isEmbedded) {
          await _restorePanelBounds();
          return;
        }

        await _sendStageWindow(
          frame: await _windowedFrame(displays),
          fullscreen: false,
        );
        ref.read(stageNoticeProvider.notifier).show(
              'Se ha desconectado la pantalla del escenario: '
              'el reloj vuelve a una ventana normal.',
            );

      case StageScreenChange.toScreen:
        final display = displayByKey(displays, _stageDisplayKey);
        // La decisión anterior ya ha comprobado que está; si aun así no aparece,
        // no se mueve nada: es una carrera contra el sistema.
        if (display == null) return;

        _stageFullscreen = true;
        _degradedToWindow = false;
        await _sendStageWindow(frame: visibleRectOf(display), fullscreen: true);
        ref.read(stageNoticeProvider.notifier).show(
              'La pantalla del escenario ha vuelto.',
            );
    }
  }

  /// Le dice al escenario que cambie su ventana.
  ///
  /// La orden viaja por el mismo canal que el reloj: el plugin en Windows y
  /// macOS, la entrada estándar en Linux. La coloca quien tiene su ventana: el
  /// escenario es otra ventana —u otro proceso— y no se puede mover desde fuera.
  Future<void> _sendStageWindow({
    required Rect frame,
    required bool fullscreen,
  }) async {
    final command = StageWindowCommand(frame: frame, fullscreen: fullscreen);

    final process = _process;
    if (process != null) {
      try {
        process.stdin.writeln(command.encode());
        await process.stdin.flush();
      } catch (_) {
        // El proceso ya no está; [Process.exitCode] se encarga del estado.
      }
      return;
    }

    final controller = _controller;
    if (controller == null) return;

    try {
      await controller.invokeMethod(stageWindowCommand, command.toJson());
    } catch (_) {
      // Si el motor del escenario ya no está, no hay a quién moverle la ventana.
    }
  }

  /// Abre el escenario en una **segunda ventana del mismo proceso**.
  Future<void> _openSecondWindow(StageWindowArgs args) async {
    final controller = await WindowController.create(
      WindowConfiguration(arguments: args.encode()),
    );

    _controller = controller;
    _pushFailures = 0;
    state = const StageWindowStatus(isOpen: true);

    // Primer envío inmediato para que no se vea un reloj vacío al abrir.
    await push(ref.read(countdownProvider));
  }

  /// Abre el escenario como **segunda instancia de la app**.
  ///
  /// Linux no aguanta dos vistas de Flutter dentro de un mismo proceso, pero sí
  /// dos procesos: esta instancia arranca como escenario y recibe el reloj por
  /// su entrada estándar, una instantánea por línea.
  ///
  /// Lo que puede fallar es el lanzamiento; a partir de ahí nada lanza, para que
  /// un fallo no deje dos escenarios a la vez.
  Future<void> _openSeparateProcess(StageWindowArgs args) async {
    final process = await Process.start(
      Platform.resolvedExecutable,
      const [],
      environment: {
        ...Platform.environment,
        AppConfig.stageEnvKey: args.encode(),
      },
      // Los recursos de la app viven junto al ejecutable, así que el directorio
      // de trabajo no puede depender de desde dónde se abrió el panel.
      workingDirectory: File(Platform.resolvedExecutable).parent.path,
    );

    _process = process;
    _pushFailures = 0;
    state = const StageWindowStatus(isOpen: true);

    // Que el operador cierre la ventana del escenario termina su proceso, y esa
    // es la señal de que ya no hay reloj: el botón del panel vuelve solo.
    unawaited(process.exitCode.then((_) => _onProcessGone(process)));

    // El escenario va en su propio proceso: si algo revienta dentro, su aviso
    // tiene que verse donde se lanzó (la consola del panel). Si no hay consola,
    // esto no molesta a nadie.
    process.stdout.transform(utf8.decoder).listen(stdout.write, onError: (_) {});
    process.stderr.transform(utf8.decoder).listen(stderr.write, onError: (_) {});

    await push(ref.read(countdownProvider));
  }

  Future<void> _onProcessGone(Process process) async {
    if (_process != process) return;

    _process = null;
    _reset();
  }

  /// Proyecta el escenario **dentro de la ventana del panel**.
  ///
  /// Es la red de seguridad de Linux: si la segunda instancia no arranca, el
  /// reloj sale donde está el operador, que es mejor que no salir. Si hay una
  /// pantalla elegida, se lleva la ventana entera a ella; con una sola, se queda
  /// donde está, porque no hay otra superficie donde ponerlo.
  Future<void> _openInPanel() async {
    _boundsBeforeStage = await _panelBounds();

    Rect? target;
    String? displayKey;
    try {
      final displays = await ref.read(displaysProvider.future);
      final chosen = chooseStageDisplay(
        displays: displays,
        selectedKey: ref.read(selectedDisplayProvider),
        panelBounds: _boundsBeforeStage,
      );
      if (chosen != null) {
        target = visibleRectOf(chosen);
        displayKey = displayKeyOf(chosen);
      }
    } catch (_) {
      // Sin pantallas legibles se proyecta donde está el panel.
    }

    _stageDisplayKey = displayKey;
    _stageFullscreen = target != null;
    _degradedToWindow = false;

    // Primero se enseña el reloj y después se coloca la ventana: al revés, un
    // fallo al colocarla dejaría al operador sin escenario y sin saber por qué.
    state = const StageWindowStatus(isOpen: true, isEmbedded: true);

    if (target == null) return;
    try {
      await placeWindow(target, fullscreen: true);
    } catch (_) {
      // Colocar la ventana es un extra; el reloj ya está en pantalla.
    }
  }

  /// Cierra el escenario, se esté proyectando donde se esté proyectando.
  Future<void> close() async {
    final embedded = state.isEmbedded;
    final controller = _controller;
    final process = _process;

    _controller = null;
    _process = null;
    _reset();

    if (embedded) {
      await _restorePanelBounds();
      return;
    }

    if (process != null) {
      await _closeProcess(process);
      return;
    }

    if (controller == null) return;
    try {
      await controller.invokeMethod('close');
    } catch (_) {
      // Si el motor del escenario ya no está, no hay nada que cerrar.
    }
  }

  /// Pide a la segunda instancia que se cierre y, si no atiende, la apaga.
  ///
  /// Pedirlo es más limpio: destruye su ventana por el camino normal. El `kill`
  /// queda de red, y sobre un proceso ya terminado no hace nada.
  Future<void> _closeProcess(Process process) async {
    try {
      process.stdin.writeln(stageCloseCommand);
      await process.stdin.flush();
    } catch (_) {
      // Ya no está: no hay a quién pedirle nada.
    }

    unawaited(() async {
      await Future<void>.delayed(const Duration(seconds: 2));
      process.kill();
    }());
  }

  /// Devuelve la ventana del panel a donde estaba antes de proyectar.
  Future<void> _restorePanelBounds() async {
    final bounds = _boundsBeforeStage;
    _boundsBeforeStage = null;
    if (bounds == null) return;

    try {
      await windowManager.setFullScreen(false);
      // También aquí sin preguntar: al salir de pantalla completa el sistema
      // devuelve la ventana al estado que tenía antes, y si estaba maximizada
      // se quedaría ocupando la pantalla entera e ignoraría la medida que se le
      // pide debajo.
      await windowManager.unmaximize();
      await windowManager.setSize(bounds.size);
      await windowManager.setPosition(bounds.topLeft);
    } catch (_) {
      // Devolver la ventana a su sitio es cosmético: si falla, el operador
      // sigue teniendo el panel entero delante.
    }
  }

  Future<void> toggle() => state.isOpen ? close() : open();

  /// Manda al escenario lo que tiene que pintar.
  ///
  /// Los fallos se ignoran a propósito: al abrir, el motor del escenario tarda
  /// un instante en instalar su receptor, y basta con que llegue el siguiente
  /// envío. Es preferible eso a ensuciar el reloj con avisos de transporte.
  ///
  /// Pero si los fallos se encadenan ya no es un tropiezo del arranque, sino
  /// que la ventana no está: el operador la habrá cerrado con su aspa. Es el
  /// segundo camino para enterarse, por si el aviso del plugin no llega.
  Future<void> push(CountdownSnapshot snapshot) async {
    final controller = _controller;
    final process = _process;

    if (process != null) {
      try {
        process.stdin.writeln(jsonEncode(snapshot.toJson()));
        await process.stdin.flush();
      } catch (_) {
        // El proceso ya no está; [Process.exitCode] se encarga del estado.
      }
      return;
    }

    if (controller == null) return;

    try {
      await controller.invokeMethod('update', snapshot.toJson());
      _pushFailures = 0;
    } catch (_) {
      if (++_pushFailures < _pushFailuresBeforeGone) return;

      _pushFailures = 0;
      // Mientras se esperaba la respuesta pudo cerrarse ya, y entonces manda
      // ese cierre: no se pisa.
      if (_controller != controller) return;

      _controller = null;
      _reset();
    }
  }

  /// Envíos fallidos seguidos que dan la ventana por perdida.
  ///
  /// Tres y no uno porque al abrir es normal fallar el primero: el motor del
  /// escenario todavía no ha instalado su receptor.
  static const int _pushFailuresBeforeGone = 3;

  Future<Rect?> _panelBounds() async {
    try {
      final position = await windowManager.getPosition();
      final size = await windowManager.getSize();
      return position & size;
    } catch (_) {
      return null;
    }
  }

  static Rect _centeredOn(Display? display, Size size) {
    final area = display == null
        ? Rect.fromLTWH(0, 0, size.width, size.height)
        : visibleRectOf(display);

    final width = size.width.clamp(0.0, area.width);
    final height = size.height.clamp(0.0, area.height);

    return Rect.fromLTWH(
      area.left + (area.width - width) / 2,
      area.top + (area.height - height) / 2,
      width,
      height,
    );
  }
}

final stageWindowProvider =
    NotifierProvider<StageWindowNotifier, StageWindowStatus>(
  StageWindowNotifier.new,
);

/// Aviso del escenario para el operador, de una vez.
///
/// Lo usa el escenario cuando algo cambia en la proyección sin que el operador
/// lo haya pedido —se ha desenchufado la pantalla del reloj—: la ventana se ha
/// movido sola y, si no se dice nada, parece un fallo.
class StageNoticeNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void show(String message) => state = message;
}

final stageNoticeProvider = NotifierProvider<StageNoticeNotifier, String?>(
  StageNoticeNotifier.new,
);
