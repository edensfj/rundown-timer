import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/quick_timer_provider.dart';

/// Diálogo para lanzar un contador suelto, fuera del itinerario programado.
///
/// Devuelve `true` si el usuario arrancó un contador.
class QuickTimerDialog extends ConsumerStatefulWidget {
  const QuickTimerDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    final started = await showDialog<bool>(
      context: context,
      builder: (_) => const QuickTimerDialog(),
    );
    return started ?? false;
  }

  @override
  ConsumerState<QuickTimerDialog> createState() => _QuickTimerDialogState();
}

class _QuickTimerDialogState extends ConsumerState<QuickTimerDialog> {
  /// Presets pensados para lo que de verdad se improvisa en un evento.
  static const List<Duration> _presets = [
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 5),
    Duration(minutes: 10),
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(minutes: 45),
    Duration(hours: 1),
  ];

  final _horas = TextEditingController();
  final _minutos = TextEditingController();
  final _etiqueta = TextEditingController();

  Duration? _seleccion;

  @override
  void dispose() {
    _horas.dispose();
    _minutos.dispose();
    _etiqueta.dispose();
    super.dispose();
  }

  /// Duración efectiva: lo personalizado manda sobre el preset elegido.
  Duration get _duracion {
    final h = int.tryParse(_horas.text.trim()) ?? 0;
    final m = int.tryParse(_minutos.text.trim()) ?? 0;
    final personalizado = Duration(hours: h, minutes: m);

    if (personalizado > Duration.zero) return personalizado;
    return _seleccion ?? Duration.zero;
  }

  bool get _valido {
    final d = _duracion;
    return d >= kQuickTimerMin && d <= kQuickTimerMax;
  }

  void _usarPreset(Duration d) {
    setState(() {
      _seleccion = d;
      // Al elegir preset se limpia lo escrito, para que no haya dos verdades.
      _horas.clear();
      _minutos.clear();
    });
  }

  void _iniciar() {
    if (!_valido) return;
    ref.read(quickTimerProvider.notifier).start(
          duration: _duracion,
          label: _etiqueta.text,
        );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.timer_outlined),
          SizedBox(width: 10),
          Text('Contador rápido'),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Un conteo suelto, independiente del itinerario. Útil para un '
                'aviso, un descanso o una dinámica improvisada.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),

              Text('Elige un tiempo', style: theme.textTheme.titleSmall),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in _presets)
                    ChoiceChip(
                      label: Text(_etiquetaPreset(d)),
                      selected: _seleccion == d && _esPersonalizadoVacio,
                      onSelected: (_) => _usarPreset(d),
                    ),
                ],
              ),

              const SizedBox(height: 22),
              Text('O escríbelo', style: theme.textTheme.titleSmall),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _horas,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Horas',
                        suffixText: 'h',
                      ),
                      onChanged: (_) => setState(() => _seleccion = null),
                      onSubmitted: (_) => _iniciar(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _minutos,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Minutos',
                        suffixText: 'min',
                      ),
                      onChanged: (_) => setState(() => _seleccion = null),
                      onSubmitted: (_) => _iniciar(),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              TextField(
                controller: _etiqueta,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Etiqueta (opcional)',
                  hintText: 'Receso, Aviso, Dinámica…',
                ),
                onSubmitted: (_) => _iniciar(),
              ),

              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: _valido
                      ? scheme.primaryContainer.withValues(alpha: 0.45)
                      : scheme.errorContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      _valido ? Icons.timer_outlined : Icons.error_outline_rounded,
                      size: 20,
                      color: _valido ? scheme.primary : scheme.error,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _valido
                            ? 'Contará ${_resumen(_duracion)} y avisará en rojo al llegar a cero.'
                            : 'Escribe un tiempo entre 1 segundo y 24 horas.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: _valido ? scheme.onSurface : scheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _valido ? _iniciar : null,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Iniciar'),
        ),
      ],
    );
  }

  bool get _esPersonalizadoVacio =>
      (_horas.text.trim().isEmpty && _minutos.text.trim().isEmpty);

  static String _etiquetaPreset(Duration d) {
    if (d.inMinutes < 60) return '${d.inMinutes} min';
    final h = d.inHours;
    return h == 1 ? '1 hora' : '$h h';
  }

  static String _resumen(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    final partes = [
      if (h > 0) '$h h',
      if (m > 0) '$m min',
      if (s > 0 && h == 0) '$s s',
    ];
    return partes.isEmpty ? 'un instante' : partes.join(' ');
  }
}
