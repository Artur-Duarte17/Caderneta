import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/notificacoes_service.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

const periodos = {0: 'Todo o período', 1: 'Hoje', 7: 'Últimos 7 dias', 30: 'Últimos 30 dias', 90: 'Últimos 90 dias'};

bool dentroDoPeriodo(DateTime? d, int dias) {
  if (dias == 0) return true;
  if (d == null) return false;
  return !d.isBefore(hoje().subtract(Duration(days: dias - 1)));
}

class VendasPage extends StatefulWidget {
  const VendasPage({super.key});
  @override
  State<VendasPage> createState() => _VendasPageState();
}

class _VendasPageState extends State<VendasPage> {
  String _busca = '';
  Status? _status;
  int _periodo = 0;

  @override
  Widget build(BuildContext context) => AsyncView<Snapshot>(
        load: Snapshot.load,
        builder: (context, s, _) {
          final termo = _busca.toLowerCase();
          final lista = s.vendas.where((v) {
            if (termo.isNotEmpty && !s.nomeCliente(v.clienteId).toLowerCase().contains(termo) && !'${v.id}'.contains(termo)) {
              return false;
            }
            if (_status != null && s.statusVenda(v) != _status) return false;
            return dentroDoPeriodo(v.dataHora, _periodo);
          }).toList()
            ..sort((a, b) => (b.dataHora ?? DateTime(0)).compareTo(a.dataHora ?? DateTime(0)));

          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            PageHeader(
              titulo: 'Vendas a prazo',
              subtitulo: '${lista.length} de ${s.vendas.length} venda(s) · ${moeda(lista.fold<double>(0, (t, v) => t + v.valorTotal))}',
              acoes: [
                FilledButton.icon(
                  onPressed: s.clientes.isEmpty ? null : () => _form(context, s, null),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nova venda'),
                ),
              ],
            ),
            Wrap(spacing: Gap.md, runSpacing: Gap.md, children: [
              FilterField(width: 300, child: SearchField(hint: 'Buscar por cliente ou nº da venda', onChanged: (v) => setState(() => _busca = v))),
              FilterField(
                child: Dropdown<Status?>(
                  label: 'Status',
                  value: _status,
                  itens: {null: 'Todos', for (final st in Status.values) st: st.label},
                  onChanged: (v) => setState(() => _status = v),
                ),
              ),
              FilterField(
                child: Dropdown<int>(label: 'Período', value: _periodo, itens: periodos, onChanged: (v) => setState(() => _periodo = v)),
              ),
            ]),
            const SizedBox(height: Gap.lg),
            if (lista.isEmpty)
              const EmptyState(icon: Icons.receipt_long, titulo: 'Nenhuma venda encontrada', mensagem: 'Ajuste os filtros ou registre uma nova venda.')
            else
              ResponsiveGrid(minWidth: 300, children: [
                for (final v in lista)
                  _VendaCard(
                    venda: v,
                    cliente: s.nomeCliente(v.clienteId),
                    status: s.statusVenda(v),
                    onDetalhes: () => _detalhes(context, s, v),
                    onEditar: () => _form(context, s, v),
                  ),
              ]),
          ]);
        },
      );

  void _detalhes(BuildContext context, Snapshot s, Venda v) {
    final d = s.divida(v.dividaId);
    showAppDialog(context, titulo: 'Venda #${v.id}', width: 640, builder: (ctx, _) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [Expanded(child: Text(s.nomeCliente(v.clienteId), style: Theme.of(ctx).textTheme.titleMedium)), StatusBadge(d?.status)]),
        const SizedBox(height: Gap.sm),
        InfoRow('Data da venda', dataHora(v.dataHora)),
        InfoRow('Valor total', moeda(v.valorTotal)),
        if (d != null) ...[
          InfoRow('Vencimento', data(d.dataVencimento), destaque: d.status == Status.vencida ? AppColors.danger : null),
          InfoRow('Valor pendente', moeda(d.valorPendente), destaque: d.valorPendente > 0 ? AppColors.danger : AppColors.success),
        ],
        const SizedBox(height: Gap.md),
        const FormSection('Itens'),
        if (v.itens.isEmpty)
          Text('Nenhum item registrado', style: Theme.of(ctx).textTheme.bodySmall)
        else
          AppTable(
            colunas: const ['Produto', 'Qtd', 'Unitário', 'Subtotal'],
            numericas: const {1, 2, 3},
            linhas: [
              for (final i in v.itens)
                [Text(i.descricao), Text('${i.quantidade}'), Text(moeda(i.precoUnitario)), Text(moeda(i.subtotal), style: const TextStyle(fontWeight: FontWeight.w600))],
            ],
          ),
      ]);
    });
  }

  Future<void> _form(BuildContext context, Snapshot s, Venda? v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => v == null ? _NovaVendaForm(clientes: s.clientes) : _EditarVendaForm(venda: v, clientes: s.clientes),
    );
    if (ok == true) NotificacoesService.instance.dadosAlterados();
  }
}

