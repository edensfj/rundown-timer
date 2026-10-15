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

  /// Cambia el texto o el bucle de un mensaje ya enviado.
  ///
  /// El caso típico es un texto que se repetía en bucle y ya no debe repetirse
  /// —o al revés—: se edita ahí mismo en vez de volver a escribirlo entero.
  Future<void> update(String id, {required String text, required bool loop}) =>
      _commit([
        for (final message in state)
          message.id == id
              ? message.copyWith(text: text.trim(), loop: loop)
              : message,
      ]);

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
///
/// Los ajustes se aplican **en vivo**: si el operador mueve un deslizador con un
/// texto ya cruzando, este cambia aquí mismo, sin tener que reenviarlo. Para eso
/// el pase guarda los ajustes que se están usando —no los del envío— y el
/// escenario los va reverdando en cada instantánea.
class MarqueePlaybackNotifier extends Notifier<MarqueeOverlay?> {
  Timer? _timer;

  /// Cuándo arrancó el pase en curso, para poder recalcular cuánto le queda.
  DateTime? _startedAt;

  @override
  MarqueeOverlay? build() {
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });

    ref.listen(
      marqueeSettingsProvider,
      (previous, next) => _applySettings(next),
    );
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

  /// Pone al día el pase al aire cuando su mensaje se edita en el chat.
  ///
  /// Cambiar **solo el bucle** no reinicia el texto: se quita o se reprograma su
  /// final sobre el recorrido que le queda, igual que al mover un deslizador.
  /// Cambiar el texto sí es un pase nuevo —lo que cruza la pantalla ya no es lo
  /// mismo— y vuelve a empezar desde el principio.
  void refresh(MarqueeMessage message) {
    final overlay = state;
    if (overlay == null || overlay.messageId != message.id) return;
    if (overlay.text == message.text && overlay.loop == message.loop) return;

    if (overlay.text != message.text) {
      play(message);
      return;
    }

    state = overlay.copyWith(loop: message.loop);

    _timer?.cancel();
    _timer = null;

    // En bucle no hay final que programar: sigue hasta que lo paren.
    if (message.loop) return;

    final total = overlay.duration.inMicroseconds;
    final elapsed = _startedAt == null
        ? 0
        : DateTime.now().difference(_startedAt!).inMicroseconds;
    final pending = total <= 0 ? 0.0 : (1 - elapsed / total).clamp(0.0, 1.0);

    _timer = Timer(
      Duration(
        milliseconds: (overlay.duration.inMilliseconds * pending).round(),
      ),
      () {
        if (!ref.mounted) return;
        state = null;
        _startedAt = null;
      },
    );
  }

  void _start(MarqueeMessage message, MarqueeSettings settings) {
    _timer?.cancel();
    _timer = null;
    _startedAt = DateTime.now();

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
      _startedAt = null;
    });
  }

  /// Manda los ajustes nuevos al pase que está al aire.
  ///
  /// El texto **no** se reinicia —el operador está moviendo un deslizador y un
  /// salto a pantalla completa cada vez que lo mueve sería insoportable—, solo
  /// se recalcula lo que tarda en cruzar y se reprograma el final del pase
  /// sobre el recorrido que le queda. Así acelerar el texto no lo corta por la
  /// mitad y frenarlo no le alarga la vida.
  void _applySettings(MarqueeSettings settings) {
    final overlay = state;
    if (overlay == null) return;

    final duration = marqueeTravelTime(overlay.text, settings);
    if (overlay.settings == settings && overlay.duration == duration) return;

    state = overlay.copyWith(settings: settings, duration: duration);

    // En bucle no hay final que programar: sigue hasta que lo paren.
    if (overlay.loop) return;

    _timer?.cancel();
    _timer = null;

    final total = overlay.duration.inMicroseconds;
    final elapsed = _startedAt == null
        ? 0
        : DateTime.now().difference(_startedAt!).inMicroseconds;
    final pending = total <= 0 ? 0.0 : (1 - elapsed / total).clamp(0.0, 1.0);

    _timer = Timer(
      Duration(milliseconds: (duration.inMilliseconds * pending).round()),
      () {
        if (!ref.mounted) return;
        state = null;
        _startedAt = null;
      },
    );
  }

  /// Quita el mensaje de la pantalla y deja el reloj como estaba.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _startedAt = null;
    if (state != null) state = null;
  }
}

final marqueePlaybackProvider =
    NotifierProvider<MarqueePlaybackNotifier, MarqueeOverlay?>(
      MarqueePlaybackNotifier.new,
    );
