import 'package:flutter/material.dart';

import '../../core/time_formatters.dart';
import '../../models/countdown_phase.dart';
import '../../models/countdown_snapshot.dart';

/// Banner del pie de pantalla con la siguiente actividad.
///
/// Va deliberadamente discreto: el countdown manda, así que esto solo informa.
class NextActivityBanner extends StatelessWidget {
  const NextActivityBanner({super.key, required this.snapshot});

  final CountdownSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final next = snapshot.next;
    const muted = Color(0x99FFFFFF);

    if (next == null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.flag_outlined, color: muted, size: 18),
          const SizedBox(width: 8),
          Text(
            'Última actividad del día',
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
        ],
      );
    }

    final item = next.item;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'SIGUIENTE',
          style: theme.textTheme.labelSmall?.copyWith(
            color: const Color(0x66FFFFFF),
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          TimeFormatters.time(next.startTime),
          style: theme.textTheme.titleMedium?.copyWith(
            color: StageColors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(color: muted),
          ),
        ),
        if (item.location != null) ...[
          const SizedBox(width: 12),
          const Icon(Icons.place_outlined, size: 15, color: muted),
          const SizedBox(width: 4),
          Text(
            item.location!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0x80FFFFFF),
            ),
          ),
        ],
      ],
    );
  }
}
