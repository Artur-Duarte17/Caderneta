import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/notificacoes_service.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'vendas_page.dart' show periodos, dentroDoPeriodo;

class PagamentosPage extends StatefulWidget {
  const PagamentosPage({super.key});
  @override
  State<PagamentosPage> createState() => _PagamentosPageState();
}

class _PagamentosPageState extends State<PagamentosPage> {
  String _busca = '';
  Status? _status;
  int _periodo = 0;

  @override
  Widget build(BuildContext context) => AsyncView<Snapshot>(
        load: Snapshot.load,
        builder: (context, s, _) {
          final termo = _busca.toLowerCase();
          final lista = s.dividas.where((d) {
            if (termo.isNotEmpty && !s.nomeCliente(d.clienteId).toLowerCase().contains(termo)) return false;
            if (_status != null && d.status != _status) return false;
            return dentroDoPeriodo(d.dataEmissao, _periodo);
          }).toList()
            // Em aberto primeiro, ordenadas pelo vencimento mais próximo.
            ..sort((a, b) {
              if (a.status.emAberto != b.status.emAberto) return a.status.emAberto ? -1 : 1;
              return (a.dataVencimento ?? DateTime(9999)).compareTo(b.dataVencimento ?? DateTime(9999));
            });

          final abertas = lista.where((d) => d.status.emAberto);
          final inicioMes = DateTime(DateTime.now().year, DateTime.now().month);
          final pagsMes = lista.expand((d) => d.pagamentos).where((p) => p.dataPagamento != null && !p.dataPagamento!.isBefore(inicioMes));
          final vencidas = lista.where((d) => d.status == Status.vencida);

          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const PageHeader(titulo: 'Pagamentos', subtitulo: 'Acompanhe dívidas e registre pagamentos recebidos'),
            ResponsiveGrid(minWidth: isMobile(context) ? 160 : 220, spacing: Gap.md - 4, preencher: true, children: [
              StatCard(label: 'Saldo pendente', valor: moeda(abertas.fold<double>(0, (t, d) => t + d.valorPendente)),
                  icon: Icons.account_balance_wallet_outlined, rodape: '${abertas.length} dívida(s) em aberto'),
              StatCard(label: 'Recebido no mês', valor: moeda(pagsMes.fold<double>(0, (t, p) => t + p.valorPago)),
                  icon: Icons.payments_outlined, cor: AppColors.success, rodape: '${pagsMes.length} pagamento(s)'),
              StatCard(label: 'Dívidas vencidas', valor: '${vencidas.length}', icon: Icons.warning_amber_rounded, cor: AppColors.danger,
                  rodape: moeda(vencidas.fold<double>(0, (t, d) => t + d.valorPendente))),
            ]),
            const SizedBox(height: Gap.md),
            Wrap(spacing: Gap.md, runSpacing: Gap.md - 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              FilterField(width: 300, child: SearchField(hint: 'Buscar cliente', onChanged: (v) => setState(() => _busca = v))),
              FilterField(
                child: Dropdown<Status?>(
                  label: 'Status',
                  value: _status,
                  itens: {null: 'Todos', for (final st in Status.values) st: st.label},
                  onChanged: (v) => setState(() => _status = v),
                ),
              ),
              FilterField(
                child: Dropdown<int>(label: 'Emissão', value: _periodo, itens: periodos, onChanged: (v) => setState(() => _periodo = v)),
              ),
            ]),
            const SizedBox(height: Gap.md),
            if (lista.isEmpty)
              const EmptyState(icon: Icons.inbox_outlined, titulo: 'Nenhuma dívida encontrada')
            else
              ResponsiveGrid(minWidth: 300, spacing: Gap.md - 4, children: [
                for (final d in lista) _DividaCard(divida: d, cliente: s.nomeCliente(d.clienteId), onPagar: () => _pagar(context, s, d)),
              ]),
          ]);
        },
      );

  Future<void> _pagar(BuildContext context, Snapshot s, Divida d) async {
    await abrirFormPagamento(context, d, s.nomeCliente(d.clienteId));
  }
}

/// Abre o formulário de pagamento de uma dívida. Usado também pela Visão Geral.
Future<void> abrirFormPagamento(BuildContext context, Divida d, String cliente) async {
  final ok = await showDialog<bool>(context: context, builder: (_) => _PagamentoForm(divida: d, cliente: cliente));
  if (ok == true) NotificacoesService.instance.dadosAlterados();
}

class _DividaCard extends StatelessWidget {
  const _DividaCard({required this.divida, required this.cliente, required this.onPagar});
  final Divida divida;
  final String cliente;
  final VoidCallback onPagar;

