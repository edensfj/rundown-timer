import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Si el escenario está proyectándose y, si algo falló, por qué.
@immutable
class StageWindowStatus {
  const StageWindowStatus({
    this.isOpen = false,
    this.isEmbedded = false,
    this.error,
  });

  final bool isOpen;

  /// En web el escenario **siempre** se proyecta dentro de la misma pestaña:
  /// no hay ventanas nativas ni una segunda instancia de la app.
  final bool isEmbedded;

  /// Mensaje del último intento fallido de abrir la ventana.
  final String? error;

  bool get hasError => error != null;
}

/// En web no existe la segunda ventana de escritorio.
final stageSecondWindowProvider = Provider<bool>((ref) => false);

/// Controla el modo escenario en web.
///
/// Abrir el escenario sustituye el panel por la proyección dentro de la misma
/// pestaña; cerrarlo devuelve al panel. La vista previa lateral sigue siendo el
/// mismo [StageView] que se pone a pantalla completa.
class StageWindowNotifier extends Notifier<StageWindowStatus> {
  @override
  StageWindowStatus build() => const StageWindowStatus();

  Future<void> open() async {
    if (state.isOpen) return;
    state = const StageWindowStatus(isOpen: true, isEmbedded: true);
  }

  Future<void> close() async {
    if (!state.isOpen) return;
    state = const StageWindowStatus();
  }

  Future<void> toggle() => state.isOpen ? close() : open();
}

final stageWindowProvider =
    NotifierProvider<StageWindowNotifier, StageWindowStatus>(
      StageWindowNotifier.new,
    );

/// Aviso del escenario para el operador. En web no hay cambios de pantalla que
/// provoquen avisos automáticos, pero el panel escucha el mismo provider.
class StageNoticeNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void show(String message) => state = message;
}

final stageNoticeProvider = NotifierProvider<StageNoticeNotifier, String?>(
  StageNoticeNotifier.new,
);
