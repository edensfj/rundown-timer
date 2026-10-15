import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ids.dart';
import '../data/rundown_repository.dart';
import '../models/marquee.dart';

/// Ajustes de la marquesina, tal como los dejó el operador.
///
/// A diferencia del modo reloj (que es de sesión), esto se persiste: la
/// velocidad y el grosor que funcionan en un proyector se quieren tal cual en el
/// siguiente evento.
class MarqueeSettingsNotifier extends Notifier<MarqueeSettings> {
  @override
  MarqueeSettings build() => ref.read(repositoryProvider).loadMarqueeSettings();

  void set(MarqueeSettings settings, {bool persist = true}) {
    if (settings == state) return;
    state = settings;
    // Mientras se arrastra un deslizador se actualiza la vista sin escribir en
    // disco en cada píxel; [commit] guarda al soltar.
    if (persist) ref.read(repositoryProvider).saveMarqueeSettings(settings);
  }

  /// Guarda los ajustes actuales. Se llama al soltar un deslizador.
  void commit() => ref.read(repositoryProvider).saveMarqueeSettings(state);

  void update(MarqueeSettings Function(MarqueeSettings) change) =>
      set(change(state));
}

final marqueeSettingsProvider =
    NotifierProvider<MarqueeSettingsNotifier, MarqueeSettings>(
      MarqueeSettingsNotifier.new,
    );

/// El chat de la marquesina: todo lo enviado, de lo más nuevo a lo más viejo.
class MarqueeMessagesNotifier extends Notifier<List<MarqueeMessage>> {
  @override
  List<MarqueeMessage> build() =>
      ref.read(repositoryProvider).loadMarqueeMessages();

  /// Guarda un mensaje nuevo al principio de la lista y lo devuelve, para poder
  /// enviarlo acto seguido.
  Future<MarqueeMessage> add(String text, {bool loop = false}) async {
    final message = MarqueeMessage(
      id: newId(),
      text: text.trim(),
      createdAt: DateTime.now(),
      loop: loop,
    );
    await _commit([message, ...state]);
    return message;
  }

  Future<void> remove(String id) =>
      _commit(state.where((m) => m.id != id).toList());

  Future<void> _commit(List<MarqueeMessage> messages) async {
    state = messages;
    await ref.read(repositoryProvider).saveMarqueeMessages(messages);
  }
}

final marqueeMessagesProvider =
    NotifierProvider<MarqueeMessagesNotifier, List<MarqueeMessage>>(
      MarqueeMessagesNotifier.new,
    );

/// Qué mensaje está cruzando la pantalla ahora mismo, si hay alguno.
///
/// El pase dura lo que tarda el texto en cruzar ([marqueeTravelTime]) y se
/// detiene solo. Se mide aquí y no en el escenario porque el escenario no
/// conoce la pantalla del otro lado: es el panel el que decide cuándo se acaba
/// y manda una instantánea sin mensaje, con lo que el reloj recupera su tamaño.
class MarqueePlaybackNotifier extends Notifier<MarqueeOverlay?> {
  Timer? _timer;

  @override
  MarqueeOverlay? build() {
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });
    return null;
  }

  /// Guarda [text] en el chat y lo lanza a la banda.
  Future<void> send(String text, {bool loop = false}) async {
    final clean = text.trim();
    if (clean.isEmpty) return;

    final message = await ref
        .read(marqueeMessagesProvider.notifier)
        .add(clean, loop: loop);
    play(message);
  }

  /// Repite un mensaje ya enviado. El pase es nuevo, así que la animación vuelve
  /// a empezar aunque el texto sea el mismo.
  void play(MarqueeMessage message) {
    final settings = ref.read(marqueeSettingsProvider);
    _start(message, settings);
  }

  void _start(MarqueeMessage message, MarqueeSettings settings) {
    _timer?.cancel();
    _timer = null;

    final duration = marqueeTravelTime(message.text, settings);
    state = MarqueeOverlay(
      runId: newId(),
      messageId: message.id,
      text: message.text,
      settings: settings,
      duration: duration,
      loop: message.loop,
    );

    // En bucle no hay final que programar: dura hasta que el operador lo corta.
    if (message.loop) return;

    _timer = Timer(duration, () {
      if (!ref.mounted) return;
      state = null;
    });
  }

  /// Quita el mensaje de la pantalla y deja el reloj como estaba.
  void stop() {
    _timer?.cancel();
    _timer = null;
    if (state != null) state = null;
  }
}

final marqueePlaybackProvider =
    NotifierProvider<MarqueePlaybackNotifier, MarqueeOverlay?>(
      MarqueePlaybackNotifier.new,
    );
