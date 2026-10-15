import 'dart:convert';
import 'dart:io';

import '../models/run_show_state.dart';
import '../state/run_show_provider.dart';

/// Lo que el escenario puede pedirle al panel.
///
/// El escenario es una pantalla **muda**: pinta la instantánea que le llega, pero
/// no decide nada. Sus botones —pausa, siguiente, detener, +1 min— tenían que
/// viajar al panel por el canal inverso, porque es el panel quien tiene el
/// estado. Sin esto, en la pantalla del proyector los botones no hacían nada.
///
/// El canal es el mismo que usan las órdenes de ventana: en Linux, una línea
/// JSON por su salida estándar; en Windows y macOS, el canal del plugin.
class StageRunCommand {
  const StageRunCommand(this.action, {this.index, this.delta});

  final StageRunAction action;

  /// Actividad a la que saltar, cuando la orden lleva índice.
  final int? index;

  /// Minutos a sumar o restar, en las órdenes de tiempo.
  final Duration? delta;

  static const String channelKey = 'run';

  Map<String, dynamic> toJson() => {
    'cmd': channelKey,
    'action': action.name,
    if (index != null) 'index': index,
    if (delta != null) 'deltaMs': delta!.inMilliseconds,
  };

  String encode() => jsonEncode(toJson());

  /// Lee una orden válida, o `null` si la línea es otra cosa (un aviso del
  /// escenario, por ejemplo).
  static StageRunCommand? tryDecode(String line) {
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map) return null;
      final map = decoded.cast<String, dynamic>();
      if (map['cmd'] != channelKey) return null;

      final name = map['action'];
      final action = StageRunAction.values
          .where((a) => a.name == name)
          .cast<StageRunAction?>()
          .firstWhere((a) => true, orElse: () => null);
      if (action == null) return null;

      final ms = map['deltaMs'];
      return StageRunCommand(
        action,
        index: map['index'] is int ? map['index'] as int : null,
        delta: ms is int ? Duration(milliseconds: ms) : null,
      );
    } catch (_) {
      return null;
    }
  }

  /// Obedece la orden sobre el estado de verdad, que está en el panel.
  ///
  /// [eventIsFinished] lo lee quien la aplica: el estado del reloj es interno
  /// al notifier y desde aquí no se puede mirar.
  void applyTo(RunShowNotifier run, {required bool eventIsFinished}) {
    switch (action) {
      case StageRunAction.next:
        run.goToNext();
      case StageRunAction.previous:
        run.goToPrevious();
      case StageRunAction.restart:
        run.restart();
      case StageRunAction.togglePause:
        run.togglePause();
      case StageRunAction.toggleStop:
        run.toggleStop();
      case StageRunAction.sync:
        run.syncWithClock();
      case StageRunAction.toggleFinished:
        if (eventIsFinished) {
          run.resumeEvent();
        } else {
          run.finishEvent();
        }
      case StageRunAction.run:
        final target = index;
        if (target != null) run.runActivity(target);
      case StageRunAction.addTime:
        final amount = delta;
        if (amount != null) run.addTime(amount);
    }
  }
}

enum StageRunAction {
  next,
  previous,
  restart,
  togglePause,
  toggleStop,
  sync,
  toggleFinished,
  run,
  addTime,
}

/// Cómo sale una orden del escenario. Lo fija el arranque según la plataforma:
/// la tubería de salida en Linux, el canal del plugin en Windows y macOS.
StageRunCommandSender? stageRunSender;

/// Se usa cuando el escenario va en su propio proceso: una línea JSON por la
/// salida estándar, que el panel ya lee.
void sendStageRunCommandByStdout(StageRunCommand command) {
  stdout.writeln(command.encode());
}

typedef StageRunCommandSender = void Function(StageRunCommand command);

/// El reloj del escenario, pero sin estado: cada botón manda su orden al panel
/// y espera a que le llegue la instantánea nueva.
///
/// Sustituye a [runShowProvider] dentro del escenario. Sin esto, el escenario
/// escribía en un reloj propio que no pinta nada y sus botones parecían
/// averiados.
class StageRunBridge extends RunShowNotifier {
  @override
  RunShowState build() => const RunShowState(sourceId: 'stage-bridge');

  void _send(StageRunAction action, {int? index, Duration? delta}) {
    final sender = stageRunSender ?? sendStageRunCommandByStdout;
    sender(StageRunCommand(action, index: index, delta: delta));
  }

  @override
  void goToNext() => _send(StageRunAction.next);

  @override
  void goToPrevious() => _send(StageRunAction.previous);

  @override
  void goToIndex(int index) => _send(StageRunAction.run, index: index);

  @override
  void runActivity(int index, {String? dayId}) =>
      _send(StageRunAction.run, index: index);

  @override
  void restart() => _send(StageRunAction.restart);

  @override
  void togglePause() => _send(StageRunAction.togglePause);

  @override
  void toggleStop() => _send(StageRunAction.toggleStop);

  @override
  void syncWithClock() => _send(StageRunAction.sync);

  @override
  void finishEvent() => _send(StageRunAction.toggleFinished);

  @override
  void resumeEvent() => _send(StageRunAction.toggleFinished);

  @override
  void addTime(Duration delta) => _send(StageRunAction.addTime, delta: delta);
}
