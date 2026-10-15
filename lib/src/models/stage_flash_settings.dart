import 'package:flutter/foundation.dart';

/// Ajustes de los efectos parpadeantes del escenario.
///
/// El escenario da tres avisos a pantalla completa: **verde** al cambiar de
/// actividad, **naranja** en los últimos instantes antes de acabar y **rojo**
/// cuando se pasa del tiempo. Aquí se decide si cada uno está encendido y, en
/// los dos primeros, con cuánta antelación o durante cuánto tiempo se encienden.
///
/// El rojo del tiempo excedido no tiene interruptor propio: cuando el aviso
/// maestro está encendido, **siempre** parpadea al acabarse el tiempo. Es el
/// aviso que no se puede echar en falta.
///
/// Viaja dentro de [CountdownSnapshot] para que llegue igual a la segunda
/// ventana (Windows y macOS) y al proceso aparte de Linux, que no comparten
/// memoria con el panel ni abren las cajas de Hive.
@immutable
class StageFlashSettings {
  const StageFlashSettings({
    this.enabled = true,
    this.changeEnabled = true,
    this.changeDuration = const Duration(seconds: 5),
    this.endingEnabled = true,
    this.endingWindow = const Duration(minutes: 2),
  });

  /// Interruptor maestro: apagado, el escenario no parpadea nunca.
  final bool enabled;

  /// `true` si el destello **verde** de cambio de actividad está activo.
  final bool changeEnabled;

  /// Cuánto dura el destello verde tras el cambio de actividad.
  final Duration changeDuration;

  /// `true` si el aviso **naranja** de fin inminente está activo.
  final bool endingEnabled;

  /// Con este tiempo o menos por delante, empieza el aviso naranja. Dos minutos
  /// de fábrica: tiempo de sobra para ir cerrando, sin dar el aviso tan pronto
  /// que se vuelva ruido de fondo.
  final Duration endingWindow;

  StageFlashSettings copyWith({
    bool? enabled,
    bool? changeEnabled,
    Duration? changeDuration,
    bool? endingEnabled,
    Duration? endingWindow,
  }) {
    return StageFlashSettings(
      enabled: enabled ?? this.enabled,
      changeEnabled: changeEnabled ?? this.changeEnabled,
      changeDuration: changeDuration ?? this.changeDuration,
      endingEnabled: endingEnabled ?? this.endingEnabled,
      endingWindow: endingWindow ?? this.endingWindow,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StageFlashSettings &&
          other.enabled == enabled &&
          other.changeEnabled == changeEnabled &&
          other.changeDuration == changeDuration &&
          other.endingEnabled == endingEnabled &&
          other.endingWindow == endingWindow;

  @override
  int get hashCode => Object.hash(
    enabled,
    changeEnabled,
    changeDuration,
    endingEnabled,
    endingWindow,
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'changeEnabled': changeEnabled,
    'changeMs': changeDuration.inMilliseconds,
    'endingEnabled': endingEnabled,
    'endingMs': endingWindow.inMilliseconds,
  };

  factory StageFlashSettings.fromJson(Map<dynamic, dynamic> json) {
    return StageFlashSettings(
      enabled: json['enabled'] as bool? ?? true,
      changeEnabled: json['changeEnabled'] as bool? ?? true,
      changeDuration: Duration(milliseconds: _asInt(json['changeMs']) ?? 5000),
      endingEnabled: json['endingEnabled'] as bool? ?? true,
      endingWindow: Duration(milliseconds: _asInt(json['endingMs']) ?? 120000),
    );
  }

  // Un dato corrupto no puede tumbar el reloj en mitad de un evento: se ignora y
  // se usa el valor de fábrica.
  static int? _asInt(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value');
}
