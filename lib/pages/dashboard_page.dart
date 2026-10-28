import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'clientes_page.dart' show abrirFormCliente;
import 'pagamentos_page.dart' show abrirFormPagamento;
import 'vendas_page.dart' show abrirFormVenda;

final _diaExtenso = DateFormat("EEEE, d 'de' MMMM", 'pt_BR');

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) => AsyncView<Snapshot>(
      load: Snapshot.load,
      builder: (context, s, _) {
        final mobile = isMobile(context);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PageHeader(titulo: 'Visão Geral', subtitulo: toBeginningOfSentenceCase(_diaExtenso.format(DateTime.now())), acoes: [
            if (!mobile)
              OutlinedButton.icon(
                  onPressed: () => abrirFormCliente(context),
                  icon: const Icon(Icons.person_add_alt, size: 18),
                  label: const Text('Novo cliente')),
            FilledButton.icon(
                onPressed: s.clientes.isEmpty ? null : () => abrirFormVenda(context, s.clientes),
                icon: const Icon(Icons.add, size: 18),
                label: Text(mobile ? 'Venda' : 'Nova venda'))
          ]),
          _Conteudo(s)
        ]);
      });
}

/// Indicadores calculados uma vez a partir do snapshot.
class _Indicadores {
  _Indicadores(this.s) {
    final agora = DateTime.now();
    final inicioMes = DateTime(agora.year, agora.month);
    final inicioMesAnterior = DateTime(agora.year, agora.month - 1);
    bool noMes(DateTime? d) => d != null && !d.isBefore(inicioMes);
    bool noMesAnterior(DateTime? d) => d != null && !d.isBefore(inicioMesAnterior) && d.isBefore(inicioMes);

    final abertas = s.dividas.where((d) => d.status.emAberto).toList();
    saldo = _soma(abertas.map((d) => d.valorPendente));
    qtdAbertas = abertas.length;
    vencidas = abertas.where((d) => d.status == Status.vencida).toList()..sort((a, b) => b.diasAtraso.compareTo(a.diasAtraso));
    valorVencido = _soma(vencidas.map((d) => d.valorPendente));
    aVencer = abertas.where((d) => d.status != Status.vencida).toList()
      ..sort((a, b) => (a.dataVencimento ?? DateTime(9999)).compareTo(b.dataVencimento ?? DateTime(9999)));

    final vendasMes = s.vendas.where((v) => noMes(v.dataHora));
    qtdVendasMes = vendasMes.length;
    vendidoMes = _soma(vendasMes.map((v) => v.valorTotal));
    vendidoMesAnterior = _soma(s.vendas.where((v) => noMesAnterior(v.dataHora)).map((v) => v.valorTotal));

    final pagamentos = s.dividas.expand((d) => d.pagamentos).toList();
    final pagsMes = pagamentos.where((p) => noMes(p.dataPagamento));
    qtdPagsMes = pagsMes.length;
    recebidoMes = _soma(pagsMes.map((p) => p.valorPago));
    recebidoMesAnterior = _soma(pagamentos.where((p) => noMesAnterior(p.dataPagamento)).map((p) => p.valorPago));

    // Últimos 6 meses (incluindo o atual) para o gráfico.
    meses = [for (var i = 5; i >= 0; i--) DateTime(agora.year, agora.month - i)];
    int idx(DateTime? d) => d == null ? -1 : meses.indexWhere((m) => m.year == d.year && m.month == d.month);
    vendidoPorMes = List.filled(6, 0);
    recebidoPorMes = List.filled(6, 0);
    for (final v in s.vendas) {
      final i = idx(v.dataHora);
      if (i >= 0) vendidoPorMes[i] += v.valorTotal;
    }
    for (final p in pagamentos) {
      final i = idx(p.dataPagamento);
      if (i >= 0) recebidoPorMes[i] += p.valorPago;
    }

    final limiteTotal = _soma(s.clientes.map((c) => c.limiteCredito));
    creditoUsado = limiteTotal == 0 ? 0 : saldo / limiteTotal;
    clientesComSaldo = s.clientes.where((c) => s.saldoDevedor(c.id) > 0).length;
    clientesEmAtraso = s.clientes.where((c) => s.emAtraso(c.id)).length;
  }

