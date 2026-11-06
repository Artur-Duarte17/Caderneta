import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/app_runtime.dart';
import '../core/permissoes.dart';
import 'ativar_page.dart' show cpfValido;
import '../widgets/convite_dialog.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/historico_service.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class ClientesPage extends StatefulWidget {
  const ClientesPage({super.key});
  @override
  State<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends State<ClientesPage> {
  String _busca = '';
  int _page = 0;

  @override
  Widget build(BuildContext context) => AsyncView<Snapshot>(
    key: ValueKey((_page, _busca, null, 0)),
    load: () => Snapshot.load(recurso: 'clientes', page: _page, q: _busca),
    builder: (context, s, reload) {
      final termo = _busca.toLowerCase();
      final lista =
          s.clientes
              .where(
                (c) =>
                    termo.isEmpty ||
                    c.nome.toLowerCase().contains(termo) ||
                    (c.telefone ?? '').contains(termo),
              )
              .toList()
            ..sort(
              (a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()),
            );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            titulo: 'Clientes',
            subtitulo: '${s.total} cliente(s) cadastrado(s)',
            acoes: [
              FilledButton.icon(
                onPressed: () => _abrirForm(context, null),
                icon: const Icon(Icons.person_add_alt, size: 18),
                label: const Text('Novo cliente'),
              ),
            ],
          ),
          FilterField(
            width: 360,
            child: SearchField(
              hint: 'Buscar por nome ou telefone',
              onChanged: (v) => setState(() {
                _busca = v;
                _page = 0;
              }),
            ),
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
              icon: Icons.person_off_outlined,
              titulo: 'Nenhum cliente encontrado',
            )
          else
            ResponsiveGrid(
              minWidth: 300,
              children: [
                for (final c in lista)
                  _ClienteCard(
                    cliente: c,
                    saldo: s.saldoDevedor(c.id),
                    atraso: s.emAtraso(c.id),
                    onDetalhes: () => _detalhes(context, s, c),
                    onEditar: () => _abrirForm(context, c),
                  ),
              ],
            ),
        ],
      );
    },
  );

  void _detalhes(BuildContext context, Snapshot s, Cliente c) {
    final saldo = s.saldoDevedor(c.id);
    final disponivel = c.limiteCredito - saldo;
    showAppDialog(
      context,
      titulo: 'Detalhes do cliente',
      builder: (ctx, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Avatar(c.nome, size: 48),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Text(
                    c.nome,
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                ),
                _situacao(saldo, s.emAtraso(c.id)),
              ],
            ),
            const SizedBox(height: Gap.md),
            const FormSection('Informações pessoais'),
            InfoRow('Telefone', c.telefone ?? 'Não informado'),
            InfoRow('E-mail', c.email ?? 'Não informado'),
            InfoRow('CPF/CNPJ', c.cpf ?? 'Não informado'),
            InfoRow('Endereço', c.endereco ?? 'Não informado'),
            const SizedBox(height: Gap.sm),
            const FormSection('Situação financeira'),
            InfoRow('Limite de crédito', moeda(c.limiteCredito)),
            InfoRow(
              'Saldo devedor',
              moeda(saldo),
              destaque: saldo > 0 ? AppColors.danger : AppColors.success,
            ),
            InfoRow(
              'Crédito disponível',
              moeda(disponivel),
              destaque: disponivel < 0 ? AppColors.danger : null,
            ),
            InfoRow('Prazo padrão', '${c.prazoPagamentoPadraoDias} dias'),
          ],
        );
      },
    );
  }

  Future<void> _abrirForm(BuildContext context, Cliente? c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ClienteForm(cliente: c),
    );
    if (ok == true) HistoricoService.instance.dadosAlterados();
  }
}

Widget _situacao(double saldo, bool atraso) {
  if (atraso) {
    return const Pill(
      label: 'Em atraso',
      cor: AppColors.danger,
      icon: Icons.error,
    );
  }
  if (saldo > 0) {
    return const Pill(
      label: 'Devendo',
      cor: AppColors.warning,
      icon: Icons.schedule,
    );
  }
  return const Pill(
    label: 'Em dia',
    cor: AppColors.success,
    icon: Icons.check_circle,
  );
}

