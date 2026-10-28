import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/notificacoes_service.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class ClientesPage extends StatefulWidget {
  const ClientesPage({super.key});
  @override
  State<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends State<ClientesPage> {
  String _busca = '';

  @override
  Widget build(BuildContext context) => AsyncView<Snapshot>(
        load: Snapshot.load,
        builder: (context, s, reload) {
          final termo = _busca.toLowerCase();
          final lista = s.clientes
              .where((c) => termo.isEmpty || c.nome.toLowerCase().contains(termo) || (c.telefone ?? '').contains(termo))
              .toList()
            ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            PageHeader(
              titulo: 'Clientes',
              subtitulo: '${s.clientes.length} cliente(s) cadastrado(s)',
              acoes: [
                FilledButton.icon(
                  onPressed: () => abrirFormCliente(context),
                  icon: const Icon(Icons.person_add_alt, size: 18),
                  label: Text(isMobile(context) ? 'Novo' : 'Novo cliente'),
                ),
              ],
            ),
            FilterField(width: 360, child: SearchField(hint: 'Buscar por nome ou telefone', onChanged: (v) => setState(() => _busca = v))),
            const SizedBox(height: Gap.md),
            if (lista.isEmpty)
              const EmptyState(icon: Icons.person_off_outlined, titulo: 'Nenhum cliente encontrado')
            else
              ResponsiveGrid(minWidth: 280, spacing: Gap.md - 4, children: [
                for (final c in lista)
                  _ClienteCard(
                    cliente: c,
                    saldo: s.saldoDevedor(c.id),
                    atraso: s.emAtraso(c.id),
                    onDetalhes: () => _detalhes(context, s, c),
                    onEditar: () => abrirFormCliente(context, c),
                  ),
              ]),
          ]);
        },
      );

  void _detalhes(BuildContext context, Snapshot s, Cliente c) {
    final saldo = s.saldoDevedor(c.id);
    final disponivel = c.limiteCredito - saldo;
    showAppDialog(context, titulo: 'Detalhes do cliente', builder: (ctx) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Avatar(c.nome, size: 48),
          const SizedBox(width: Gap.md),
          Expanded(child: Text(c.nome, style: Theme.of(ctx).textTheme.titleLarge)),
          _situacao(saldo, s.emAtraso(c.id)),
        ]),
        const SizedBox(height: Gap.md),
        const FormSection('Informações pessoais'),
        InfoRow('Telefone', c.telefone ?? 'Não informado'),
        InfoRow('E-mail', c.email ?? 'Não informado'),
        InfoRow('CPF/CNPJ', c.cpf ?? 'Não informado'),
        InfoRow('Endereço', c.endereco ?? 'Não informado'),
        const SizedBox(height: Gap.sm),
        const FormSection('Situação financeira'),
        InfoRow('Limite de crédito', moeda(c.limiteCredito)),
        InfoRow('Saldo devedor', moeda(saldo), destaque: saldo > 0 ? AppColors.danger : AppColors.success),
        InfoRow('Crédito disponível', moeda(disponivel), destaque: disponivel < 0 ? AppColors.danger : null),
        InfoRow('Prazo padrão', '${c.prazoPagamentoPadraoDias} dias'),
      ]);
    });
  }

}

/// Abre o formulário de cliente (novo quando [c] é nulo). Usado também pela Visão Geral.
Future<void> abrirFormCliente(BuildContext context, [Cliente? c]) async {
  final ok = await showDialog<bool>(context: context, builder: (_) => _ClienteForm(cliente: c));
  if (ok == true) NotificacoesService.instance.dadosAlterados();
}

Widget _situacao(double saldo, bool atraso) {
  if (atraso) return const Pill(label: 'Em atraso', cor: AppColors.danger, icon: Icons.error);
  if (saldo > 0) return const Pill(label: 'Devendo', cor: AppColors.warning, icon: Icons.schedule);
  return const Pill(label: 'Em dia', cor: AppColors.success, icon: Icons.check_circle);
}

class _ClienteCard extends StatelessWidget {
  const _ClienteCard({required this.cliente, required this.saldo, required this.atraso, required this.onDetalhes, required this.onEditar});
  final Cliente cliente;
  final double saldo;
  final bool atraso;
  final VoidCallback onDetalhes, onEditar;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Avatar(cliente.nome),
              const SizedBox(width: Gap.md - 4),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(cliente.nome, style: Theme.of(context).textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(cliente.telefone ?? 'Sem telefone', style: Theme.of(context).textTheme.bodySmall),
                ]),
              ),
            ]),
            const SizedBox(height: Gap.md - 4),
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Saldo devedor', style: Theme.of(context).textTheme.bodySmall),
                  Text(moeda(saldo),
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700, color: saldo > 0 ? AppColors.danger : AppColors.success)),
                ]),
              ),
              _situacao(saldo, atraso),
            ]),
            const SizedBox(height: Gap.md - 4),
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

class _ClienteForm extends StatefulWidget {
  const _ClienteForm({this.cliente});
  final Cliente? cliente;
  @override
  State<_ClienteForm> createState() => _ClienteFormState();
}

