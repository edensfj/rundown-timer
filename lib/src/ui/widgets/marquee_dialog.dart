import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/marquee.dart';
import '../../state/marquee_provider.dart';
import 'marquee_band.dart';

/// El diálogo de la marquesina: el chat de mensajes y sus ajustes.
///
/// Desde aquí se escribe un texto, se marca si va en bucle y se manda a la
/// pantalla. Abajo quedan los mensajes ya enviados, para copiarlos, editarlos
/// —el texto o el bucle—, reenviarlos o eliminarlos, y un botón para **cortar**
/// el que esté al aire, que devuelve el reloj a su tamaño.
class MarqueeDialog extends ConsumerStatefulWidget {
  const MarqueeDialog({super.key});

  static Future<void> show(BuildContext context) =>
      showDialog<void>(context: context, builder: (_) => const MarqueeDialog());

  @override
  ConsumerState<MarqueeDialog> createState() => _MarqueeDialogState();
}

class _MarqueeDialogState extends ConsumerState<MarqueeDialog> {
  final _controller = TextEditingController();
  bool _loop = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _enviar() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    ref.read(marqueePlaybackProvider.notifier).send(text, loop: _loop);
    _controller.clear();
    // Se queda abierto: enviar un mensaje no debería cerrar el chat.
    setState(() => _loop = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final active = ref.watch(marqueePlaybackProvider);
    final messages = ref.watch(marqueeMessagesProvider);

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 660),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
              child: Row(
                children: [
                  Icon(Icons.campaign_rounded, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Marquesina',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (active != null)
                    TextButton.icon(
                      onPressed: () =>
                          ref.read(marqueePlaybackProvider.notifier).stop(),
                      icon: const Icon(Icons.stop_circle_outlined, size: 18),
                      label: const Text('Detener'),
                      style: TextButton.styleFrom(
                        foregroundColor: scheme.error,
                      ),
                    ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Cerrar',
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _PreviewStrip(),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _controller,
                      autofocus: true,
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _enviar(),
                      decoration: const InputDecoration(
                        labelText: 'Mensaje',
                        hintText: 'Bienvenidos al culto de hoy…',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            value: _loop,
                            onChanged: (v) => setState(() => _loop = v),
                            title: const Text('Repetir en bucle'),
                            subtitle: Text(
                              _loop
                                  ? 'El texto se repite hasta que lo pares.'
                                  : 'El texto cruza una sola vez.',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _enviar,
                          icon: const Icon(Icons.send_rounded, size: 18),
                          label: const Text('Enviar'),
                        ),
                      ],
                    ),
                    const Divider(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Ajustes',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => ref
                              .read(marqueeSettingsProvider.notifier)
                              .set(const MarqueeSettings()),
                          child: const Text('Restablecer'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const _SettingsSliders(),
                    const Divider(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Mensajes enviados',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '${messages.length}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (messages.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Todavía no has enviado ningún mensaje.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    else
                      for (final message in messages)
                        _MessageTile(
                          message: message,
                          isActive: active?.messageId == message.id,
                        ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Recuadro de ejemplo: enseña cómo queda el texto con los ajustes actuales.
///
/// No es el escenario —eso lo manda el chat—, solo una muestra viva para ajustar
/// velocidad, tamaño, grosor y sentido sin tener que proyectar nada.
///
/// El recuadro **nunca cambia de tamaño**: cambia el modo (solo texto,
/// protagonista o bajo el reloj), el alto de la banda y con ella la letra, pero
/// la caja se queda igual. Si el recuadro creciera o se encogiera, el campo de
/// mensaje y los deslizadores de abajo se moverían mientras el operador los está
/// usando.
class _PreviewStrip extends ConsumerWidget {
  const _PreviewStrip();

  /// Alto fijo del recuadro, el mismo con cualquier ajuste.
  static const double _boxHeight = 200;

  /// Margen interior, para que la banda no se pegue al borde.
  static const double _inset = 10;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(marqueeSettingsProvider);
    const sample = 'MENSAJE DE EJEMPLO · ASÍ SE VERÁ';

    // Dentro del recuadro, la banda sí imita la proporción que tendrá en el
    // escenario. Lo único que cambia al mover un ajuste es el texto.
    final inner = _boxHeight - _inset * 2;
    final bandHeight = marqueeBandFractionFor(settings) * inner;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: _boxHeight,
        width: double.infinity,
        color: Colors.black,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: _inset),
        child: SizedBox(
          height: bandHeight,
          width: double.infinity,
          child: MarqueeBand(
            // Un id fijo: la muestra no se reinicia en cada ajuste; el estilo y
            // la velocidad se actualizan en vivo.
            overlay: MarqueeOverlay(
              runId: 'preview',
              messageId: 'preview',
              text: sample,
              settings: settings,
              duration: marqueeTravelTime(sample, settings),
              loop: true,
            ),
            fontSize: bandHeight * settings.fontScale,
          ),
        ),
      ),
    );
  }
}

/// Los cuatro ajustes de la banda, con deslizadores para lo continuo.
class _SettingsSliders extends ConsumerWidget {
  const _SettingsSliders();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(marqueeSettingsProvider);
    final notifier = ref.read(marqueeSettingsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: settings.showTimer,
          onChanged: (v) => notifier.set(settings.copyWith(showTimer: v)),
          title: const Text('Mostrar el reloj'),
          subtitle: Text(
            settings.showTimer
                ? 'El texto sale junto a la cuenta atrás o la hora.'
                : 'Sale solo el texto, a pantalla completa.',
          ),
        ),
        if (settings.showTimer)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: settings.prominent,
            onChanged: (v) => notifier.set(settings.copyWith(prominent: v)),
            title: const Text('El texto es el protagonista'),
            subtitle: Text(
              settings.prominent
                  ? 'El reloj se encoge arriba y el texto se ve grande.'
                  : 'El texto pasa por una franja fina bajo el reloj.',
            ),
          ),
        const SizedBox(height: 4),
        _SliderRow(
          label: 'Velocidad',
          value: settings.speed,
          min: 0.05,
          max: 1.0,
          divisions: 19,
          display: '${(settings.speed * 100).round()} %',
          onChanged: (v) =>
              notifier.set(settings.copyWith(speed: v), persist: false),
          onChangeEnd: notifier.commit,
        ),
        _SliderRow(
          label: 'Tamaño',
          value: settings.fontScale,
          min: 0.3,
          max: 1.0,
          divisions: 14,
          display: '${(settings.fontScale * 100).round()} %',
          onChanged: (v) =>
              notifier.set(settings.copyWith(fontScale: v), persist: false),
          onChangeEnd: notifier.commit,
        ),
        _SliderRow(
          label: 'Grosor',
          value: settings.fontWeight.toDouble(),
          min: 100,
          max: 900,
          divisions: 8,
          display: '${settings.fontWeight}',
          onChanged: (v) => notifier.set(
            settings.copyWith(fontWeight: v.round()),
            persist: false,
          ),
          onChangeEnd: notifier.commit,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const SizedBox(
              width: 92,
              child: Text('Dirección', style: TextStyle(fontSize: 13)),
            ),
            Expanded(
              child: DropdownButtonFormField<MarqueeDirection>(
                initialValue: settings.direction,
                isDense: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                items: [
                  for (final direction in MarqueeDirection.values)
                    DropdownMenuItem(
                      value: direction,
                      child: Text(direction.label),
                    ),
                ],
                onChanged: (direction) {
                  if (direction == null) return;
                  notifier.set(settings.copyWith(direction: direction));
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
    required this.onChangeEnd,
    this.divisions,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String display;
  final ValueChanged<double> onChanged;
  final VoidCallback onChangeEnd;
  final int? divisions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(label, style: const TextStyle(fontSize: 13)),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: display,
            onChanged: onChanged,
            onChangeEnd: (_) => onChangeEnd(),
          ),
        ),
        SizedBox(
          width: 52,
          child: Text(
            display,
            textAlign: TextAlign.end,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

/// Lo que devuelve el diálogo de edición: el texto nuevo y si se repite o no.
typedef _EditedMessage = ({String text, bool loop});

/// Una fila del chat: el texto y lo que se puede hacer con él.
///
/// Los botones van de menos a más destructivo: copiar, editar, reenviar y, al
/// final, borrar. Copiar confirma en el propio botón —el icono se vuelve un
/// visto— porque un SnackBar quedaría detrás de este diálogo.
class _MessageTile extends ConsumerStatefulWidget {
  const _MessageTile({required this.message, required this.isActive});

  final MarqueeMessage message;
  final bool isActive;

  @override
  ConsumerState<_MessageTile> createState() => _MessageTileState();
}

class _MessageTileState extends ConsumerState<_MessageTile> {
  /// Se enciende un momento al copiar, para que el botón lo confirme.
  bool _copiado = false;

  Future<void> _copiar() async {
    await Clipboard.setData(ClipboardData(text: widget.message.text));
    if (!mounted) return;
    setState(() => _copiado = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copiado = false);
  }

  Future<void> _editar() async {
    final edited = await showDialog<_EditedMessage>(
      context: context,
      builder: (_) => _EditMessageDialog(message: widget.message),
    );
    if (edited == null || !mounted) return;

    await ref
        .read(marqueeMessagesProvider.notifier)
        .update(widget.message.id, text: edited.text, loop: edited.loop);
    if (!mounted) return;

    // Si el mensaje editado está al aire, la pantalla lo refleja ya.
    if (ref.read(marqueePlaybackProvider)?.messageId == widget.message.id) {
      ref
          .read(marqueePlaybackProvider.notifier)
          .refresh(
            widget.message.copyWith(text: edited.text, loop: edited.loop),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final message = widget.message;
    final isActive = widget.isActive;

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: isActive
            ? Color.lerp(scheme.surface, scheme.primary, 0.10)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: isActive
            ? Border.all(color: scheme.primary)
            : Border.all(color: Colors.transparent),
      ),
      child: Row(
        children: [
          if (message.loop)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Tooltip(
                message: 'Se repite en bucle',
                child: Icon(
                  Icons.repeat_rounded,
                  size: 16,
                  color: scheme.primary,
                ),
              ),
            ),
          Expanded(
            child: Text(
              message.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          IconButton(
            onPressed: _copiar,
            tooltip: _copiado ? 'Copiado' : 'Copiar texto',
            color: _copiado ? scheme.primary : null,
            icon: Icon(
              _copiado ? Icons.check_rounded : Icons.copy_rounded,
              size: 20,
            ),
          ),
          IconButton(
            onPressed: _editar,
            tooltip: 'Editar mensaje',
            icon: const Icon(Icons.edit_outlined, size: 20),
          ),
          if (isActive)
            IconButton(
              onPressed: () =>
                  ref.read(marqueePlaybackProvider.notifier).stop(),
              tooltip: 'Detener',
              icon: const Icon(Icons.stop_circle_outlined, size: 20),
              color: scheme.error,
            )
          else
            IconButton(
              onPressed: () =>
                  ref.read(marqueePlaybackProvider.notifier).play(message),
              tooltip: 'Enviar de nuevo',
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
            ),
          IconButton(
            onPressed: () =>
                ref.read(marqueeMessagesProvider.notifier).remove(message.id),
            tooltip: 'Eliminar mensaje',
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            color: scheme.error,
          ),
        ],
      ),
    );
  }
}

/// Editar un mensaje ya enviado: el texto y si se repite o no.
///
/// Es el formulario de arriba en pequeño y con lo que ya hay puesto. El caso
/// típico es cambiar el bucle —un texto que se repetía y ya no debe, o al
/// revés— sin tener que volver a escribirlo entero.
class _EditMessageDialog extends StatefulWidget {
  const _EditMessageDialog({required this.message});

  final MarqueeMessage message;

  @override
  State<_EditMessageDialog> createState() => _EditMessageDialogState();
}

class _EditMessageDialogState extends State<_EditMessageDialog> {
  late final TextEditingController _controller;
  late bool _loop;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.message.text);
    _loop = widget.message.loop;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _guardar() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Navigator.of(context).pop((text: text, loop: _loop));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar mensaje'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _guardar(),
              decoration: const InputDecoration(
                labelText: 'Mensaje',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _loop,
              onChanged: (v) => setState(() => _loop = v),
              title: const Text('Repetir en bucle'),
              subtitle: Text(
                _loop
                    ? 'El texto se repite hasta que lo pares.'
                    : 'El texto cruza una sola vez.',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }
}
