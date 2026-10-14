import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_retriever/screen_retriever.dart';

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
/// La elección se hace **antes** de abrir el escenario (desde el panel). Si es
/// `null`, la ventana del escenario se abre en la pantalla del panel.
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

  // Un id vacío no identifica ninguna pantalla: hay plataformas (Linux) donde
  // el plugin no da identificador, y darlo por bueno hacía que el selector
  // mostrara una selección que el operador nunca hizo.
  if (id == null || id.isEmpty) return null;

  final displays = ref.watch(displaysProvider).value;
  if (displays == null) return null;

  for (final display in displays) {
    if (display.id == id) return display;
  }
  return null;
});

/// ¿Hay más de una pantalla? Decide si vale la pena mostrar el selector.
final hasMultipleDisplaysProvider = Provider<bool>((ref) {
  return (ref.watch(displaysProvider).value?.length ?? 0) > 1;
});

/// Rectángulo utilizable de una pantalla, sin la barra de tareas, en píxeles
/// lógicos (que es lo que espera `window_manager`).
Rect visibleRectOf(Display display) {
  final origin = display.visiblePosition ?? Offset.zero;
  final size = display.visibleSize ?? display.size;
  return Rect.fromLTWH(origin.dx, origin.dy, size.width, size.height);
}

/// La pantalla en la que está el panel, si [bounds] cae dentro de alguna.
Display? displayContaining(List<Display> displays, Rect? bounds) {
  if (bounds == null) return null;

  for (final display in displays) {
    if (visibleRectOf(display).contains(bounds.center)) return display;
  }
  return null;
}

/// Decide en qué pantalla se abre el escenario.
///
/// El orden de preferencia es:
/// 1. La pantalla elegida a mano en el selector, si sigue conectada.
/// 2. Si hay más de una y no se eligió ninguna, **la que no está ocupando el
///    panel**. Al conectar un proyector lo esperable es que el escenario salga
///    en la otra pantalla sin tener que configurar nada.
/// 3. Con una sola pantalla devuelve `null` y el escenario se abre en una
///    ventana sobre la pantalla del panel.
///
/// Está aparte de los providers para poder probarla con listas de pantallas
/// inventadas, que es justo lo que no se puede reproducir a mano en un equipo
/// con un solo monitor.
Display? chooseStageDisplay({
  required List<Display> displays,
  required String? selectedId,
  Rect? panelBounds,
}) {
  if (displays.isEmpty) return null;

  // Con una sola pantalla no hay a dónde proyectar: el escenario se abre en
  // ventana para poder seguir programando. Da igual lo que diga el selector,
  // porque no existe una segunda pantalla donde ponerlo.
  if (displays.length < 2) return null;

  // La elegida a mano manda, si sigue conectada. Se ignora un id vacío: hay
  // plataformas donde el plugin no da identificador y un "" no identifica
  // ninguna pantalla en concreto.
  if (selectedId != null && selectedId.isNotEmpty) {
    for (final display in displays) {
      if (display.id == selectedId) return display;
    }
  }

  // La que no está ocupando el panel.
  final delPanel = displayContaining(displays, panelBounds);
  if (delPanel != null) {
    final otras = displays
        .where((display) => display.id != delPanel.id)
        .toList(growable: false);
    if (otras.isNotEmpty) return otras.first;
  }

  // Si no se pudo situar el panel, se evita la principal: el proyector suele
  // ser la secundaria.
  return displays.firstWhere(
    (display) => (display.visiblePosition ?? Offset.zero) != Offset.zero,
    orElse: () => displays.last,
  );
}
