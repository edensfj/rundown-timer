import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time_formatters.dart';
import '../../state/clock_provider.dart';

/// Cabecera del dashboard con la fecha y la hora actual en vivo.
///
/// Se actualiza segundo a segundo a través de [clockProvider].
class LiveClockHeader extends ConsumerWidget {
  const LiveClockHeader({super.key, required this.contextLabel});

  /// Texto secundario, por ejemplo el nombre del evento.
  final String? contextLabel;

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
          if (contextLabel != null) ...[
            Text(
              contextLabel!.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onPrimary.withValues(alpha: 0.85),
                letterSpacing: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
          ],
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
