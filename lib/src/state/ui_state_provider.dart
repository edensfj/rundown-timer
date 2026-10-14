import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ¿Está visible la vista previa del escenario en el programador?
///
/// Arranca visible: el operador ve desde el primer momento lo que se proyecta.
class PreviewVisibleNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

final previewVisibleProvider =
    NotifierProvider<PreviewVisibleNotifier, bool>(PreviewVisibleNotifier.new);
