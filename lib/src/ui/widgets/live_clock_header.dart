import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time_formatters.dart';
import '../../state/clock_provider.dart';

/// Cabecera del dashboard con la fecha y la hora actual en vivo.
///
/// Se actualiza segundo a segundo a través de [clockProvider].
///
/// Solo hora y fecha: el nombre del día no se pone aquí porque justo debajo
/// están las fichas de los días, con el que está en marcha highlighted —decirlo
/// dos veces era ruido, y además podía contradecirse: aquí arriba salía el día
/// que se estaba viendo y el ⏸ marcaba el que estaba en el aire.
class LiveClockHeader extends ConsumerWidget {
  const LiveClockHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, scheme.tertiary, 0.55)!,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            TimeFormatters.timeWithSeconds(now),
            style: theme.textTheme.displaySmall?.copyWith(
              color: scheme.onPrimary,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            TimeFormatters.fullDate(now),
            style: theme.textTheme.titleMedium?.copyWith(
              color: scheme.onPrimary.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}
