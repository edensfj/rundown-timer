import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

/// Coloca la ventana en el rectángulo indicado y, si se pide, la deja a
/// pantalla completa.
///
/// **El orden importa y no es cosmético**: en Windows `window_manager` aplica
/// el fullscreen al monitor que *contiene* la ventana, así que hay que moverla
/// primero y activarlo después. Al revés, el escenario se quedaba en la
/// pantalla equivocada.
Future<void> placeWindow(Rect frame, {required bool fullscreen, bool force = false}) async {
  // El orden importa y no es cosmético: en Windows `window_manager` aplica
  // el fullscreen al monitor que *contiene* la ventana, así que hay que moverla
  // primero y activarlo después. Al revés, el escenario se quedaba en la
  // pantalla equivocada.
  await windowManager.setPosition(frame.topLeft);
  await windowManager.setSize(frame.size);

  if (!fullscreen) return;

  // `isFullScreen()` puede devolver un verdadero inesperado en una segunda
  // ventana, dejando la llamada a `setFullScreen(true)` por saltar. Con `force`,
  // tras mover la ventana, se prueba a activarlo de todos modos. El guard normal
  // se conserva para no volatizar una ventana que ya lo está a toda pantalla.
  if (!force) {
    final alreadyFullScreen = await windowManager.isFullScreen();
    if (alreadyFullScreen) return;
  }

  await windowManager.setFullScreen(true);
}
