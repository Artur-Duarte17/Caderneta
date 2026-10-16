import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../core/notificacoes_service.dart';
import '../core/theme.dart';

// ===== Feedback =====

void toast(BuildContext context, String msg, {bool erro = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(erro ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white, size: 20),
        const SizedBox(width: Gap.sm),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: erro ? AppColors.danger : AppColors.success,
    ));
}

// ===== Carregamento assíncrono padronizado =====

/// Carrega dados, mostra loading/erro de forma uniforme e recarrega sozinho
/// quando outra parte do app altera dados (venda criada, pagamento etc.).
class AsyncView<T> extends StatefulWidget {
  const AsyncView({super.key, required this.load, required this.builder});

  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;

  @override
  State<AsyncView<T>> createState() => _AsyncViewState<T>();
}

class _AsyncViewState<T> extends State<AsyncView<T>> {
  T? _data;
  Object? _erro;
  bool _carregando = true;
  final _revisao = NotificacoesService.instance.revisao;

  @override
  void initState() {
    super.initState();
    _reload();
    _revisao.addListener(_reload);
  }

  @override
  void dispose() {
    _revisao.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    if (_data == null) setState(() => _carregando = true);
    try {
      final d = await widget.load();
      if (mounted) {
        setState(() {
          _data = d;
          _erro = null;
          _carregando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = e;
          _carregando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando && _data == null) return const LoadingState();
    if (_erro != null && _data == null) return ErrorState(mensagem: '$_erro', onRetry: _reload);
    return widget.builder(context, _data as T, _reload);
  }
}

class LoadingState extends StatelessWidget {
  const LoadingState({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: Padding(padding: EdgeInsets.all(Gap.xl), child: CircularProgressIndicator()));
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.mensagem, this.onRetry});
  final String mensagem;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.cloud_off,
        titulo: 'Não foi possível carregar os dados',
        mensagem: mensagem,
        acao: onRetry == null
            ? null
            : OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Tentar novamente')),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.titulo, this.mensagem, this.acao});
  final IconData icon;
  final String titulo;
  final String? mensagem;
  final Widget? acao;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Gap.xl * 1.5, horizontal: Gap.lg),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 48, color: AppColors.muted.withValues(alpha: .5)),
            const SizedBox(height: Gap.md),
            Text(titulo, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            if (mensagem != null) ...[
              const SizedBox(height: Gap.xs),
              Text(mensagem!, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
            ],
            if (acao != null) ...[const SizedBox(height: Gap.md), acao!],
          ]),
        ),
      );
}

// ===== Layout =====

class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.titulo, this.subtitulo, this.acoes = const []});
  final String titulo;
  final String? subtitulo;
  final List<Widget> acoes;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Gap.lg),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: Gap.md,
          spacing: Gap.md,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(titulo, style: Theme.of(context).textTheme.headlineSmall),
              if (subtitulo != null) ...[
                const SizedBox(height: Gap.xs),
                Text(subtitulo!, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 14)),
              ],
            ]),
            if (acoes.isNotEmpty) Wrap(spacing: Gap.sm, runSpacing: Gap.sm, children: acoes),
          ],
        ),
      );
}

/// Grade responsiva: distribui [children] em colunas de largura mínima
/// [minWidth]; os itens de uma mesma linha ficam com a mesma altura.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({super.key, required this.children, this.minWidth = 280, this.spacing = Gap.md});
  final List<Widget> children;
  final double minWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final cols = (c.maxWidth / minWidth).floor().clamp(1, 6);
        return Column(children: [
          for (var i = 0; i < children.length; i += cols) ...[
            if (i > 0) SizedBox(height: spacing),
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (var j = 0; j < cols; j++) ...[
                  if (j > 0) SizedBox(width: spacing),
                  Expanded(child: i + j < children.length ? children[i + j] : const SizedBox.shrink()),
                ],
              ]),
            ),
          ],
        ]);
      });
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.titulo, this.acao, required this.child, this.padding = const EdgeInsets.all(Gap.lg)});
  final String? titulo;
  final Widget? acao;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: padding,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (titulo != null) ...[
              Row(children: [
                Expanded(child: Text(titulo!, style: Theme.of(context).textTheme.titleMedium)),
                ?acao,
              ]),
              const SizedBox(height: Gap.md),
            ],
            child,
          ]),
        ),
      );
}

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.label, required this.valor, required this.icon, this.cor = AppColors.primary, this.rodape});
  final String label;
  final String valor;
  final IconData icon;
  final Color cor;
  final String? rodape;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg - 4),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: cor.withValues(alpha: .1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: cor),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(valor, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.text)),
                ),
                // Linha sempre presente para todos os cards terem a mesma altura.
                Text(rodape ?? '', style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
          ]),
        ),
      );
}

