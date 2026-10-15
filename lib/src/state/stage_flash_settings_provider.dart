import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/rundown_repository.dart';
import '../models/stage_flash_settings.dart';

/// Ajustes de los parpadeos del escenario, tal como los dejó el operador.
///
/// Se persisten, como los de la marquesina: lo que funciona en un proyector
/// —un aviso naranja a dos minutos, un verde de cinco segundos— se quiere igual
/// en el evento siguiente. Al vivir en un provider que observa
/// [countdownProvider], cada cambio viaja al escenario dentro de la instantánea.
class StageFlashSettingsNotifier extends Notifier<StageFlashSettings> {
  @override
  StageFlashSettings build() =>
      ref.read(repositoryProvider).loadFlashSettings();

  void set(StageFlashSettings settings, {bool persist = true}) {
    if (settings == state) return;
    state = settings;
    // Mientras se arrastra un deslizador se actualiza la vista sin escribir en
    // disco en cada píxel; [commit] guarda al soltar.
    if (persist) ref.read(repositoryProvider).saveFlashSettings(settings);
  }

  /// Guarda los ajustes actuales. Se llama al soltar un deslizador.
  void commit() => ref.read(repositoryProvider).saveFlashSettings(state);

  void update(StageFlashSettings Function(StageFlashSettings) change) =>
      set(change(state));

  /// Vuelve a los valores de fábrica.
  void reset() => set(const StageFlashSettings());
}

final stageFlashSettingsProvider =
    NotifierProvider<StageFlashSettingsNotifier, StageFlashSettings>(
      StageFlashSettingsNotifier.new,
    );
