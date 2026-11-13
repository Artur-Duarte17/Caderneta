import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/comprovante.dart';
import '../core/documentos.dart';
import '../core/entrada_numerica.dart';
import '../core/validacoes.dart';
import '../core/app_runtime.dart';
import '../core/permissoes.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/historico_service.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

const periodos = {
  0: 'Todo o período',
  1: 'Hoje',
  7: 'Últimos 7 dias',
  30: 'Últimos 30 dias',
  90: 'Últimos 90 dias',
};

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
  int _page = 0;
  Status? _status;
  int _periodo = 0;

  @override
  Widget build(BuildContext context) => AsyncView<Snapshot>(
    cache: 'vendas',
    queryKey: (_page, _busca, _status, _periodo),
    mensagem: 'Carregando vendas',
    mensagemAtualizando: 'Buscando vendas',
    load: () => Snapshot.load(
      recurso: 'vendas',
      page: _page,
      q: _busca,
      status: _status?.backend,
      periodo: _periodo,
    ),
    builder: (context, s, _) {
      final termo = _busca.toLowerCase();
      final lista =
          s.vendas.where((v) {
            if (termo.isNotEmpty &&
                !s.nomeCliente(v.clienteId).toLowerCase().contains(termo) &&
                !'${v.id}'.contains(termo)) {
              return false;
            }
            if (_status != null && s.statusVenda(v) != _status) return false;
            return dentroDoPeriodo(v.dataHora, _periodo);
          }).toList()..sort(
            (a, b) => (b.dataHora ?? DateTime(0)).compareTo(
              a.dataHora ?? DateTime(0),
            ),
          );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            titulo: 'Vendas a prazo',
            subtitulo: '${s.total} venda(s) · Página ${_page + 1}',
            acoes: [
              FilledButton.icon(
                onPressed: () => _form(context, s, null),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nova venda'),
              ),
            ],
          ),
          Wrap(
            spacing: Gap.md,
            runSpacing: Gap.md,
            children: [
              FilterField(
                width: 300,
                child: SearchField(
                  hint: 'Buscar por cliente ou nº da venda',
                  onChanged: (v) => setState(() {
                    _busca = v;
                    _page = 0;
                  }),
                ),
              ),
              FilterField(
                child: Dropdown<Status?>(
                  label: 'Status',
                  value: _status,
                  itens: {
                    null: 'Todos',
                    for (final st in Status.values) st: st.label,
                  },
                  onChanged: (v) => setState(() {
                    _status = v;
                    _page = 0;
                  }),
                ),
              ),
              FilterField(
                child: Dropdown<int>(
                  label: 'Período',
                  value: _periodo,
                  itens: periodos,
                  onChanged: (v) => setState(() {
                    _periodo = v;
                    _page = 0;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          OperacaoPaginador(
            page: _page,
            total: s.total,
            last: s.last,
            onPage: (p) => setState(() => _page = p),
          ),
          if (lista.isEmpty)
            const EmptyState(
              icon: Icons.receipt_long,
              titulo: 'Nenhuma venda encontrada',
              mensagem: 'Ajuste os filtros ou registre uma nova venda.',
            )
          else
            ResponsiveGrid(
              minWidth: 300,
              children: [
                for (final v in lista)
                  _VendaCard(
                    venda: v,
                    cliente: s.nomeCliente(v.clienteId),
                    status: s.statusVenda(v),
                    onDetalhes: () => _detalhes(context, s, v),
                    onEditar:
                        pode(
                          AppScope.of(context).sessao.usuario?.perfil,
                          Acao.editarVenda,
                        )
                        ? () => _form(context, s, v)
                        : null,
                  ),
              ],
            ),
        ],
      );
    },
  );

  void _detalhes(BuildContext context, Snapshot s, Venda v) {
    final d = s.divida(v.dividaId);
    showAppDialog(
      context,
      titulo: 'Venda #${v.id}',
      width: 640,
      builder: (ctx, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.nomeCliente(v.clienteId),
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                ),
                StatusBadge(d?.status),
              ],
            ),
            const SizedBox(height: Gap.sm),
            InfoRow('Data da venda', dataHora(v.dataHora)),
            InfoRow('Valor total', moeda(v.valorTotal)),
            Wrap(
              spacing: Gap.md,
              children: [
                OutlinedButton.icon(
                  onPressed: () =>
                      abrirComprovante('/vendas/${v.id}/comprovante'),
                  icon: const Icon(Icons.print),
                  label: const Text('Comprovante'),
                ),
                if (AppScope.of(context).sessao.usuario?.perfil ==
                        Perfil.gerente &&
                    !v.temPagamentos)
                  TextButton(
                    onPressed: () async {
                      final confirmar = await showDialog<bool>(
                        context: ctx,
                        builder: (c) => AlertDialog(
                          title: const Text('Excluir venda?'),
                          content: const Text(
                            'A venda e sua dívida sem pagamentos serão excluídas. A auditoria será preservada.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text('Cancelar'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('Excluir'),
                            ),
                          ],
                        ),
                      );
                      if (confirmar == true && ctx.mounted) {
                        try {
                          await executarComCarregamento(
                            ctx,
                            'Excluindo venda',
                            () => Api.instance.excluirVenda(v.id),
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          HistoricoService.instance.dadosAlterados();
                        } catch (e) {
                          if (ctx.mounted) toast(ctx, '$e', erro: true);
                        }
                      }
                    },
                    child: const Text('Excluir venda'),
                  ),
              ],
            ),
            InfoRow(
              'Soma dos itens',
              moeda(v.itens.fold<double>(0, (t, i) => t + i.subtotal)),
            ),
            InfoRow(
              'Valor não detalhado',
              moeda(
                v.valorTotal -
                    v.itens.fold<double>(0, (t, i) => t + i.subtotal),
              ),
            ),
            if (d != null) ...[
              InfoRow(
                'Vencimento',
                data(d.dataVencimento),
                destaque: d.status == Status.vencida ? AppColors.danger : null,
              ),
              InfoRow(
                'Valor pendente',
                moeda(d.valorPendente),
                destaque: d.valorPendente > 0
                    ? AppColors.danger
                    : AppColors.success,
              ),
            ],
            const SizedBox(height: Gap.md),
            const FormSection('Itens'),
            if (v.itens.isEmpty)
              Text(
                'Nenhum item registrado',
                style: Theme.of(ctx).textTheme.bodySmall,
              )
            else
              AppTable(
                colunas: const ['Produto', 'Qtd', 'Unitário', 'Subtotal'],
                numericas: const {1, 2, 3},
                linhas: [
                  for (final i in v.itens)
                    [
                      Text(i.descricao),
                      Text('${i.quantidade}'),
                      Text(moeda(i.precoUnitario)),
                      Text(
                        moeda(i.subtotal),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                ],
              ),
          ],
        );
      },
    );
  }

  Future<void> _form(BuildContext context, Snapshot s, Venda? v) async {
    final clientes = await Api.instance.clientes();
    if (v != null && !clientes.any((c) => c.id == v.clienteId)) {
      clientes.add(await Api.instance.cliente(v.clienteId));
    }
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => v == null
          ? _NovaVendaForm(clientes: clientes)
          : _EditarVendaForm(venda: v, clientes: clientes),
    );
    if (ok == true) HistoricoService.instance.dadosAlterados();
  }
}

