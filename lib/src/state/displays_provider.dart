import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_retriever/screen_retriever.dart';

import '../data/rundown_repository.dart';

/// Cada cuánto se pregunta al sistema si han cambiado las pantallas.
///
/// Corto a propósito: enchufar o desenchufar un proyector es cosa de un segundo,
/// y el operador no puede estar esperando a un reinicio para verlo. Tampoco puede
/// muchísimo: mientras el escenario esté proyectando, de este intervalo depende
/// que la ventana del reloj vuelva a ser una ventana normal si la pantalla de la
/// TV se va a mitad de evento.
const Duration _displaysRefreshInterval = Duration(seconds: 5);

/// Pantallas conectadas al sistema (monitores, proyectores, pantallas de
/// escenario).
///
/// Se relee cada [\_displaysRefreshInterval] mientras alguien la esté mirando,
/// porque **las pantallas se conectan y desconectan mientras la app está
/// abierta**: con el listado congelado al arrancar, enchufar la TV a mitad de
/// un ensayo no aparecía hasta reiniciar, y el escenario se quedaba donde
/// estaba.
///
/// Releyéndola no se pierde lo que ya se estaba viendo: Riverpod conserva los
/// datos anteriores mientras refresca, así que la lista no parpadea.
final displaysProvider = FutureProvider<List<Display>>((ref) async {
  final timer = Timer.periodic(
    _displaysRefreshInterval,
    (_) => ref.invalidateSelf(),
  );
  ref.onDispose(timer.cancel);

  return screenRetriever.getAllDisplays();
});

/// Pantalla elegida para mostrar el modo escenario.
///
/// La elección se hace **antes** de abrir el escenario (desde el panel). Si es
/// `null`, la ventana del escenario se abre en la pantalla del panel.
///
/// Lo que se guarda no es el identificador del sistema, sino la clave de la
/// pantalla (ver [displayKeyOf]): en Linux no hay identificadores.
class SelectedDisplayNotifier extends Notifier<String?> {
  @override
  String? build() => ref.read(repositoryProvider).loadSelectedDisplayKey();

  void select(String? key) {
    if (key == state) return;
    state = key;
    ref.read(repositoryProvider).saveSelectedDisplayKey(key);
  }
}

final selectedDisplayProvider =
    NotifierProvider<SelectedDisplayNotifier, String?>(
      SelectedDisplayNotifier.new,
    );

/// Con qué se distingue una pantalla de otra.
///
/// Windows y macOS dan un identificador por pantalla y se usa tal cual, porque es
/// lo único que sobrevive a que el equipo cambie de plugged a projector.
///
/// En Linux `screen_retriever` devuelve **todas con el `id` vacío**. Con un id
/// vacío no hay forma de distinguir una pantalla de otra: la elección se
/// guardaba indistinguible, el diálogo no marcaba ninguna y al abrir el
/// escenario no se respetaba. Cuando falta el id se usa la posición y el tamaño,
/// que en una disposición de pantallas estable (la de un portátil con su TV, la
/// de una mesa de sonido con un proyector) distinguen una pantalla de otra.
String displayKeyOf(Display display) {
  final id = display.id.trim();
  if (id.isNotEmpty) return id;

  final position = display.visiblePosition ?? Offset.zero;
  final size = display.visibleSize ?? display.size;

  return '@${position.dx.toInt()},${position.dy.toInt()}'
      ' ${size.width.toInt()}x${size.height.toInt()}';
}

/// Las pantallas **de verdad** en este instante.
///
/// El provider se relee cada pocos segundos, y entre una lectura y la siguiente
/// el operador puede desconectar la TV y abrir el escenario. Con la lista cacheada
/// la app aún creía que había dos pantallas, así que abría el escenario a
/// pantalla completa en las coordenadas de la TV… y como esa pantalla ya no
/// estaba, el sistema lo dibujaba encima de la principal. Al abrir el escenario
/// no hay que esperar al refresco: se pregunta.
///
/// También refresca el provider, para que el panel y el diálogo enseñen la misma
/// lista que se acaba de usar para proyectar.
Future<List<Display>> readDisplaysNow(Ref ref) async {
  final displays = await screenRetriever.getAllDisplays();
  ref.invalidate(displaysProvider);
  return displays;
}

