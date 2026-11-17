import 'package:flutter/material.dart';
import '../../widgets/busca_sugestoes.dart';
import '../../core/catalogo_repository.dart';
import '../../core/entrada_numerica.dart';
import '../../core/validacoes.dart';
import '../../core/app_runtime.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

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

class NovaVendaForm extends StatelessWidget {
  const NovaVendaForm({super.key, required this.clientes});
  final List<Cliente> clientes;
  @override
  Widget build(BuildContext context) => _VendaForm(clientes: clientes);
}

class EditarVendaForm extends StatelessWidget {
  const EditarVendaForm({
    super.key,
    required this.venda,
    required this.clientes,
  });
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
  late final List<Cliente> _clientes = List.of(widget.clientes);
  late int? _cliente = widget.venda?.clienteId;
  late DateTime? _data = widget.venda?.dataHora?.toLocal();
  late final _valor = TextEditingController(
    text: widget.venda?.valorTotal.toStringAsFixed(2).replaceAll('.', ','),
  );
  late final _itens = <_ItemCtrl>[
    for (final i in widget.venda?.itens ?? <ItemVenda>[]) _ItemCtrl(i),
  ];
  AppRuntime? _runtime;
  int? _epocaRascunho;
  bool _descartarRascunho = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_runtime != null) return;
    _runtime = AppScope.of(context);
    _epocaRascunho = _runtime!.sessao.epoca;
    if (_editando) return;
    final d = _runtime!.rascunhos['venda'];
    if (d != null) {
      _valor.text = d['valor'] as String? ?? '';
      _cliente = d['clienteId'] as int?;
      for (final i in (d['itens'] as List? ?? [])) {
        final item = _ItemCtrl();
        item.desc.text = i['descricao'];
        item.qtd.text = i['quantidade'];
        item.valor.text = i['preco'];
        _itens.add(item);
      }
    }
  }

  bool _salvando = false, _dataAlterada = false;
  String? _erro;
  bool get _editando => widget.venda != null;
  bool get _bloqueado => widget.venda?.temPagamentos ?? false;
  int get _soma => _itens.fold(0, (t, i) => t + i.subtotalCentavos);
  int get _total => parseCentavos(_valor.text) ?? 0;
  @override
  void dispose() {
    if (!_editando &&
        _runtime != null &&
        _epocaRascunho == _runtime!.sessao.epoca) {
      if (_descartarRascunho) {
        _runtime!.rascunhos.remove('venda');
      } else {
        _runtime!.rascunhos['venda'] = {
          'valor': _valor.text,
          'clienteId': _cliente,
          'itens': [
            for (final i in _itens)
              {
                'descricao': i.desc.text,
                'quantidade': i.qtd.text,
                'preco': i.valor.text,
              },
          ],
        };
      }
    }
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
        await AppScope.read(context).vendas.atualizarVenda(
          widget.venda!.id,
          clienteId: _cliente!,
          valorTotal: _total / 100,
          versao: widget.venda!.versao,
          itens: itens,
          data: _dataAlterada ? _data : null,
        );
      } else {
        await AppScope.of(
          context,
        ).vendas.criarVenda(_cliente!, itens, valorTotal: _total / 100);
      }
      if (!mounted) return;
      toast(
        context,
        _editando
            ? 'Venda atualizada com sucesso'
            : 'Venda registrada com sucesso',
      );
      _descartarRascunho = true;
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
        BuscaSugestoes<ItemCatalogo>(
          controller: i.desc,
          label: 'Descrição *',
          texto: (item) => item.descricao,
          buscar: (q) async => (await AppScope.of(
            context,
          ).catalogoConsulta.listar(q: q)).content,
          onSelecionar: (item) => setState(() {
            if (item.precoSugerido != null) {
              i.valor.text = item.precoSugerido!
                  .toStringAsFixed(2)
                  .replaceAll('.', ',');
            }
          }),
          validator: (v) => (v ?? '').length > descricaoMax
              ? 'Descrição muito longa'
              : validarDescricao(v),
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
              BuscaSugestoes<Cliente>(
                label: 'Cliente *',
                enabled: !_bloqueado && !_salvando,
                inicial:
                    _clientes
                        .where((c) => c.id == _cliente)
                        .firstOrNull
                        ?.nome ??
                    '',
                texto: (c) => c.nome,
                buscar: (q) async => (await AppScope.read(
                  context,
                ).clientes.pagina(q: q)).content.where((c) => c.ativo).toList(),
                onChanged: (_) => setState(() => _cliente = null),
                onSelecionar: (c) => setState(() {
                  _cliente = c.id;
                  if (!_clientes.any((e) => e.id == c.id)) _clientes.add(c);
                }),
                validator: (_) => _cliente == null
                    ? 'Selecione um cliente nas sugestões'
                    : null,
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
              if (_itens.isNotEmpty && !_bloqueado)
                OutlinedButton.icon(
                  onPressed: _salvando
                      ? null
                      : () => setState(
                          () => _valor.text = (_soma / 100)
                              .toStringAsFixed(2)
                              .replaceAll('.', ','),
                        ),
                  icon: const Icon(Icons.calculate_outlined),
                  label: const Text('Usar soma dos itens'),
                ),

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
        onPressed: _salvando
            ? null
            : () {
                _descartarRascunho = true;
                Navigator.pop(context);
              },
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