class _VendaCard extends StatelessWidget {
  const _VendaCard({
    required this.venda,
    required this.cliente,
    required this.status,
    required this.onDetalhes,
    required this.onEditar,
  });
  final Venda venda;
  final String cliente;
  final Status? status;
  final VoidCallback onDetalhes;
  final VoidCallback? onEditar;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(Gap.ml),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Venda #${venda.id}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      data(venda.dataNegocio ?? venda.dataHora),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              StatusBadge(status),
            ],
          ),
          const SizedBox(height: Gap.md),
          Row(
            children: [
              const Icon(
                Icons.person_outline,
                size: 18,
                color: AppColors.muted,
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  cliente,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.xs),
          Text(
            moeda(venda.valorTotal),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: Gap.md),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDetalhes,
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('Detalhes'),
                ),
              ),
              if (onEditar != null) const SizedBox(width: Gap.sm),
              if (onEditar != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEditar,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Editar'),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

DropdownButtonFormField<int> _clienteSelect(
  List<Cliente> clientes,
  int? valor,
  ValueChanged<int?> onChanged,
) => DropdownButtonFormField<int>(
  initialValue: valor,
  isExpanded: true,
  decoration: const InputDecoration(labelText: 'Cliente *'),
  validator: (v) => v == null ? 'Selecione um cliente' : null,
  items: [
    for (final c in [...clientes]..sort((a, b) => a.nome.compareTo(b.nome)))
      DropdownMenuItem(
        value: c.id,
        child: Text(
          '${c.nome}${c.telefone == null ? '' : ' · ${exibirTelefone(c.telefone)}'}',
        ),
      ),
  ],
  onChanged: onChanged,
);

class _ItemCtrl {
  _ItemCtrl([ItemVenda? item]) {
    desc.text = item?.descricao ?? '';
    qtd.text = '${item?.quantidade ?? 1}';
    valor.text = item == null
        ? ''
        : item.precoUnitario.toStringAsFixed(2).replaceAll('.', ',');
  }
  final desc = TextEditingController(),
      qtd = TextEditingController(),
      valor = TextEditingController();
  int get subtotalCentavos =>
      (int.tryParse(qtd.text) ?? 0) * (parseCentavos(valor.text) ?? 0);
  void dispose() {
    desc.dispose();
    qtd.dispose();
    valor.dispose();
  }
}

class _NovaVendaForm extends StatelessWidget {
  const _NovaVendaForm({required this.clientes});
  final List<Cliente> clientes;
  @override
  Widget build(BuildContext context) => _VendaForm(clientes: clientes);
}

class _EditarVendaForm extends StatelessWidget {
  const _EditarVendaForm({required this.venda, required this.clientes});
  final Venda venda;
  final List<Cliente> clientes;
  @override
  Widget build(BuildContext context) =>
      _VendaForm(clientes: clientes, venda: venda);
}

class _VendaForm extends StatefulWidget {
  const _VendaForm({required this.clientes, this.venda});
  final List<Cliente> clientes;
  final Venda? venda;
  @override
  State<_VendaForm> createState() => _VendaFormState();
}

class _VendaFormState extends State<_VendaForm> {
  final _form = GlobalKey<FormState>();
  late List<Cliente> _clientes = List.of(widget.clientes);
  int _buscaCliente = 0;
  bool _buscandoClientes = false;

  Future<void> _buscarClientes(String q) async {
    final pedido = ++_buscaCliente;
    setState(() => _buscandoClientes = true);
    try {
      final encontrados = (await Api.instance.pagina(
        '/clientes',
        Cliente.fromJson,
        q: q,
        size: 100,
      )).content;
      if (!mounted || pedido != _buscaCliente) return;
      final atual = _clientes.where((c) => c.id == _cliente).firstOrNull;
      if (atual != null && !encontrados.any((c) => c.id == atual.id)) {
        encontrados.add(atual);
      }
      setState(() => _clientes = encontrados);
    } catch (e) {
      if (mounted) toast(context, '$e', erro: true);
    } finally {
      // Só a busca mais recente desliga o indicador.
      if (mounted && pedido == _buscaCliente) {
        setState(() => _buscandoClientes = false);
      }
    }
  }

  late int? _cliente = widget.venda?.clienteId;
  late DateTime? _data = widget.venda?.dataHora?.toLocal();
  late final _valor = TextEditingController(
    text: widget.venda?.valorTotal.toStringAsFixed(2).replaceAll('.', ','),
  );
  late final _itens = <_ItemCtrl>[
    for (final i in widget.venda?.itens ?? <ItemVenda>[]) _ItemCtrl(i),
  ];
  bool _salvando = false, _dataAlterada = false;
  String? _erro;
  bool get _editando => widget.venda != null;
  bool get _bloqueado => widget.venda?.temPagamentos ?? false;
  int get _soma => _itens.fold(0, (t, i) => t + i.subtotalCentavos);
  int get _total => parseCentavos(_valor.text) ?? 0;
  @override
  void dispose() {
    _valor.dispose();
    for (final i in _itens) {
      i.dispose();
    }
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_salvando || !_form.currentState!.validate()) return;
    if (_soma > _total) {
      setState(
        () => _erro = 'A soma dos itens não pode ultrapassar o total da venda.',
      );
      return;
    }
    setState(() {
      _salvando = true;
      _erro = null;
    });
    final itens = [
      for (final i in _itens)
        ItemVenda(
          descricao: i.desc.text.trim(),
          quantidade: int.parse(i.qtd.text),
          precoUnitario: parseCentavos(i.valor.text)! / 100,
        ),
    ];
    try {
      if (_editando) {
        await Api.instance.atualizarVenda(
          widget.venda!.id,
          clienteId: _cliente!,
          valorTotal: _total / 100,
          versao: widget.venda!.versao,
          itens: itens,
          data: _dataAlterada ? _data : null,
        );
      } else {
        await Api.instance.criarVenda(
          _cliente!,
          itens,
          valorTotal: _total / 100,
        );
      }
      if (!mounted) return;
      toast(
        context,
        _editando
            ? 'Venda atualizada com sucesso'
            : 'Venda registrada com sucesso',
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _salvando = false;
          _erro = '$e';
        });
      }
    }
  }

  Widget _item(int idx, _ItemCtrl i) => Container(
    margin: const EdgeInsets.only(bottom: Gap.md),
    padding: const EdgeInsets.all(Gap.md),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(child: Text('Item ${idx + 1}')),
            Expanded(child: Text(moeda(i.subtotalCentavos / 100))),
            IconButton(
              tooltip: 'Remover item',
              onPressed: _salvando
                  ? null
                  : () => setState(() => _itens.removeAt(idx).dispose()),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        TextFormField(
          controller: i.desc,
          decoration: const InputDecoration(labelText: 'Descrição *'),
          maxLength: descricaoMax,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: filtroDescricao,
          validator: validarDescricao,
        ),
        const SizedBox(height: Gap.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: i.qtd,
                decoration: const InputDecoration(labelText: 'Qtd *'),
                keyboardType: TextInputType.number,
                inputFormatters: somenteInteiro(maxDigitos: 7),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return n == null || n < 1 || n > 1000000
                      ? 'Quantidade inválida'
                      : null;
                },
              ),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: i.valor,
                decoration: const InputDecoration(
                  labelText: 'Valor unitário *',
                  prefixText: r'R$ ',
                ),
                keyboardType: tecladoValor,
                inputFormatters: somenteValorMonetario(),
                onChanged: (_) => setState(() {}),
                validator: (v) => (parseCentavos(v ?? '') ?? 0) <= 0
                    ? 'Informe valor com até 2 casas'
                    : null,
              ),
            ),
          ],
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      _editando ? 'Editar venda #${widget.venda!.id}' : 'Nova venda a prazo',
    ),
    content: SizedBox(
      width: 600,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const LegendaObrigatorios(),
              if (_erro != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: Gap.md),
                  child: Text(
                    _erro!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              if (_bloqueado)
                const Padding(
                  padding: EdgeInsets.only(bottom: Gap.md),
                  child: Text(
                    'Esta venda possui pagamentos. Você pode corrigir apenas o detalhamento dos itens.',
                  ),
                ),
              if (!_bloqueado) ...[
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Buscar cliente por nome ou CPF',
                    suffixIcon: _buscandoClientes
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                    helper: _buscandoClientes
                        ? const TextoCarregando('Buscando clientes')
                        : null,
                  ),
                  onChanged: _buscarClientes,
                ),
                const SizedBox(height: Gap.sm),
              ],
              AbsorbPointer(
                absorbing: _bloqueado || _salvando,
                child: _clienteSelect(
                  _clientes,
                  _cliente,
                  (v) => setState(() => _cliente = v),
                ),
              ),
              const SizedBox(height: Gap.md),
              TextFormField(
                controller: _valor,
                enabled: !_bloqueado && !_salvando,
                decoration: const InputDecoration(
                  labelText: 'Valor total *',
                  prefixText: r'R$ ',
                ),
                keyboardType: tecladoValor,
                inputFormatters: somenteValorMonetario(),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final n = parseCentavos(v ?? '');
                  return n == null || n <= 0
                      ? 'Informe valor positivo com até 2 casas decimais'
                      : null;
                },
              ),
              if (_editando) ...[
                const SizedBox(height: Gap.md),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(data(_data)),
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                  ),
                  onPressed: _bloqueado || _salvando
                      ? null
                      : () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _data ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (d != null) {
                            final t = _data ?? DateTime.now();
                            setState(() {
                              _data = DateTime(
                                d.year,
                                d.month,
                                d.day,
                                t.hour,
                                t.minute,
                                t.second,
                                t.millisecond,
                                t.microsecond,
                              );
                              _dataAlterada = true;
                            });
                          }
                        },
                ),
              ],
              const SizedBox(height: Gap.md),
              const FormSection('Itens opcionais'),
              const Text(
                'Registre rapidamente pelo valor total. Você pode completar os itens depois.',
              ),
              const SizedBox(height: Gap.md),
              for (var i = 0; i < _itens.length; i++) _item(i, _itens[i]),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _salvando
                      ? null
                      : () => setState(() => _itens.add(_ItemCtrl())),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Adicionar item'),
                ),
              ),
              const SizedBox(height: Gap.md),
              InfoRow('Soma dos itens', moeda(_soma / 100)),
              InfoRow(
                'Valor não detalhado',
                moeda((_total - _soma) / 100),
                destaque: _soma > _total ? AppColors.danger : null,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _salvando ? null : () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      BusyButton(
        label: _editando ? 'Salvar alterações' : 'Registrar venda',
        busyLabel: _editando ? 'Salvando' : 'Registrando venda',
        busy: _salvando,
        onPressed: _salvar,
      ),
    ],
  );
}