class _ClienteCard extends StatelessWidget {
  const _ClienteCard({
    required this.cliente,
    required this.saldo,
    required this.atraso,
    required this.onDetalhes,
    required this.onEditar,
  });
  final Cliente cliente;
  final double saldo;
  final bool atraso;
  final VoidCallback onDetalhes, onEditar;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(Gap.ml),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Avatar(cliente.nome),
              const SizedBox(width: Gap.ms),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cliente.nome,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      cliente.telefone ?? 'Sem telefone',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saldo devedor',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      moeda(saldo),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: saldo > 0 ? AppColors.danger : AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
              _situacao(saldo, atraso),
            ],
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
              const SizedBox(width: Gap.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEditar,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Editar'),
                ),
              ),
            ],
          ),
          if (pode(
            AppScope.of(context).sessao.usuario?.perfil,
            Acao.gerarConvite,
          )) ...[
            const SizedBox(height: Gap.sm),
            OutlinedButton.icon(
              onPressed: () => showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => ConviteDialog(cliente: cliente),
              ),
              icon: const Icon(Icons.key_outlined),
              label: const Text('Gerar convite'),
            ),
          ],
        ],
      ),
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
  late final _limite = TextEditingController(
    text: widget.cliente?.limiteCredito.toStringAsFixed(2).replaceAll('.', ','),
  );
  late final _prazo = TextEditingController(
    text: '${widget.cliente?.prazoPagamentoPadraoDias ?? 30}',
  );
  final _fNome = TextEditingController(),
      _fTel = TextEditingController(),
      _fEmail = TextEditingController();
  final _fCpf = TextEditingController(), _fEnd = TextEditingController();
  late bool _temFiador = widget.cliente?.fiador != null;
  bool get _gerente =>
      AppScope.of(context).sessao.usuario?.perfil == Perfil.gerente;
  @override
  void initState() {
    super.initState();
    final f = widget.cliente?.fiador;
    if (f != null) {
      _fNome.text = f['nome'] ?? '';
      _fTel.text = f['telefone'] ?? '';
      _fEmail.text = f['email'] ?? '';
      _fCpf.text = f['cpf'] ?? '';
      _fEnd.text = f['endereco'] ?? '';
    }
  }

  bool _salvando = false;

  @override
  void dispose() {
    for (final c in [
      _nome,
      _tel,
      _email,
      _cpf,
      _end,
      _limite,
      _prazo,
      _fNome,
      _fTel,
      _fEmail,
      _fCpf,
      _fEnd,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _editando => widget.cliente != null;
  bool get _fiadorAlterado {
    final atual = widget.cliente?.fiador;
    if (_temFiador != (atual != null)) return true;
    if (!_temFiador) return false;
    final campos = {
      'nome': _fNome.text,
      'cpf': _fCpf.text,
      'telefone': _fTel.text,
      'email': _fEmail.text,
      'endereco': _fEnd.text,
    };
    return campos.entries.any(
      (e) => (atual?[e.key] ?? '').toString().trim() != e.value.trim(),
    );
  }

  String? _obrigatorio(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null;
  String? _opt(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _salvar() async {
    if (_salvando || !_form.currentState!.validate()) return;
    setState(() => _salvando = true);
    final dados = {
      'nome': _nome.text.trim(),
      'telefone': _tel.text.trim(),
      'email': _opt(_email),
      'endereco': _opt(_end),
      if (_gerente) 'limiteCredito': (parseCentavos(_limite.text) ?? 0) / 100,
      if (_gerente) 'prazoPagamentoPadraoDias': int.tryParse(_prazo.text) ?? 30,
      if (!_editando || _fiadorAlterado)
        'fiador': _temFiador
            ? {
                if (widget.cliente?.fiador?['cpf'] == _fCpf.text.trim())
                  'id': widget.cliente?.fiador?['id'],
                'nome': _fNome.text.trim(),
                'cpf': _fCpf.text.trim(),
                'telefone': _fTel.text.trim(),
                'email': _opt(_fEmail),
                'endereco': _opt(_fEnd),
              }
            : null,
    };
    try {
      if (_editando) {
        await Api.instance.atualizarCliente(widget.cliente!.id, dados);
      } else {
        await Api.instance.criarCliente({...dados, 'cpf': _cpf.text.trim()});
      }
      if (!mounted) return;
      toast(
        context,
        _editando
            ? 'Cliente atualizado com sucesso'
            : 'Cliente cadastrado com sucesso',
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      toast(context, '$e', erro: true);
    }
  }

  Widget _row(List<Widget> campos) => LayoutBuilder(
    builder: (_, c) => c.maxWidth < 480
        ? Column(
            children: [
              for (final f in campos)
                Padding(
                  padding: const EdgeInsets.only(bottom: Gap.md),
                  child: f,
                ),
            ],
          )
        : Padding(
            padding: const EdgeInsets.only(bottom: Gap.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < campos.length; i++) ...[
                  if (i > 0) const SizedBox(width: Gap.md),
                  Expanded(child: campos[i]),
                ],
              ],
            ),
          ),
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(_editando ? 'Editar cliente' : 'Novo cliente'),
    content: SizedBox(
      width: 600,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FormSection('Dados pessoais'),
              _row([
                TextFormField(
                  controller: _nome,
                  decoration: const InputDecoration(
                    labelText: 'Nome completo *',
                  ),
                  validator: _obrigatorio,
                ),
              ]),
              _row([
                TextFormField(
                  controller: _tel,
                  decoration: const InputDecoration(labelText: 'Telefone *'),
                  validator: _obrigatorio,
                ),
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'E-mail'),
                ),
              ]),
              _row([
                TextFormField(
                  controller: _cpf,
                  validator: (v) => _editando
                      ? null
                      : cpfValido(v ?? '')
                      ? null
                      : 'Informe um CPF válido',
                  enabled: !_editando,
                  decoration: InputDecoration(
                    labelText: 'CPF/CNPJ *',
                    helperText: _editando ? 'Não pode ser alterado' : null,
                  ),
                ),
              ]),
              _row([
                TextFormField(
                  controller: _end,
                  decoration: const InputDecoration(labelText: 'Endereço'),
                  maxLines: 2,
                ),
              ]),
              const FormSection('Crédito'),
              _row([
                TextFormField(
                  controller: _limite,
                  enabled: _gerente,
                  validator: (v) => !_gerente
                      ? null
                      : parseCentavos(v ?? '') == null
                      ? 'Informe limite com até 2 casas'
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Limite de crédito',
                    prefixText: r'R$ ',
                  ),
                ),
                TextFormField(
                  controller: _prazo,
                  enabled: _gerente,
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    return !_gerente
                        ? null
                        : n == null || n < 0 || n > 3650
                        ? 'Prazo de 0 a 3650 dias'
                        : null;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Prazo de pagamento',
                    suffixText: 'dias',
                  ),
                ),
              ]),
              ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Cliente possui fiador'),
                  value: _temFiador,
                  onChanged: (v) => setState(() => _temFiador = v),
                ),
                if (_temFiador) ...[
                  const FormSection('Fiador'),
                  _row([
                    TextFormField(
                      controller: _fNome,
                      decoration: const InputDecoration(
                        labelText: 'Nome completo *',
                      ),
                      validator: _obrigatorio,
                    ),
                  ]),
                  _row([
                    TextFormField(
                      controller: _fTel,
                      decoration: const InputDecoration(
                        labelText: 'Telefone *',
                      ),
                      validator: _obrigatorio,
                    ),
                    TextFormField(
                      controller: _fEmail,
                      decoration: const InputDecoration(labelText: 'E-mail'),
                    ),
                  ]),
                  _row([
                    TextFormField(
                      controller: _fCpf,
                      validator: (v) => _editando && !_fiadorAlterado
                          ? null
                          : cpfValido(v ?? '')
                          ? null
                          : 'Informe um CPF válido',
                      decoration: const InputDecoration(
                        labelText: 'CPF do fiador *',
                      ),
                    ),
                    TextFormField(
                      controller: _fEnd,
                      decoration: const InputDecoration(labelText: 'Endereço'),
                    ),
                  ]),
                ],
              ],
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
        label: _editando ? 'Salvar alterações' : 'Cadastrar',
        busy: _salvando,
        onPressed: _salvar,
      ),
    ],
  );
}