class _VendaCard extends StatelessWidget {
  const _VendaCard({required this.venda, required this.cliente, required this.status, required this.onDetalhes, required this.onEditar});
  final Venda venda;
  final String cliente;
  final Status? status;
  final VoidCallback onDetalhes, onEditar;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(Gap.md + 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Venda #${venda.id}', style: Theme.of(context).textTheme.titleMedium),
                  Text(data(venda.dataHora), style: Theme.of(context).textTheme.bodySmall),
                ]),
              ),
              StatusBadge(status),
            ]),
            const SizedBox(height: Gap.md),
            Row(children: [
              const Icon(Icons.person_outline, size: 18, color: AppColors.muted),
              const SizedBox(width: Gap.sm),
              Expanded(child: Text(cliente, maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: Gap.xs),
            Text(moeda(venda.valorTotal), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary)),
            const SizedBox(height: Gap.md),
            const Spacer(),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: onDetalhes, icon: const Icon(Icons.visibility_outlined, size: 18), label: const Text('Detalhes'))),
              const SizedBox(width: Gap.sm),
              Expanded(child: OutlinedButton.icon(onPressed: onEditar, icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Editar'))),
            ]),
          ]),
        ),
      );
}

DropdownButtonFormField<int> _clienteSelect(List<Cliente> clientes, int? valor, ValueChanged<int?> onChanged) =>
    DropdownButtonFormField<int>(
      initialValue: valor,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Cliente *'),
      validator: (v) => v == null ? 'Selecione um cliente' : null,
      items: [
        for (final c in [...clientes]..sort((a, b) => a.nome.compareTo(b.nome)))
          DropdownMenuItem(value: c.id, child: Text('${c.nome}${c.telefone == null ? '' : ' · ${c.telefone}'}')),
      ],
      onChanged: onChanged,
    );

class _ItemCtrl {
  final desc = TextEditingController();
  final qtd = TextEditingController(text: '1');
  final valor = TextEditingController();
  double get subtotal => (int.tryParse(qtd.text) ?? 0) * (parseValor(valor.text) ?? 0);
}

class _NovaVendaForm extends StatefulWidget {
  const _NovaVendaForm({required this.clientes});
  final List<Cliente> clientes;
  @override
  State<_NovaVendaForm> createState() => _NovaVendaFormState();
}

class _NovaVendaFormState extends State<_NovaVendaForm> {
  final _form = GlobalKey<FormState>();
  int? _cliente;
  final _itens = [_ItemCtrl()];
  bool _salvando = false;

  double get _total => _itens.fold<double>(0, (t, i) => t + i.subtotal);