  final Snapshot s;
  late final double saldo, valorVencido, vendidoMes, vendidoMesAnterior, recebidoMes, recebidoMesAnterior, creditoUsado;
  late final int qtdAbertas, qtdVendasMes, qtdPagsMes, clientesComSaldo, clientesEmAtraso;
  late final List<Divida> vencidas, aVencer;
  late final List<DateTime> meses;
  late final List<double> vendidoPorMes, recebidoPorMes;

  double get valorAVencer => saldo - valorVencido;

  static double _soma(Iterable<double> v) => v.fold<double>(0, (t, x) => t + x);
}

/// " · +12% x mês ant." (ou nada quando não há base de comparação).
String _variacao(double atual, double anterior) {
  if (anterior <= 0) return '';
  final p = (atual - anterior) / anterior * 100;
  return ' · ${p >= 0 ? '+' : '−'}${p.abs().toStringAsFixed(0)}% x mês ant.';
}

class _Conteudo extends StatelessWidget {
  const _Conteudo(this.s);
  final Snapshot s;

  @override
  Widget build(BuildContext context) {
    final k = _Indicadores(s);
    const gap = Gap.md - 4;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ResponsiveGrid(minWidth: isMobile(context) ? 160 : 220, spacing: gap, preencher: true, children: [
        StatCard(
            label: 'Saldo a receber',
            valor: moeda(k.saldo),
            icon: Icons.account_balance_wallet_outlined,
            rodape: '${k.qtdAbertas} dívida(s) em aberto'),
        StatCard(
            label: 'Vendas no mês',
            valor: moeda(k.vendidoMes),
            icon: Icons.receipt_long_outlined,
            cor: AppColors.info,
            rodape: '${k.qtdVendasMes} venda(s)${_variacao(k.vendidoMes, k.vendidoMesAnterior)}'),
        StatCard(
            label: 'Recebido no mês',
            valor: moeda(k.recebidoMes),
            icon: Icons.payments_outlined,
            cor: AppColors.success,
            rodape: '${k.qtdPagsMes} pagamento(s)${_variacao(k.recebidoMes, k.recebidoMesAnterior)}'),
        StatCard(
            label: 'Vencido',
            valor: moeda(k.valorVencido),
            icon: Icons.warning_amber_rounded,
            cor: AppColors.danger,
            rodape: '${k.vencidas.length} dívida(s) · ${k.clientesEmAtraso} cliente(s)')
      ]),
      const SizedBox(height: gap),
      _linha(context, flex: const [
        3,
        2
      ], children: [
        SectionCard(titulo: 'Vendas x recebimentos', acao: const _Legenda(), child: SizedBox(height: 220, child: _GraficoMeses(k))),
        SectionCard(titulo: 'Situação da carteira', child: _Carteira(k))
      ]),
      const SizedBox(height: gap),
      _linha(context, flex: const [
        1,
        1,
        1
      ], children: [
        SectionCard(
            titulo: 'Próximos vencimentos',
            acao: TextButton(onPressed: () => context.go('/pagamentos'), child: const Text('Ver todos')),
            child: k.aVencer.isEmpty
                ? const _Vazio(icon: Icons.event_available_outlined, texto: 'Nenhuma dívida a vencer')
                : Column(children: [
                    for (final d in k.aVencer.take(5))
                      _LinhaDivida(s: s, d: d, detalhe: _prazo(d.diasAtraso), cor: d.diasAtraso >= -3 ? AppColors.warning : AppColors.muted)
                  ])),
        SectionCard(
            titulo: 'Em atraso',
            acao: TextButton(onPressed: () => context.go('/pagamentos'), child: const Text('Ver todos')),
            child: k.vencidas.isEmpty
                ? const _Vazio(icon: Icons.verified_outlined, texto: 'Nenhuma dívida vencida')
                : Column(children: [
                    for (final d in k.vencidas.take(5)) _LinhaDivida(s: s, d: d, detalhe: _prazo(d.diasAtraso), cor: AppColors.danger)
                  ])),
        SectionCard(
            titulo: 'Vendas recentes',
            acao: TextButton(onPressed: () => context.go('/vendas'), child: const Text('Ver todas')),
            child: s.vendas.isEmpty
                ? const _Vazio(icon: Icons.receipt_long_outlined, texto: 'Nenhuma venda registrada')
                : Column(children: [
                    for (final v
                        in ([...s.vendas]..sort((a, b) => (b.dataHora ?? DateTime(0)).compareTo(a.dataHora ?? DateTime(0)))).take(5))
                      _LinhaVenda(s: s, v: v)
                  ]))
      ])
    ]);
  }

  /// Cartões lado a lado com a mesma altura no desktop; empilhados no celular.
  Widget _linha(BuildContext context, {required List<int> flex, required List<Widget> children}) => LayoutBuilder(builder: (context, c) {
        const gap = Gap.md - 4;
        final minPorCartao = children.length == 3 ? 320.0 : 360.0;
        if (c.maxWidth < minPorCartao * children.length) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: gap), children[i]]
          ]);
        }
        return IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: gap), Expanded(flex: flex[i], child: children[i])]
        ]));
      });
}