/// Resuelve la pantalla elegida, si sigue conectada.
final activeDisplayProvider = Provider<Display?>((ref) {
  // Una elección vacía nunca viene de una selección real: el diálogo guarda
  // siempre la clave de la pantalla.
  return displayByKey(
    ref.watch(displaysProvider).value ?? const [],
    ref.watch(selectedDisplayProvider),
  );
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

/// La pantalla [key] de la lista, o `null` si ya no está conectada.
///
/// Se compara con [displayKeyOf] y no con el id del sistema, porque en Linux no
/// hay: era justo lo que hacía que la elección se ignorase y el escenario no fuese
/// a pantalla completa en la pantalla elegida.
Display? displayByKey(List<Display> displays, String? key) {
  if (key == null || key.isEmpty) return null;

  for (final display in displays) {
    if (displayKeyOf(display) == key) return display;
  }
  return null;
}

/// Qué hay que hacer con la ventana del escenario cuando ha cambiado el reparto
/// de pantallas.
enum StageScreenChange {
  /// La pantalla del escenario sigue donde estaba: no se toca nada.
  none,

  /// La pantalla del escenario ha desaparecido: la ventana vuelve a ser normal.
  ///
  /// Sin esto, al desenchufar la TV el sistema **no devuelve la ventana a su
  /// sitio**: la recoloca sobre la pantalla que queda manteniendo el modo
  /// pantalla completa, y el reloj se queda encima del panel del operador, a
  /// pantalla completa y sin poder programarse al lado.
  toWindow,

  /// La pantalla del escenario ha vuelto: el reloj regresa a ella a pantalla
  /// completa, sin que el operador tenga que cerrar y reabrir el modo escenario
  /// en mitad del evento.
  toScreen,
}

/// Decide qué hay que hacer con la ventana del escenario ante un cambio en el
/// reparto de pantallas.
///
/// Parámetros:
/// - [displays]: las pantallas **de verdad** ahora mismo.
/// - [stageDisplayKey]: la pantalla donde se instaló el escenario, o `null` si se
///   abrió en una ventana normal sobre la del panel (entonces no hay ninguna
///   pantalla que pueda desaparecer).
/// - [wasFullScreen]: si el escenario llegó a ocupar una pantalla entera.
/// - [degradedByUs]: si la app fue quien lo bajó a ventana normal al perder la
///   pantalla. Solo en ese caso se le devuelve a pantalla completa si la pantalla
///   vuelve: si el operador lo abrió en ventana a propósito, que siga en ventana.
///
/// Está aparte de los providers para poder probarla con listas de pantallas
/// inventadas, que es justo lo que no se puede reproducir a mano en un equipo con
/// un solo monitor.
StageScreenChange stageScreenChangeFor({
  required List<Display> displays,
  required String? stageDisplayKey,
  required bool wasFullScreen,
  required bool degradedByUs,
}) {
  // El escenario se abrió en una ventana normal encima del panel: no hay
  // ninguna pantalla que pueda desaparecer, así que no hay nada que hacer.
  if (stageDisplayKey == null || stageDisplayKey.isEmpty) {
    return StageScreenChange.none;
  }

  final sigue = displayByKey(displays, stageDisplayKey) != null;

  // Se desconectó la TV o el proyector: ya no hay nada donde proyectar y la
  // ventana tiene que dejar de ser una pantalla completa.
  if (!sigue) {
    return wasFullScreen ? StageScreenChange.toWindow : StageScreenChange.none;
  }

  // La pantalla ha vuelto: se le devuelve el reloj, en pantalla completa.
  if (degradedByUs) return StageScreenChange.toScreen;

  return StageScreenChange.none;
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
  required String? selectedKey,
  Rect? panelBounds,
}) {
  if (displays.isEmpty) return null;

  // Con una sola pantalla no hay a dónde proyectar: el escenario se abre en
  // ventana para poder seguir programando. Da igual lo que diga el selector,
  // porque no existe una segunda pantalla donde ponerlo.
  if (displays.length < 2) return null;

  // La elegida a mano manda, si sigue conectada. Se compara con [displayKeyOf] y
  // no con el id del sistema, porque en Linux no hay: era justo lo que hacía que
  // la elección se ignorase y el escenario no fuese a pantalla completa en la
  // pantalla elegida.
  if (selectedKey != null && selectedKey.isNotEmpty) {
    for (final display in displays) {
      if (displayKeyOf(display) == selectedKey) return display;
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