  Widget _valor(BuildContext context, String label, String valor, {Color? cor}) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(valor, style: TextStyle(fontWeight: FontWeight.w600, color: cor ?? AppColors.text)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final d = divida;
    final vencida = d.status == Status.vencida;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.vendaId == null ? 'Dívida #${d.id}' : 'Venda #${d.vendaId}', style: Theme.of(context).textTheme.titleMedium),
                Text(cliente, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 14)),
              ]),
            ),
            StatusBadge(d.status),
          ]),
          const SizedBox(height: Gap.md - 4),
          Container(
            padding: const EdgeInsets.all(Gap.md - 4),
            decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(8)),
            child: Column(children: [
              Row(children: [
                _valor(context, 'Valor original', moeda(d.valorOriginal)),
                _valor(context, 'Valor pendente', moeda(d.valorPendente), cor: d.valorPendente > 0 ? AppColors.danger : AppColors.success),
              ]),
              const SizedBox(height: Gap.sm),
              Row(children: [
                _valor(context, 'Emissão', data(d.dataEmissao)),
                _valor(context, 'Vencimento', data(d.dataVencimento), cor: vencida ? AppColors.danger : null),
              ]),
            ]),
          ),
          if (d.pagamentos.isNotEmpty) ...[
            const SizedBox(height: Gap.md),
            Text('Pagamentos realizados', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: Gap.xs),
            for (final p in d.pagamentos)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  const Icon(Icons.check_circle, size: 16, color: AppColors.success),
                  const SizedBox(width: Gap.xs),
                  Text(moeda(p.valorPago), style: const TextStyle(fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Text('${data(p.dataPagamento)} · ${p.metodo?.label ?? '—'}', style: Theme.of(context).textTheme.bodySmall),
                ]),
              ),
          ],
          const SizedBox(height: Gap.md - 4),
          const Spacer(),
          if (d.status.emAberto)
            FilledButton.icon(onPressed: onPagar, icon: const Icon(Icons.payments_outlined, size: 18), label: const Text('Registrar pagamento'))
          else
            OutlinedButton.icon(
              onPressed: null,
              icon: Icon(d.status.icon, size: 18),
              label: Text(d.status == Status.pago ? 'Dívida quitada' : 'Dívida cancelada'),
            ),
        ]),
      ),
    );
  }
}

class _PagamentoForm extends StatefulWidget {
  const _PagamentoForm({required this.divida, required this.cliente});
  final Divida divida;
  final String cliente;
  @override
  State<_PagamentoForm> createState() => _PagamentoFormState();
}

class _PagamentoFormState extends State<_PagamentoForm> {
  final _form = GlobalKey<FormState>();
  final _valor = TextEditingController();
  MetodoPagamento? _metodo;
  bool _salvando = false;

  double get _pendente => widget.divida.valorPendente;

  Future<void> _salvar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      await Api.instance.registrarPagamento(widget.divida.id, parseValor(_valor.text)!, _metodo!);
      if (!mounted) return;
      toast(context, 'Pagamento registrado com sucesso');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      toast(context, '$e', erro: true);
    }
  }

  Widget? _aviso() {
    final v = parseValor(_valor.text);
    if (v == null || v <= 0 || v > _pendente + .001) return null;
    final quita = (v - _pendente).abs() < .01;
    return Pill(
      cor: quita ? AppColors.success : AppColors.info,
      icon: quita ? Icons.check_circle : Icons.timelapse,
      label: quita ? 'Este pagamento quita a dívida' : 'Pagamento parcial · restará ${moeda(_pendente - v)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final aviso = _aviso();
    return AppFormDialog(
      titulo: 'Registrar pagamento',
      width: 440,
      busy: _salvando,
      acao: BusyButton(label: 'Confirmar pagamento', busy: _salvando, onPressed: _salvar),
      child: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            InfoRow('Dívida', '${widget.divida.vendaId == null ? '#${widget.divida.id}' : 'Venda #${widget.divida.vendaId}'} · ${widget.cliente}'),
            InfoRow('Valor pendente', moeda(_pendente), destaque: AppColors.danger),
            const SizedBox(height: Gap.md),
            TextFormField(
              controller: _valor,
              autofocus: !isMobile(context),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Valor pago *',
                prefixText: r'R$ ',
                suffixIcon: TextButton(
                  onPressed: () => setState(() => _valor.text = _pendente.toStringAsFixed(2).replaceAll('.', ',')),
                  child: const Text('Total'),
                ),
              ),
              onChanged: (_) => setState(() {}),
              validator: (t) {
                final v = parseValor(t ?? '');
                if (v == null || v <= 0) return 'Informe um valor válido';
                if (v > _pendente + .001) return 'Valor maior que o pendente';
                return null;
              },
            ),
            if (aviso != null) ...[const SizedBox(height: Gap.sm), Align(alignment: Alignment.centerLeft, child: aviso)],
            const SizedBox(height: Gap.md),
            DropdownButtonFormField<MetodoPagamento>(
              initialValue: _metodo,
              decoration: const InputDecoration(labelText: 'Método de pagamento *'),
              validator: (v) => v == null ? 'Selecione o método' : null,
              items: [for (final m in MetodoPagamento.values) DropdownMenuItem(value: m, child: Text(m.label))],
              onChanged: (v) => setState(() => _metodo = v),
            ),
          ]),
        ),
    );
  }
}
