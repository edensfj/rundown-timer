import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

/// Coloca la ventana en el rectángulo indicado y, si se pide, la deja a
/// pantalla completa.
///
/// **El orden importa y no es cosmético**: en Windows `window_manager` aplica
/// el fullscreen al monitor que *contiene* la ventana, así que hay que moverla
/// primero y activarlo después. Al revés, el escenario se quedaba en la
/// pantalla equivocada.
Future<void> placeWindow(Rect frame, {required bool fullscreen}) async {
  await windowManager.setPosition(frame.topLeft);
  await windowManager.setSize(frame.size);

  if (!fullscreen) return;

  // Si ya lo estuviera, volver a activarlo haría parpadear la ventana.
  final alreadyFullScreen = await windowManager.isFullScreen();
  if (!alreadyFullScreen) {
    await windowManager.setFullScreen(true);
  }
}
