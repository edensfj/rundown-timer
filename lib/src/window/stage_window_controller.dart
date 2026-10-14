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

/// Si el escenario está proyectándose y, si algo falló, por qué.
@immutable
class StageWindowStatus {
  const StageWindowStatus({this.isOpen = false, this.error});

  final bool isOpen;

  /// Mensaje del último intento fallido de abrir la ventana.
  final String? error;

  bool get hasError => error != null;
}

/// Controla la **segunda ventana**, la del escenario.
///
/// El panel ya no se convierte en escenario: crea una ventana aparte y se queda
/// donde está, para poder seguir programando mientras el reloj se proyecta.
class StageWindowNotifier extends Notifier<StageWindowStatus> {
  WindowController? _controller;

  @override
  StageWindowStatus build() {
    // El escenario es un espejo del panel: cada vez que cambia lo que hay que
    // mostrar se le manda. Va aquí y no en la UI para que no se pueda olvidar
    // en algún camino.
    ref.listen(countdownProvider, (_, next) => push(next));

    return const StageWindowStatus();
  }

  /// Abre la ventana del escenario en la pantalla que corresponda.
  ///
  /// Si no hay a dónde proyectar (una sola pantalla) se abre igualmente, en
  /// ventana: nunca se queda sin reloj.
  Future<void> open() async {
    if (_controller != null) return;

    try {
      final displays = await ref.read(displaysProvider.future);
      final panel = await _panelBounds();

      final target = chooseStageDisplay(
        displays: displays,
        selectedId: ref.read(selectedDisplayProvider),
        panelBounds: panel,
      );

      final frame = target == null
          // Sin pantalla elegida: se centra un lienzo de proyector en la
          // pantalla donde está el panel, para poder ver las dos cosas.
          ? _centeredOn(
              displayContaining(displays, panel) ?? displays.firstOrNull,
              AppConfig.stageWindowSize,
            )
          : visibleRectOf(target);

      final controller = await WindowController.create(
        WindowConfiguration(
          arguments: StageWindowArgs(
            x: frame.left,
            y: frame.top,
            width: frame.width,
            height: frame.height,
            fullscreen: target != null,
          ).encode(),
        ),
      );

      _controller = controller;
      state = const StageWindowStatus(isOpen: true);

      // Primer envío inmediato para que no se vea un reloj vacío al abrir.
      await push(ref.read(countdownProvider));
    } catch (error) {
      _controller = null;
      state = StageWindowStatus(error: '$error');
    }
  }

  /// Cierra la ventana del escenario, si está abierta.
  Future<void> close() async {
    final controller = _controller;
    _controller = null;
    state = const StageWindowStatus();

    if (controller == null) return;
    try {
      await controller.invokeMethod('close');
    } catch (_) {
      // Si el motor del escenario ya no está, no hay nada que cerrar.
    }
  }

  Future<void> toggle() => state.isOpen ? close() : open();

  /// Manda al escenario lo que tiene que pintar.
  ///
  /// Los fallos se ignoran a propósito: al abrir, el motor del escenario tarda
  /// un instante en instalar su receptor, y basta con que llegue el siguiente
  /// envío. Es preferible eso a ensuciar el reloj con avisos de transporte.
  Future<void> push(CountdownSnapshot snapshot) async {
    final controller = _controller;
    if (controller == null) return;

    try {
      await controller.invokeMethod('update', snapshot.toJson());
    } catch (_) {
      // Ver arriba: se reintenta solo un segundo después.
    }
  }

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
