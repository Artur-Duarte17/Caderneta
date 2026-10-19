import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:web/web.dart' as web;

import '../core/api.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class _Relatorio {
  _Relatorio(this.vendas, this.dividas, this.clientes) : _clientes = {for (final c in clientes) c.id: c};
  final List<Venda> vendas;
  final List<Divida> dividas;
  final List<Cliente> clientes;
  final Map<int, Cliente> _clientes;
  String nome(int id) => _clientes[id]?.nome ?? 'Cliente #$id';
  Status? statusVenda(Venda v) => dividas.where((d) => d.id == v.dividaId).firstOrNull?.status;
}

enum _Tabela { vendas, dividas, clientes }

class RelatoriosPage extends StatefulWidget {
  const RelatoriosPage({super.key});
  @override
  State<RelatoriosPage> createState() => _RelatoriosPageState();
}

class _RelatoriosPageState extends State<RelatoriosPage> {
  late DateTimeRange _periodo = DateTimeRange(start: DateTime(DateTime.now().year, DateTime.now().month), end: hoje());
  _Tabela _tabela = _Tabela.vendas;

  Future<_Relatorio> _load() async {
    final api = Api.instance;
    final ini = isoDate(_periodo.start), fim = isoDate(_periodo.end);
    final r = await Future.wait([api.relatorioVendas(ini, fim), api.relatorioDividas(ini, fim), api.clientes()]);
    return _Relatorio(r[0] as List<Venda>, r[1] as List<Divida>, r[2] as List<Cliente>);
  }

