import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import '../data/rundown_repository.dart';

/// Pantallas conectadas al sistema (monitores, proyectores, pantallas de
/// escenario).
///
/// Se resuelve una sola vez y se refresca a mano con `ref.invalidate`, porque
/// las pantallas no se conectan en medio de un evento.
final displaysProvider = FutureProvider<List<Display>>((ref) async {
  return screenRetriever.getAllDisplays();
});

/// Pantalla elegida para mostrar el modo escenario.
///
/// La elección se hace **antes** de entrar al escenario (desde el dashboard) y
/// se persiste: al abrir el modo escenario la ventana se mueve sola a esa
/// pantalla. Si es `null`, el escenario se queda en la pantalla actual.
class SelectedDisplayNotifier extends Notifier<String?> {
  @override
  String? build() => ref.read(repositoryProvider).loadSelectedDisplayId();

  void select(String? displayId) {
    if (displayId == state) return;
    state = displayId;
    ref.read(repositoryProvider).saveSelectedDisplayId(displayId);
  }
}

final selectedDisplayProvider =
    NotifierProvider<SelectedDisplayNotifier, String?>(
  SelectedDisplayNotifier.new,
);

/// Resuelve la pantalla elegida, si sigue conectada.
final activeDisplayProvider = Provider<Display?>((ref) {
  final id = ref.watch(selectedDisplayProvider);
  if (id == null) return null;

  final displays = ref.watch(displaysProvider).value;
  if (displays == null) return null;

  for (final display in displays) {
    if (display.id == id) return display;
  }
  return null;
});

/// Mueve la ventana a la pantalla indicada y la deja en pantalla completa.
///
/// Primero se posiciona y dimensiona sobre la pantalla destino (el fullscreen
/// se aplica a la pantalla que contiene la ventana) y solo después se activa
/// el fullscreen.
Future<void> projectOntoDisplay(Display display) async {
  final position = display.visiblePosition ?? Offset.zero;
  final size = display.visibleSize ?? display.size;

  await windowManager.setPosition(position);
  await windowManager.setSize(size);

  final alreadyFullscreen = await windowManager.isFullScreen();
  if (!alreadyFullscreen) {
    await windowManager.setFullScreen(true);
  }
}

/// ¿Hay más de una pantalla? Decide si vale la pena mostrar el selector.
final hasMultipleDisplaysProvider = Provider<bool>((ref) {
  return (ref.watch(displaysProvider).value?.length ?? 0) > 1;
});