String _prazo(int diasAtraso) {
  if (diasAtraso > 0) return 'Vencida há $diasAtraso dia(s)';
  if (diasAtraso == 0) return 'Vence hoje';
  if (diasAtraso == -1) return 'Vence amanhã';
  return 'Vence em ${-diasAtraso} dias';
}

class _Vazio extends StatelessWidget {
  const _Vazio({required this.icon, required this.texto});
  final IconData icon;
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.lg),
      child: Column(children: [
        Icon(icon, size: 32, color: AppColors.muted.withValues(alpha: .5)),
        const SizedBox(height: Gap.xs),
        Text(texto, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13))
      ]));
}

/// Linha compacta usada nas listas da Visão Geral; toque abre o pagamento.
class _LinhaDivida extends StatelessWidget {
  const _LinhaDivida({required this.s, required this.d, required this.detalhe, required this.cor});
  final Snapshot s;
  final Divida d;
  final String detalhe;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    final nome = s.nomeCliente(d.clienteId);
    return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => abrirFormPagamento(context, d, nome),
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
            child: Row(children: [
              Avatar(nome, size: 34),
              const SizedBox(width: Gap.md - 6),
              Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(nome, style: const TextStyle(fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('$detalhe · ${data(d.dataVencimento)}', style: TextStyle(fontSize: 12, color: cor))
              ])),
              const SizedBox(width: Gap.sm),
              Text(moeda(d.valorPendente),
                  style: TextStyle(fontWeight: FontWeight.w600, color: cor == AppColors.muted ? AppColors.text : cor))
            ])));
  }
}

class _LinhaVenda extends StatelessWidget {
  const _LinhaVenda({required this.s, required this.v});
  final Snapshot s;
  final Venda v;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
      child: Row(children: [
        Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.info.withValues(alpha: .1), borderRadius: BorderRadius.circular(8)),
            child: Text('#${v.id}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.info))),
        const SizedBox(width: Gap.md - 6),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.nomeCliente(v.clienteId),
              style: const TextStyle(fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(data(v.dataHora), style: Theme.of(context).textTheme.bodySmall)
        ])),
        const SizedBox(width: Gap.sm),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(moeda(v.valorTotal), style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          _StatusPonto(s.statusVenda(v))
        ])
      ]));
}

/// Versão compacta do status (ponto + texto) para caber nas linhas.
class _StatusPonto extends StatelessWidget {
  const _StatusPonto(this.status);
  final Status? status;

  @override
  Widget build(BuildContext context) {
    final cor = status?.color ?? AppColors.neutral;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 6, height: 6, decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(status?.label ?? 'Sem dívida', style: TextStyle(fontSize: 11, color: cor, fontWeight: FontWeight.w600))
    ]);
  }
}