  Future<void> _escolherPeriodo() async {
    final r = await showDateRangePicker(
      context: context,
      initialDateRange: _periodo,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialEntryMode: DatePickerEntryMode.input,
    );
    if (r != null) setState(() => _periodo = r);
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PageHeader(
          titulo: 'Relatórios',
          subtitulo: 'Período: ${data(_periodo.start)} a ${data(_periodo.end)}',
          acoes: [
            OutlinedButton.icon(onPressed: _escolherPeriodo, icon: const Icon(Icons.date_range, size: 18), label: const Text('Alterar período')),
          ],
        ),
        AsyncView<_Relatorio>(
          key: ValueKey(_periodo),
          load: _load,
          builder: (context, r, _) => _conteudo(context, r),
        ),
      ]);

  Widget _conteudo(BuildContext context, _Relatorio r) {
    final totalVendido = r.vendas.fold<double>(0, (t, v) => t + v.valorTotal);
    final totalRecebido = r.dividas.fold<double>(0, (t, d) => t + d.valorPago);
    final totalPendente = r.dividas.where((d) => d.status.emAberto).fold<double>(0, (t, d) => t + d.valorPendente);
    final inadimplencia = totalVendido == 0
        ? 0.0
        : r.dividas.where((d) => d.status == Status.vencida).fold<double>(0, (t, d) => t + d.valorPendente) / totalVendido * 100;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ResponsiveGrid(minWidth: 240, children: [
        StatCard(label: 'Total vendido', valor: moeda(totalVendido), icon: Icons.receipt_long_outlined, rodape: '${r.vendas.length} venda(s)'),
        StatCard(label: 'Total recebido', valor: moeda(totalRecebido), icon: Icons.payments_outlined, cor: AppColors.success),
        StatCard(label: 'Saldo pendente', valor: moeda(totalPendente), icon: Icons.account_balance_wallet_outlined, cor: AppColors.warning),
        StatCard(label: 'Inadimplência', valor: '${inadimplencia.toStringAsFixed(1).replaceAll('.', ',')}%', icon: Icons.trending_down,
            cor: AppColors.danger, rodape: '${r.vendas.map((v) => v.clienteId).toSet().length} cliente(s) ativos'),
      ]),
      const SizedBox(height: Gap.lg),
      ResponsiveGrid(minWidth: 460, spacing: Gap.lg, children: [
        SectionCard(titulo: 'Vendas por dia', child: SizedBox(height: 260, child: _graficoVendas(r))),
        SectionCard(titulo: 'Recebimentos por método', child: SizedBox(height: 260, child: _graficoMetodos(r))),
      ]),
      const SizedBox(height: Gap.lg),
      SectionCard(
        titulo: 'Detalhamento',
        acao: OutlinedButton.icon(onPressed: () => _exportar(r), icon: const Icon(Icons.download, size: 18), label: const Text('Exportar CSV')),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<_Tabela>(
              segments: const [
                ButtonSegment(value: _Tabela.vendas, label: Text('Vendas'), icon: Icon(Icons.receipt_long_outlined)),
                ButtonSegment(value: _Tabela.dividas, label: Text('Dívidas'), icon: Icon(Icons.payments_outlined)),
                ButtonSegment(value: _Tabela.clientes, label: Text('Clientes'), icon: Icon(Icons.people_outline)),
              ],
              selected: {_tabela},
              onSelectionChanged: (s) => setState(() => _tabela = s.first),
            ),
          ),
          const SizedBox(height: Gap.md),
          _tabelaWidget(r),
        ]),
      ),
    ]);
  }

  Widget _vazio() => const EmptyState(icon: Icons.insights_outlined, titulo: 'Sem dados no período');

  Widget _graficoVendas(_Relatorio r) {
    final porDia = <DateTime, double>{};
    for (final v in r.vendas.where((v) => v.dataHora != null)) {
      final d = DateTime(v.dataHora!.year, v.dataHora!.month, v.dataHora!.day);
      porDia[d] = (porDia[d] ?? 0) + v.valorTotal;
    }
    if (porDia.isEmpty) return _vazio();
    final dias = porDia.keys.toList()..sort();
    final fmt = DateFormat('dd/MM');
    return LineChart(LineChartData(
      gridData: const FlGridData(drawVerticalLine: false),
      borderData: FlBorderData(show: false),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (spots) => [
            for (final s in spots)
              LineTooltipItem('${fmt.format(dias[s.x.toInt()])}\n${moeda(s.y)}', const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(),
        rightTitles: const AxisTitles(),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 56, getTitlesWidget: _eixoValor)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: (dias.length / 6).ceilToDouble().clamp(1, 999),
            getTitlesWidget: (v, m) => v % 1 == 0 && v < dias.length ? _eixo(fmt.format(dias[v.toInt()])) : const SizedBox.shrink(),
          ),
        ),
      ),
      minY: 0,
      lineBarsData: [
        LineChartBarData(
          spots: [for (var i = 0; i < dias.length; i++) FlSpot(i.toDouble(), porDia[dias[i]]!)],
          isCurved: true,
          preventCurveOverShooting: true,
          color: AppColors.primary,
          barWidth: 2.5,
          dotData: FlDotData(show: dias.length < 20),
          belowBarData: BarAreaData(show: true, color: AppColors.primary.withValues(alpha: .08)),
        ),
      ],
    ));
  }

  Widget _graficoMetodos(_Relatorio r) {
    final porMetodo = <MetodoPagamento, double>{};
    for (final p in r.dividas.expand((d) => d.pagamentos)) {
      final m = p.metodo ?? MetodoPagamento.DINHEIRO;
      porMetodo[m] = (porMetodo[m] ?? 0) + p.valorPago;
    }
    if (porMetodo.isEmpty) return _vazio();
    final metodos = MetodoPagamento.values.where(porMetodo.containsKey).toList();
    return BarChart(BarChartData(
      gridData: const FlGridData(drawVerticalLine: false),
      borderData: FlBorderData(show: false),
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (g, _, rod, _) =>
              BarTooltipItem('${metodos[g.x].label}\n${moeda(rod.toY)}', const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(),
        rightTitles: const AxisTitles(),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 56, getTitlesWidget: _eixoValor)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) => _eixo(metodos[v.toInt()].label))),
      ),
      barGroups: [
        for (var i = 0; i < metodos.length; i++)
          BarChartGroupData(x: i, barRods: [
            BarChartRodData(toY: porMetodo[metodos[i]]!, color: AppColors.secondary, width: 28, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
          ]),
      ],
    ));
  }

  // Omite o rótulo do topo para não sobrepor o penúltimo.
  Widget _eixoValor(double v, TitleMeta m) =>
      v == m.max && v != m.min ? const SizedBox.shrink() : _eixo(NumberFormat.compact(locale: 'pt_BR').format(v));

  Widget _eixo(String t) => Padding(padding: const EdgeInsets.only(top: 4), child: Text(t, style: const TextStyle(fontSize: 11, color: AppColors.muted)));

  Widget _tabelaWidget(_Relatorio r) {
    switch (_tabela) {
      case _Tabela.vendas:
        if (r.vendas.isEmpty) return _vazio();
        return AppTable(colunas: const ['Data', 'Venda', 'Cliente', 'Valor', 'Status'], numericas: const {3}, linhas: [
          for (final v in r.vendas) [Text(data(v.dataHora)), Text('#${v.id}'), Text(r.nome(v.clienteId)), Text(moeda(v.valorTotal)), StatusBadge(r.statusVenda(v))],
        ]);
      case _Tabela.dividas:
        if (r.dividas.isEmpty) return _vazio();
        return AppTable(colunas: const ['Vencimento', 'Cliente', 'Original', 'Pago', 'Pendente', 'Status'], numericas: const {2, 3, 4}, linhas: [
          for (final d in r.dividas)
            [Text(data(d.dataVencimento)), Text(r.nome(d.clienteId)), Text(moeda(d.valorOriginal)), Text(moeda(d.valorPago)), Text(moeda(d.valorPendente)), StatusBadge(d.status)],
        ]);
      case _Tabela.clientes:
        if (r.clientes.isEmpty) return _vazio();
        return AppTable(colunas: const ['Cliente', 'Telefone', 'Compras no período', 'Limite'], numericas: const {2, 3}, linhas: [
          for (final c in r.clientes)
            [
              Text(c.nome),
              Text(c.telefone ?? '—'),
              Text(moeda(r.vendas.where((v) => v.clienteId == c.id).fold<double>(0, (t, v) => t + v.valorTotal))),
              Text(moeda(c.limiteCredito)),
            ],
        ]);
    }
  }

  void _exportar(_Relatorio r) {
    final num2 = NumberFormat('0.00', 'pt_BR');
    final (cab, linhas, nome) = switch (_tabela) {
      _Tabela.vendas => (
          ['Data', 'Venda', 'Cliente', 'Valor', 'Status'],
          [for (final v in r.vendas) [data(v.dataHora), '${v.id}', r.nome(v.clienteId), num2.format(v.valorTotal), r.statusVenda(v)?.label ?? '']],
          'vendas'
        ),
      _Tabela.dividas => (
          ['Vencimento', 'Cliente', 'Original', 'Pago', 'Pendente', 'Status'],
          [
            for (final d in r.dividas)
              [data(d.dataVencimento), r.nome(d.clienteId), num2.format(d.valorOriginal), num2.format(d.valorPago), num2.format(d.valorPendente), d.status.label]
          ],
          'dividas'
        ),
      _Tabela.clientes => (
          ['Nome', 'Telefone', 'E-mail', 'Limite'],
          [for (final c in r.clientes) [c.nome, c.telefone ?? '', c.email ?? '', num2.format(c.limiteCredito)]],
          'clientes'
        ),
    };
    String esc(String s) => '"${s.replaceAll('"', '""')}"';
    // Separador ";" e BOM para abrir corretamente no Excel em português.
    final csv = '﻿${[cab, ...linhas].map((l) => l.map(esc).join(';')).join('\r\n')}';
    final bytes = Uint8List.fromList(utf8.encode(csv));
    final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: 'text/csv;charset=utf-8'));
    final url = web.URL.createObjectURL(blob);
    web.HTMLAnchorElement()
      ..href = url
      ..download = 'relatorio-$nome-${isoDate(_periodo.start)}_${isoDate(_periodo.end)}.csv'
      ..click();
    web.URL.revokeObjectURL(url);
    toast(context, 'CSV exportado');
  }
}
