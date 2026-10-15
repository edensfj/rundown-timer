import 'dart:ui' show FontWeight;

import 'package:flutter/foundation.dart';

import '../core/app_config.dart';

/// Hacia dónde corre el texto de la marquesina.
enum MarqueeDirection {
  /// Entra por la izquierda y sale por la derecha.
  leftToRight('Izquierda → derecha'),

  /// Entra por la derecha y sale por la izquierda.
  rightToLeft('Derecha → izquierda');

  const MarqueeDirection(this.label);

  final String label;
}

/// Ajustes de la marquesina: lo que el operador toca en el diálogo.
///
/// El **tipo de letra** no se elige: es el mismo condensado del reloj
/// (`AppConfig.countdownFontFamily`), para que la banda y los dígitos parezcan
/// de la misma familia. Los demás valores sí son suyos.
@immutable
class MarqueeSettings {
  const MarqueeSettings({
    this.speed = 0.25,
    this.fontScale = 0.9,
    this.fontWeight = 900,
    this.direction = MarqueeDirection.rightToLeft,
    this.prominent = true,
    this.showTimer = true,
  });

  /// Velocidad, medida en **alturas de pantalla por segundo**. Expresarla así
  /// —y no en píxeles— la hace independiente de la resolución: en un proyector
  /// 720p y en uno 1080p el texto tarda lo mismo en cruzar.
  final double speed;

  /// Alto de la letra como fracción del alto de la **banda**. Por defecto casi
  /// la llena entera: el mensaje debe verse tan grande como el reloj.
  final double fontScale;

  /// Grosor de la letra, 100–900 como en CSS.
  final int fontWeight;

  final MarqueeDirection direction;

  /// `true` si el texto toma el protagonismo: el reloj se encoge arriba y la
  /// banda ocupa casi media pantalla. `false` lo deja pasar por una franja fina
  /// bajo el reloj, sin quitarle sitio.
  final bool prominent;

  /// `true` si el reloj (cuenta atrás o hora) sigue viéndose encima del texto.
  /// `false` deja **solo el texto**, a pantalla completa.
  final bool showTimer;