// ===== Elementos =====

class Pill extends StatelessWidget {
  const Pill({super.key, required this.label, required this.cor, this.icon});
  final String label;
  final Color cor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: cor.withValues(alpha: .1), borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 14, color: cor), const SizedBox(width: 4)],
          Text(label, style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      );
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});
  final Status? status;

  @override
  Widget build(BuildContext context) => status == null
      ? const Pill(label: 'Sem dívida', cor: AppColors.neutral)
      : Pill(label: status!.label, cor: status!.color, icon: status!.icon);
}

class Avatar extends StatelessWidget {
  const Avatar(this.nome, {super.key, this.size = 40});
  final String nome;
  final double size;

  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: size / 2,
        backgroundColor: AppColors.primary.withValues(alpha: .1),
        child: Text(iniciais(nome),
            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: size * .36)),
      );
}

class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.valor, {super.key, this.destaque});
  final String label;
  final String valor;
  final Color? destaque;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 140, child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 14))),
          Expanded(
            child: Text(valor,
                style: TextStyle(fontWeight: FontWeight.w500, color: destaque ?? AppColors.text)),
          ),
        ]),
      );
}

/// Campo de filtro com largura fixa, para as barras de filtro ficarem alinhadas.
class FilterField extends StatelessWidget {
  const FilterField({super.key, required this.child, this.width = 220});
  final Widget child;
  final double width;
  @override
  Widget build(BuildContext context) =>
      SizedBox(width: MediaQuery.sizeOf(context).width < 600 ? double.infinity : width, child: child);
}

class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.hint, required this.onChanged});
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextField(
        onChanged: onChanged,
        decoration: InputDecoration(hintText: hint, prefixIcon: const Icon(Icons.search, size: 20)),
      );
}

class Dropdown<T> extends StatelessWidget {
  const Dropdown({super.key, required this.label, required this.value, required this.itens, required this.onChanged});
  final String label;
  final T value;
  final Map<T, String> itens;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [for (final e in itens.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
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
        title: Row(children: [
          Expanded(child: Text(titulo, style: Theme.of(ctx).textTheme.titleLarge)),
          IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close), tooltip: 'Fechar'),
        ]),
        contentPadding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.sm),
        content: SizedBox(width: width, child: SingleChildScrollView(child: builder(ctx, setState))),
        actionsPadding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.lg),
        actions: acoes?.call(ctx, setState),
      ),
    ),
  );
}

/// Botão primário que mostra spinner enquanto a ação assíncrona roda.
class BusyButton extends StatelessWidget {
  const BusyButton({super.key, required this.label, required this.busy, required this.onPressed, this.icon});
  final String label;
  final bool busy;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
        onPressed: busy ? null : onPressed,
        icon: busy
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Icon(icon ?? Icons.check, size: 18),
        label: Text(label),
      );
}

class FormSection extends StatelessWidget {
  const FormSection(this.titulo, {super.key});
  final String titulo;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: Gap.sm, bottom: Gap.sm),
        child: Text(titulo.toUpperCase(),
            style: const TextStyle(fontSize: 12, letterSpacing: .6, fontWeight: FontWeight.w600, color: AppColors.muted)),
      );
}

// ===== Tabela =====

/// Tabela padrão com rolagem horizontal em telas estreitas.
class AppTable extends StatelessWidget {
  const AppTable({super.key, required this.colunas, required this.linhas, this.numericas = const {}});
  final List<String> colunas;
  final List<List<Widget>> linhas;
  final Set<int> numericas;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: c.maxWidth),
            child: DataTable(
              headingRowHeight: 40,
              dataRowMinHeight: 52,
              dataRowMaxHeight: 60,
              horizontalMargin: 0,
              columnSpacing: Gap.lg,
              headingTextStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted),
              columns: [
                for (var i = 0; i < colunas.length; i++) DataColumn(label: Text(colunas[i]), numeric: numericas.contains(i)),
              ],
              rows: [for (final l in linhas) DataRow(cells: [for (final w in l) DataCell(w)])],
            ),
          ),
        ),
      );
}
