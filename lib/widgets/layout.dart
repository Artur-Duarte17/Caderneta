import 'apresentacao_status.dart';
import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../core/theme.dart';
import 'animacoes.dart';

// ===== Layout =====

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.titulo,
    this.subtitulo,
    this.acoes = const [],
  });
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(titulo, style: Theme.of(context).textTheme.headlineSmall),
            if (subtitulo != null) ...[
              const SizedBox(height: Gap.xs),
              Text(
                subtitulo!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontSize: 14),
              ),
            ],
          ],
        ),
        if (acoes.isNotEmpty)
          Wrap(spacing: Gap.sm, runSpacing: Gap.sm, children: acoes),
      ],
    ),
  );
}

/// Grade responsiva: distribui [children] em colunas de largura mínima
/// [minWidth]; os itens de uma mesma linha ficam com a mesma altura.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minWidth = 280,
    this.spacing = Gap.md,
  });
  final List<Widget> children;
  final double minWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final cols = (c.maxWidth / minWidth).floor().clamp(1, 6);
      return Column(
        children: [
          for (var i = 0; i < children.length; i += cols) ...[
            if (i > 0) SizedBox(height: spacing),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < cols; j++) ...[
                    if (j > 0) SizedBox(width: spacing),
                    Expanded(
                      child: i + j < children.length
                          ? Surgir(ordem: i + j, child: children[i + j])
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.titulo,
    this.acao,
    required this.child,
    this.padding = const EdgeInsets.all(Gap.lg),
  });
  final String? titulo;
  final Widget? acao;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (titulo != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    titulo!,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ?acao,
              ],
            ),
            const SizedBox(height: Gap.md),
          ],
          child,
        ],
      ),
    ),
  );
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.valor,
    required this.icon,
    this.cor = AppColors.primary,
    this.rodape,
  });
  final String label;
  final String valor;
  final IconData icon;
  final Color cor;
  final String? rodape;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(Gap.ml),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cor.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: cor),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontSize: 13),
                ),
                const SizedBox(height: Gap.xs),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    valor,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                ),
                // Linha sempre presente para todos os cards terem a mesma altura.
                Text(
                  rodape ?? '',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
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
    padding: const EdgeInsets.symmetric(horizontal: Gap.ms, vertical: Gap.xs),
    decoration: BoxDecoration(
      color: cor.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: cor),
          const SizedBox(width: Gap.xs),
        ],
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: cor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
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
    child: Text(
      iniciais(nome),
      style: TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.w600,
        fontSize: size * .36,
      ),
    ),
  );
}

class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.valor, {super.key, this.destaque});
  final String label;
  final String valor;
  final Color? destaque;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Gap.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontSize: 14),
          ),
        ),
        Expanded(
          child: Text(
            valor,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: destaque ?? AppColors.text,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Campo de filtro com largura fixa, para as barras de filtro ficarem alinhadas.