  Future<void> _salvar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      await Api.instance.criarVenda(_cliente!, [
        for (final i in _itens)
          ItemVenda(descricao: i.desc.text.trim(), quantidade: int.parse(i.qtd.text), precoUnitario: parseValor(i.valor.text)!),
      ]);
      if (!mounted) return;
      toast(context, 'Venda registrada com sucesso');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      toast(context, '$e', erro: true);
    }
  }

  Widget _item(int idx, _ItemCtrl i) => Container(
        margin: const EdgeInsets.only(bottom: Gap.md),
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(8)),
        child: Column(children: [
          Row(children: [
            Text('Item ${idx + 1}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(moeda(i.subtotal), style: const TextStyle(color: AppColors.muted)),
            if (_itens.length > 1)
              IconButton(
                tooltip: 'Remover item',
                icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                onPressed: () => setState(() => _itens.removeAt(idx)),
              ),
          ]),
          const SizedBox(height: Gap.sm),
          TextFormField(
            controller: i.desc,
            decoration: const InputDecoration(labelText: 'Descrição *'),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Informe a descrição' : null,
          ),
          const SizedBox(height: Gap.md),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 100,
              child: TextFormField(
                controller: i.qtd,
                decoration: const InputDecoration(labelText: 'Qtd *'),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                validator: (v) => (int.tryParse(v ?? '') ?? 0) < 1 ? 'Inválida' : null,
              ),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: TextFormField(
                controller: i.valor,
                decoration: const InputDecoration(labelText: 'Valor unitário *', prefixText: r'R$ '),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                validator: (v) => (parseValor(v ?? '') ?? 0) <= 0 ? 'Informe um valor' : null,
              ),
            ),
          ]),
        ]),
      );

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Nova venda a prazo'),
        content: SizedBox(
          width: 600,
          child: Form(
            key: _form,
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _clienteSelect(widget.clientes, _cliente, (v) => setState(() => _cliente = v)),
                const SizedBox(height: Gap.sm),
                Text('O vencimento é calculado pelo prazo padrão do cliente.', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: Gap.md),
                const FormSection('Itens da venda'),
                for (var i = 0; i < _itens.length; i++) _item(i, _itens[i]),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _itens.add(_ItemCtrl())),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Adicionar item'),
                  ),
                ),
              ]),
            ),
          ),
        ),
        actions: [
          Text('Total: ${moeda(_total)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(width: Gap.md),
          TextButton(onPressed: _salvando ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
          BusyButton(label: 'Registrar venda', busy: _salvando, onPressed: _salvar),
        ],
      );
}

class _EditarVendaForm extends StatefulWidget {
  const _EditarVendaForm({required this.venda, required this.clientes});
  final Venda venda;
  final List<Cliente> clientes;
  @override
  State<_EditarVendaForm> createState() => _EditarVendaFormState();
}

class _EditarVendaFormState extends State<_EditarVendaForm> {
  final _form = GlobalKey<FormState>();
  late int? _cliente = widget.venda.clienteId;
  late DateTime? _data = widget.venda.dataHora;
  late final _valor = TextEditingController(text: widget.venda.valorTotal.toStringAsFixed(2).replaceAll('.', ','));
  bool _salvando = false;

  Future<void> _salvar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      await Api.instance.atualizarVenda(widget.venda.id, clienteId: _cliente!, valorTotal: parseValor(_valor.text)!, data: _data);
      if (!mounted) return;
      toast(context, 'Venda atualizada com sucesso');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      toast(context, '$e', erro: true);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Editar venda #${widget.venda.id}'),
        content: SizedBox(
          width: 480,
          child: Form(
            key: _form,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _clienteSelect(widget.clientes, _cliente, (v) => setState(() => _cliente = v)),
              const SizedBox(height: Gap.md),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _data ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (d != null) setState(() => _data = d);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Data da venda', suffixIcon: Icon(Icons.calendar_today, size: 18)),
                  child: Text(data(_data)),
                ),
              ),
              const SizedBox(height: Gap.md),
              TextFormField(
                controller: _valor,
                decoration: const InputDecoration(labelText: 'Valor total *', prefixText: r'R$ '),
                validator: (v) => (parseValor(v ?? '') ?? 0) <= 0 ? 'Informe um valor válido' : null,
              ),
              if (widget.venda.itens.isNotEmpty) ...[
                const SizedBox(height: Gap.md),
                Text('Itens: ${widget.venda.itens.map((i) => '${i.descricao} (${i.quantidade}x)').join(', ')}',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: _salvando ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
          BusyButton(label: 'Salvar alterações', busy: _salvando, onPressed: _salvar),
        ],
      );
}