  /// El grosor como valor de Flutter (`w100`…`w900`).
  FontWeight get weight {
    final index = (fontWeight ~/ 100 - 1).clamp(
      0,
      FontWeight.values.length - 1,
    );
    return FontWeight.values[index];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarqueeSettings &&
          other.speed == speed &&
          other.fontScale == fontScale &&
          other.fontWeight == fontWeight &&
          other.direction == direction &&
          other.prominent == prominent &&
          other.showTimer == showTimer;

  @override
  int get hashCode => Object.hash(
    speed,
    fontScale,
    fontWeight,
    direction,
    prominent,
    showTimer,
  );

  MarqueeSettings copyWith({
    double? speed,
    double? fontScale,
    int? fontWeight,
    MarqueeDirection? direction,
    bool? prominent,
    bool? showTimer,
  }) {
    return MarqueeSettings(
      speed: speed ?? this.speed,
      fontScale: fontScale ?? this.fontScale,
      fontWeight: fontWeight ?? this.fontWeight,
      direction: direction ?? this.direction,
      prominent: prominent ?? this.prominent,
      showTimer: showTimer ?? this.showTimer,
    );
  }

  Map<String, dynamic> toJson() => {
    'speed': speed,
    'fontScale': fontScale,
    'fontWeight': fontWeight,
    'direction': direction.name,
    'prominent': prominent,
    'showTimer': showTimer,
  };

  factory MarqueeSettings.fromJson(Map<dynamic, dynamic> json) {
    return MarqueeSettings(
      speed: _asDouble(json['speed']) ?? 0.25,
      fontScale: _asDouble(json['fontScale']) ?? 0.9,
      fontWeight: _asInt(json['fontWeight']) ?? 900,
      direction: _readDirection(json['direction']),
      prominent: json['prominent'] as bool? ?? true,
      showTimer: json['showTimer'] as bool? ?? true,
    );
  }

  // Un dato corrupto no puede tumbar la app en mitad de un evento: se ignora y
  // se usa el valor de fábrica.
  static double? _asDouble(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value');

  static int? _asInt(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value');

  static MarqueeDirection _readDirection(Object? value) {
    for (final direction in MarqueeDirection.values) {
      if (direction.name == value) return direction;
    }
    return MarqueeDirection.rightToLeft;
  }
}

/// Un mensaje del chat de la marquesina. Se conserva para poder reenviarlo.
@immutable
class MarqueeMessage {
  const MarqueeMessage({
    required this.id,
    required this.text,
    required this.createdAt,
    this.loop = false,
  });

  final String id;
  final String text;
  final DateTime createdAt;

  /// `true` si el texto se repite sin parar hasta que se pare a mano.
  final bool loop;

  MarqueeMessage copyWith({String? text, bool? loop}) => MarqueeMessage(
    id: id,
    text: text ?? this.text,
    createdAt: createdAt,
    loop: loop ?? this.loop,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    'loop': loop,
  };

  factory MarqueeMessage.fromJson(Map<dynamic, dynamic> json) => MarqueeMessage(
    id: (json['id'] as String?) ?? '',
    text: (json['text'] as String?) ?? '',
    createdAt:
        DateTime.tryParse('${json['createdAt']}') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    loop: json['loop'] as bool? ?? false,
  );
}

/// Lo que hay que pintar en la banda de la marquesina **ahora mismo**.
///
/// Es la pieza que viaja dentro de la instantánea, igual que el modo reloj: así
/// llega a la segunda ventana de Windows y al proceso aparte de Linux por el
/// canal de siempre, sin abrir uno nuevo.
@immutable
class MarqueeOverlay {
  const MarqueeOverlay({
    required this.runId,
    required this.messageId,
    required this.text,
    required this.settings,
    required this.duration,
    this.loop = false,
  });

  /// Distingue cada pase del texto. Reenviar el mismo mensaje cambia este id,
  /// y con él la animación del escenario vuelve a empezar en vez de quedarse
  /// parada al final.
  final String runId;

  /// Mensaje del que sale, para poder pararlo desde el chat.
  final String messageId;

  final String text;

  /// Ajustes con los que se está pintando **ahora mismo**, no los del momento
  /// del envío: si el operador toca un deslizador con el texto al aire, el panel
  /// los actualiza aquí y el escenario los aplica en el acto.
  final MarqueeSettings settings;

  /// Cuánto tarda el texto en cruzar entero. Lo calcula el panel y lo obedece
  /// el escenario, que no conoce la pantalla del otro lado.
  final Duration duration;

  /// `true` si el pase se repite sin parar y solo lo corta el operador.
  final bool loop;

  /// Cambia los ajustes del pase sin cambiar de pase: es el mismo mensaje
  /// cruzando la pantalla, con otra velocidad, otro tamaño u otro grosor.
  MarqueeOverlay copyWith({MarqueeSettings? settings, Duration? duration}) =>
      MarqueeOverlay(
        runId: runId,
        messageId: messageId,
        text: text,
        settings: settings ?? this.settings,
        duration: duration ?? this.duration,
        loop: loop,
      );

  /// Compara el pase entero, ajustes y duración incluidos. Si solo se mirara el
  /// `runId`, un cambio de ajustes no parecería un cambio y el escenario —que
  /// recibe la instantánea— no se enteraría de que hay algo nuevo que pintar.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarqueeOverlay &&
          other.runId == runId &&
          other.messageId == messageId &&
          other.text == text &&
          other.settings == settings &&
          other.duration == duration &&
          other.loop == loop;

  @override
  int get hashCode =>
      Object.hash(runId, messageId, text, settings, duration, loop);

  Map<String, dynamic> toJson() => {
    'runId': runId,
    'messageId': messageId,
    'text': text,
    'settings': settings.toJson(),
    'durationMs': duration.inMilliseconds,
    'loop': loop,
  };

  factory MarqueeOverlay.fromJson(Map<dynamic, dynamic> json) => MarqueeOverlay(
    runId: '${json['runId']}',
    messageId: '${json['messageId']}',
    text: '${json['text']}',
    settings: MarqueeSettings.fromJson(
      (json['settings'] as Map?)?.cast<dynamic, dynamic>() ?? const {},
    ),
    duration: Duration(
      milliseconds: json['durationMs'] is num
          ? (json['durationMs'] as num).toInt()
          : 0,
    ),
    loop: json['loop'] as bool? ?? false,
  );
}

/// Ratio de avance medio por unidad de tamaño para una fuente condensada como
/// Oswald. Sirve para estimar el ancho del texto sin medirlo con el motor.
const double _averageGlyphRatio = 0.42;

/// Fracción del alto de pantalla que ocupa la banda de la marquesina según los
/// ajustes: pantalla completa si solo se muestra el texto, casi media si es el
/// protagonista, o una franja fina si va bajo el reloj.
double marqueeBandFractionFor(MarqueeSettings settings) {
  if (!settings.showTimer) return 1;
  return settings.prominent
      ? AppConfig.marqueeProminentBandFraction
      : AppConfig.marqueeBandFraction;
}

/// Cuánto tarda [text] en cruzar la pantalla con [settings].
///
/// Todo se mide en **alturas de pantalla**, de modo que el resultado no depende
/// de la resolución: el escenario de 720p y el de 1080p tardan igual. La
/// proporción 16/9 es la del lienzo de proyector que usa la app.
Duration marqueeTravelTime(String text, MarqueeSettings settings) {
  const nominalAspectRatio = 16 / 9;
  final characters = text.trim().isEmpty ? 1 : text.trim().runes.length;

  // El texto vive dentro de la banda, así que su alto real es el de la banda
  // —que depende del modo elegido— por lo que ocupa dentro de ella.
  final band = marqueeBandFractionFor(settings);
  final letterHeights = band * settings.fontScale * characters;
  final textWidth = letterHeights * _averageGlyphRatio;
  final travel = nominalAspectRatio + textWidth;

  final seconds = travel / settings.speed;
  return Duration(milliseconds: (seconds * 1000).round().clamp(1500, 60000));
}