class _ClienteFormState extends State<_ClienteForm> {
  final _form = GlobalKey<FormState>();
  late final _nome = TextEditingController(text: widget.cliente?.nome);
  late final _tel = TextEditingController(text: widget.cliente?.telefone);
  late final _email = TextEditingController(text: widget.cliente?.email);
  late final _cpf = TextEditingController(text: widget.cliente?.cpf);
  late final _end = TextEditingController(text: widget.cliente?.endereco);
  late final _limite = TextEditingController(text: widget.cliente?.limiteCredito.toStringAsFixed(2).replaceAll('.', ','));
  late final _prazo = TextEditingController(text: '${widget.cliente?.prazoPagamentoPadraoDias ?? 30}');
  final _fNome = TextEditingController(), _fTel = TextEditingController(), _fEmail = TextEditingController();
  final _fCpf = TextEditingController(), _fEnd = TextEditingController();
  bool _temFiador = false;
  bool _salvando = false;

  bool get _editando => widget.cliente != null;

  String? _obrigatorio(String? v) => (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null;
  String? _opt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _salvar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _salvando = true);
    final dados = {
      'nome': _nome.text.trim(),
      'telefone': _tel.text.trim(),
      'email': _opt(_email),
      'endereco': _opt(_end),
      'limiteCredito': parseValor(_limite.text) ?? 0,
      'prazoPagamentoPadraoDias': int.tryParse(_prazo.text) ?? 30,
    };
    try {
      if (_editando) {
        await Api.instance.atualizarCliente(widget.cliente!.id, dados);
      } else {
        final novo = await Api.instance.criarCliente({...dados, 'cpf': _cpf.text.trim()});
        if (_temFiador) {
          await Api.instance.criarFiadorParaCliente(novo.id, {
            'nome': _fNome.text.trim(),
            'telefone': _fTel.text.trim(),
            'email': _opt(_fEmail),
            'cpf': _opt(_fCpf),
            'endereco': _opt(_fEnd),
          });
        }
      }
      if (!mounted) return;
      toast(context, _editando ? 'Cliente atualizado com sucesso' : 'Cliente cadastrado com sucesso');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      toast(context, '$e', erro: true);
    }
  }

  Widget _row(List<Widget> campos) => LayoutBuilder(
        builder: (_, c) => c.maxWidth < 480
            ? Column(children: [for (final f in campos) Padding(padding: const EdgeInsets.only(bottom: Gap.md), child: f)])
            : Padding(
                padding: const EdgeInsets.only(bottom: Gap.md),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (var i = 0; i < campos.length; i++) ...[
                    if (i > 0) const SizedBox(width: Gap.md),
                    Expanded(child: campos[i]),
                  ],
                ]),
              ),
      );

  @override
  Widget build(BuildContext context) => AppFormDialog(
        titulo: _editando ? 'Editar cliente' : 'Novo cliente',
        width: 600,
        busy: _salvando,
        acao: BusyButton(label: _editando ? 'Salvar alterações' : 'Cadastrar', busy: _salvando, onPressed: _salvar),
        child: Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const FormSection('Dados pessoais'),
                _row([TextFormField(controller: _nome, decoration: const InputDecoration(labelText: 'Nome completo *'), validator: _obrigatorio)]),
                _row([
                  TextFormField(controller: _tel, decoration: const InputDecoration(labelText: 'Telefone *'), keyboardType: TextInputType.phone, validator: _obrigatorio),
                  TextFormField(controller: _email, decoration: const InputDecoration(labelText: 'E-mail'), keyboardType: TextInputType.emailAddress),
                ]),
                _row([
                  TextFormField(
                    controller: _cpf,
                    enabled: !_editando,
                    decoration: InputDecoration(labelText: 'CPF/CNPJ *', helperText: _editando ? 'Não pode ser alterado' : null),
                    validator: _editando ? null : _obrigatorio,
                  ),
                ]),
                _row([TextFormField(controller: _end, decoration: const InputDecoration(labelText: 'Endereço'), maxLines: 2)]),
                const FormSection('Crédito'),
                _row([
                  TextFormField(controller: _limite, decoration: const InputDecoration(labelText: 'Limite de crédito', prefixText: r'R$ '),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                  TextFormField(controller: _prazo, decoration: const InputDecoration(labelText: 'Prazo de pagamento', suffixText: 'dias'), keyboardType: TextInputType.number),
                ]),
                if (!_editando) ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Adicionar fiador'),
                    value: _temFiador,
                    onChanged: (v) => setState(() => _temFiador = v),
                  ),
                  if (_temFiador) ...[
                    const FormSection('Fiador'),
                    _row([TextFormField(controller: _fNome, decoration: const InputDecoration(labelText: 'Nome completo *'), validator: _obrigatorio)]),
                    _row([
                      TextFormField(controller: _fTel, decoration: const InputDecoration(labelText: 'Telefone *'), keyboardType: TextInputType.phone, validator: _obrigatorio),
                      TextFormField(controller: _fEmail, decoration: const InputDecoration(labelText: 'E-mail'), keyboardType: TextInputType.emailAddress),
                    ]),
                    _row([
                      TextFormField(controller: _fCpf, decoration: const InputDecoration(labelText: 'CPF/CNPJ')),
                      TextFormField(controller: _fEnd, decoration: const InputDecoration(labelText: 'Endereço')),
                    ]),
                  ],
                ],
          ]),
        ),
      );
}
