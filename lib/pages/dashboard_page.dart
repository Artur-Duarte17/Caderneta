import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PageHeader(titulo: 'Visão Geral', subtitulo: 'Resumo de ${data(DateTime.now())}'),
        AsyncView<Snapshot>(load: Snapshot.load, builder: (context, s, _) => _Conteudo(s)),
      ]);
}

class _Conteudo extends StatelessWidget {
  const _Conteudo(this.s);
  final Snapshot s;

  @override
  Widget build(BuildContext context) {
    final inicioMes = DateTime(DateTime.now().year, DateTime.now().month);
    final emAberto = s.dividas.where((d) => d.status.emAberto);
    final saldo = emAberto.fold<double>(0, (t, d) => t + d.valorPendente);
    final vendasMes = s.vendas.where((v) => v.dataHora != null && !v.dataHora!.isBefore(inicioMes));
    final recebidoMes = s.dividas
        .expand((d) => d.pagamentos)
        .where((p) => p.dataPagamento != null && !p.dataPagamento!.isBefore(inicioMes))
        .fold<double>(0, (t, p) => t + p.valorPago);
    final vencidas = s.dividas.where((d) => d.status == Status.vencida).toList()
      ..sort((a, b) => b.diasAtraso.compareTo(a.diasAtraso));
    final recentes = [...s.vendas]..sort((a, b) => (b.dataHora ?? DateTime(0)).compareTo(a.dataHora ?? DateTime(0)));

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ResponsiveGrid(minWidth: 240, children: [
        StatCard(label: 'Saldo a receber', valor: moeda(saldo), icon: Icons.account_balance_wallet_outlined,
            rodape: '${emAberto.length} dívida(s) em aberto'),
        StatCard(label: 'Vendas no mês', valor: moeda(vendasMes.fold<double>(0, (t, v) => t + v.valorTotal)),
            icon: Icons.receipt_long_outlined, cor: AppColors.info, rodape: '${vendasMes.length} venda(s)'),
        StatCard(label: 'Recebido no mês', valor: moeda(recebidoMes), icon: Icons.payments_outlined, cor: AppColors.success),
        StatCard(label: 'Dívidas vencidas', valor: '${vencidas.length}', icon: Icons.warning_amber_rounded, cor: AppColors.danger,
            rodape: moeda(vencidas.fold<double>(0, (t, d) => t + d.valorPendente))),
      ]),
      const SizedBox(height: Gap.lg),
      LayoutBuilder(builder: (context, c) {
        final vendasCard = SectionCard(
          titulo: 'Vendas recentes',
          acao: TextButton(onPressed: () => context.go('/vendas'), child: const Text('Ver todas')),
          child: recentes.isEmpty
              ? const EmptyState(icon: Icons.receipt_long, titulo: 'Nenhuma venda registrada')
              : AppTable(
                  colunas: const ['Venda', 'Cliente', 'Data', 'Valor', 'Status'],
                  numericas: const {3},
                  linhas: [
                    for (final v in recentes.take(5))
                      [
                        Text('#${v.id}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(s.nomeCliente(v.clienteId)),
                        Text(data(v.dataHora)),
                        Text(moeda(v.valorTotal)),
                        StatusBadge(s.statusVenda(v)),
                      ],
                  ],
                ),
        );
        final atrasoCard = SectionCard(
          titulo: 'Clientes em atraso',
          acao: TextButton(onPressed: () => context.go('/pagamentos'), child: const Text('Ver todos')),
          child: vencidas.isEmpty
              ? const EmptyState(icon: Icons.verified_outlined, titulo: 'Nenhuma dívida vencida')
              : Column(children: [
                  for (final d in vencidas.take(5))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Avatar(s.nomeCliente(d.clienteId)),
                      title: Text(s.nomeCliente(d.clienteId), style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text(_atraso(d.diasAtraso)),
                      trailing: Text(moeda(d.valorPendente),
                          style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
                    ),
                ]),
        );
        if (c.maxWidth < 900) return Column(children: [vendasCard, const SizedBox(height: Gap.lg), atrasoCard]);
        return IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(flex: 3, child: vendasCard),
            const SizedBox(width: Gap.lg),
            Expanded(flex: 2, child: atrasoCard),
          ]),
        );
      }),
    ]);
  }
}

String _atraso(int dias) {
  if (dias > 0) return 'Vencida há $dias dia(s)';
  if (dias == 0) return 'Vence hoje';
  return 'Vence em ${-dias} dia(s)';
}
