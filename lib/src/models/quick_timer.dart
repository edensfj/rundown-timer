import 'package:flutter/foundation.dart';

/// Un contador suelto, **independiente del itinerario programado**.
///
/// Sirve para lo que no está en el cronograma: una cuenta atrás para un aviso,
/// un tiempo de descanso, un límite para una dinámica. Se configura en segundos
/// y arranca al instante.
///
/// No se persiste a propósito: un temporizador que sigue corriendo al reabrir la
/// app al día siguiente sería más confuso que útil.
@immutable
class QuickTimerConfig {
  const QuickTimerConfig({
    required this.id,
    required this.label,
    required this.duration,
    required this.startedAt,
  });

  final String id;

  /// Texto que se muestra en el escenario.
  final String label;

  /// Tiempo total pedido.
  final Duration duration;

  /// Momento en que se arrancó.
  final DateTime startedAt;

  DateTime get endsAt => startedAt.add(duration);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuickTimerConfig &&
          other.id == id &&
          other.label == label &&
          other.duration == duration &&
          other.startedAt == startedAt;

  @override
  int get hashCode => Object.hash(id, label, duration, startedAt);
}