class _Legenda extends StatelessWidget {
  const _Legenda();

  Widget _item(Color cor, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(t, style: const TextStyle(fontSize: 12, color: AppColors.muted))
      ]);

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: Gap.md - 4, children: [_item(AppColors.primary, 'Vendido'), _item(AppColors.success, 'Recebido')]);
}

class _GraficoMeses extends StatelessWidget {
  const _GraficoMeses(this.k);
  final _Indicadores k;

  @override
  Widget build(BuildContext context) {
    final fmtMes = DateFormat('MMM', 'pt_BR');
    final compacto = NumberFormat.compact(locale: 'pt_BR');
    Widget eixo(String t) =>
        Padding(padding: const EdgeInsets.only(top: 4), child: Text(t, style: const TextStyle(fontSize: 11, color: AppColors.muted)));

    return BarChart(BarChartData(
        gridData: const FlGridData(drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (g, _, rod, i) => BarTooltipItem('${i == 0 ? 'Vendido' : 'Recebido'}\n${moeda(rod.toY)}',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)))),
        titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
                sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    // Omite o rótulo do topo para não sobrepor o penúltimo.
                    getTitlesWidget: (v, m) => v == m.max && v != m.min ? const SizedBox.shrink() : eixo(compacto.format(v)))),
            bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, m) => eixo(toBeginningOfSentenceCase(fmtMes.format(k.meses[v.toInt()]).replaceAll('.', '')))))),
        barGroups: [
          for (var i = 0; i < k.meses.length; i++)
            BarChartGroupData(x: i, barsSpace: 3, barRods: [
              BarChartRodData(
                  toY: k.vendidoPorMes[i],
                  color: AppColors.primary,
                  width: 12,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
              BarChartRodData(
                  toY: k.recebidoPorMes[i],
                  color: AppColors.success,
                  width: 12,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)))
            ])
        ]));
  }
}

class _Carteira extends StatelessWidget {
  const _Carteira(this.k);
  final _Indicadores k;

  Widget _linha(BuildContext context, String label, String valor, {Color? cor, IconData? icon}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        if (icon != null) ...[Icon(icon, size: 16, color: cor ?? AppColors.muted), const SizedBox(width: Gap.sm)],
        Expanded(child: Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13))),
        Text(valor, style: TextStyle(fontWeight: FontWeight.w600, color: cor ?? AppColors.text))
      ]));

  @override
  Widget build(BuildContext context) {
    final total = k.saldo;
    final pVencido = total == 0 ? 0.0 : k.valorVencido / total;
    final semana = k.aVencer.where((d) => d.diasAtraso >= -7);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Total em aberto', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13)),
      Text(moeda(total), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.text)),
      const SizedBox(height: Gap.sm),
      // Barra dividida: a vencer x vencido.
      ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
              height: 10,
              child: total == 0
                  ? const ColoredBox(color: AppColors.border)
                  : Row(children: [
                      if (pVencido < 1) Expanded(flex: ((1 - pVencido) * 1000).round(), child: const ColoredBox(color: AppColors.info)),
                      if (pVencido > 0) Expanded(flex: (pVencido * 1000).round(), child: const ColoredBox(color: AppColors.danger))
                    ]))),
      const SizedBox(height: Gap.sm),
      _linha(context, 'A vencer', moeda(k.valorAVencer), cor: AppColors.info, icon: Icons.schedule),
      _linha(context, 'Vencido', moeda(k.valorVencido), cor: AppColors.danger, icon: Icons.error_outline),
      const Divider(height: Gap.md),
      _linha(context, 'Vence nos próximos 7 dias', '${semana.length} · ${moeda(semana.fold<double>(0, (t, d) => t + d.valorPendente))}'),
      _linha(context, 'Clientes com saldo', '${k.clientesComSaldo} de ${k.s.clientes.length}'),
      _linha(context, 'Crédito utilizado', '${(k.creditoUsado * 100).toStringAsFixed(0)}% do limite total',
          cor: k.creditoUsado > .8 ? AppColors.danger : null)
    ]);
  }
}
