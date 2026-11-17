import 'dart:async';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'carregando.dart';

class FilterField extends StatelessWidget {
  const FilterField({super.key, required this.child, this.width = 220});
  final Widget child;
  final double width;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => SizedBox(
      width: c.maxWidth < width || MediaQuery.sizeOf(context).width < 600
          ? c.maxWidth
          : width,
      child: child,
    ),
  );
}

class SearchField extends StatefulWidget {
  const SearchField({super.key, required this.hint, required this.onChanged});
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  Timer? _debounce;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    onChanged: (value) {
      setState(() {});
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), () {
        if (mounted) widget.onChanged(value);
      });
    },
    decoration: InputDecoration(
      hintText: widget.hint,
      prefixIcon: const Icon(Icons.search, size: 20),
      suffixIcon: _controller.text.isEmpty
          ? null
          : IconButton(
              tooltip: 'Limpar busca',
              onPressed: () {
                _debounce?.cancel();
                setState(_controller.clear);
                widget.onChanged('');
              },
              icon: const Icon(Icons.clear),
            ),
    ),
  );
}

class Dropdown<T> extends StatelessWidget {
  const Dropdown({
    super.key,
    required this.label,
    required this.value,
    required this.itens,
    required this.onChanged,
  });
  final String label;
  final T value;
  final Map<T, String> itens;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    key: ValueKey(value),
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [
      for (final e in itens.entries)
        DropdownMenuItem(value: e.key, child: Text(e.value)),
    ],
    onChanged: (v) => onChanged(v as T),
  );
}

// ===== Diálogos =====

/// Diálogo padrão para formulários e detalhes (substitui a mistura de
/// modais/offcanvas do front antigo).
Future<T?> showAppDialog<T>(
  BuildContext context, {
  required String titulo,
  required Widget Function(BuildContext context, StateSetter setState) builder,
  List<Widget> Function(BuildContext context, StateSetter setState)? acoes,
  double width = 560,
}) {
  return showDialog<T>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.sm, 0),
        title: Row(
          children: [
            Expanded(
              child: Text(titulo, style: Theme.of(ctx).textTheme.titleLarge),
            ),
            IconButton(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.close),
              tooltip: 'Fechar',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              iconSize: 28,
            ),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(
          Gap.lg,
          Gap.md,
          Gap.lg,
          Gap.sm,
        ),
        content: SizedBox(
          width: width,
          child: SingleChildScrollView(child: builder(ctx, setState)),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          Gap.lg,
          Gap.sm,
          Gap.lg,
          Gap.lg,
        ),
        actions: acoes?.call(ctx, setState),
      ),
    ),
  );
}

/// Botão primário que mostra spinner enquanto a ação assíncrona roda.
class BusyButton extends StatelessWidget {
  const BusyButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
    this.icon,
    this.busyLabel,
  });
  final String label;

  /// Texto enquanto ocupado (ex.: "Entrando"), com reticências animadas. Sem ele, mantém [label].
  final String? busyLabel;
  final bool busy;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: busy ? null : onPressed,
    icon: busy
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Icon(icon ?? Icons.check, size: 18),
    label: busy && busyLabel != null
        ? TextoCarregando(busyLabel!)
        : Text(label),
  );
}

/// Rótulo de campo OPCIONAL: o nome do campo com uma etiqueta discreta "opcional".
/// Uso: `InputDecoration(label: const RotuloOpcional('E-mail'))`. Campos obrigatórios usam " *".
class RotuloOpcional extends StatelessWidget {
  const RotuloOpcional(this.texto, {super.key});
  final String texto;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      // Em campos estreitos (celular), o nome encolhe com reticências; a etiqueta fica inteira.
      Flexible(
        child: Text(texto, overflow: TextOverflow.ellipsis, maxLines: 1),
      ),
      const SizedBox(width: Gap.xs + 2),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: AppColors.muted.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Text(
          'opcional',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.muted,
          ),
        ),
      ),
    ],
  );
}

/// Legenda no topo dos formulários: explica o "*".
class LegendaObrigatorios extends StatelessWidget {
  const LegendaObrigatorios({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Gap.sm),
    child: Text(
      '* Campos obrigatórios',
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
    ),
  );
}

class FormSection extends StatelessWidget {
  const FormSection(this.titulo, {super.key});
  final String titulo;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Gap.sm, bottom: Gap.sm),
    child: Text(
      titulo.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        letterSpacing: .6,
        fontWeight: FontWeight.w600,
        color: AppColors.muted,
      ),
    ),
  );
}

// ===== Tabela =====

/// Tabela padrão com rolagem horizontal em telas estreitas.
