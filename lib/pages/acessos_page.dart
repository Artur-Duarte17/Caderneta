import 'package:flutter/material.dart';
import '../core/app_runtime.dart';
import '../core/models.dart';
import '../core/paged_controller.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/paginacao.dart';
import 'login_page.dart';
import 'ativar_page.dart' show cpfValido, validarLogin, validarSenha;

class AcessosPage extends StatefulWidget {
  const AcessosPage({super.key});
  @override
  State<AcessosPage> createState() => _AcessosPageState();
}

class _AcessosPageState extends State<AcessosPage> {
  PagedController<ContaAcesso>? _c;
  bool _busy = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _c ??= PagedController(AppScope.of(context).acessos.listar)..atualizar();
  }

  Future<void> _ativo(ContaAcesso conta) async {
    if (_busy) return;
    final runtime = AppScope.of(context);
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${conta.ativo ? 'Desativar' : 'Ativar'} acesso?'),
        content: Text('${conta.nome} (${conta.login})'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      await runtime.acessos.ativo(conta.id, !conta.ativo);
      if (!mounted) return;
      toast(context, 'Acesso atualizado.');
      _c!.atualizar();
    } catch (e) {
      if (mounted) toast(context, '$e', erro: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _funcionario() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _FuncionarioForm(),
    );
    if (ok == true && mounted) _c!.atualizar();
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = AppScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          titulo: 'Acessos',
          subtitulo: 'Contas e situação de acesso',
          acoes: [
            if (r.acessos.permiteCriarFuncionario)
              FilledButton.icon(
                onPressed: _funcionario,
                icon: const Icon(Icons.person_add_outlined),
                label: const Text('Criar funcionário'),
              ),
          ],
        ),
        if (r.acessos.suportaBusca)
          FilterField(
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar nome ou login',
                suffixIcon: Icon(Icons.search),
              ),
              onSubmitted: (value) => _c!.filtrar(
                value.trim().isEmpty ? {} : {'busca': value.trim()},
              ),
            ),
          ),
        const SizedBox(height: Gap.md),
        PaginatedSection<ContaAcesso>(
          controller: _c!,
          builder: (lista) => AppTable(
            colunas: const ['Nome', 'Login', 'Perfil', 'Situação', 'Ação'],
            linhas: [
              for (final conta in lista)
                [
                  Text(conta.nome),
                  Text(conta.login),
                  Text(conta.perfil?.label ?? 'Desconhecido'),
                  Text(conta.ativo ? 'Ativo' : 'Inativo'),
                  conta.id == r.sessao.usuario!.id
                      ? const Text('Sua conta')
                      : TextButton(
                          onPressed: _busy ? null : () => _ativo(conta),
                          child: Text(conta.ativo ? 'Desativar' : 'Ativar'),
                        ),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FuncionarioForm extends StatefulWidget {
  const _FuncionarioForm();
  @override
  State<_FuncionarioForm> createState() => _FuncionarioFormState();
}

class _FuncionarioFormState extends State<_FuncionarioForm> {
  static const campos = {
    'nome': 'Nome',
    'cpf': 'CPF',
    'email': 'E-mail',
    'telefone': 'Telefone',
    'endereco': 'Endereço',
    'matricula': 'Matrícula',
    'cargo': 'Cargo',
    'login': 'Login',
    'senha': 'Senha',
  };
  final _form = GlobalKey<FormState>();
  final _campos = {for (final key in campos.keys) key: TextEditingController()};
  bool _busy = false;
  String? _erro;
  Future<void> _salvar() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _erro = null;
    });
    try {
      await AppScope.of(context).acessos.criarFuncionario({
        for (final e in _campos.entries) e.key: e.value.text,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _erro = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    for (final c in _campos.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Criar funcionário'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final e in campos.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: Gap.md),
                  child: TextFormField(
                    controller: _campos[e.key],
                    obscureText: e.key == 'senha',
                    decoration: InputDecoration(labelText: e.value),
                    validator: switch (e.key) {
                      'cpf' =>
                        (v) =>
                            cpfValido(v ?? '') ? null : 'Informe um CPF válido',
                      'senha' => validarSenha,
                      'login' => validarLogin,
                      'nome' || 'cargo' => obrigatorio,
                      _ => null,
                    },
                  ),
                ),
              if (_erro != null)
                Text(_erro!, style: const TextStyle(color: AppColors.danger)),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      BusyButton(label: 'Criar acesso', busy: _busy, onPressed: _salvar),
    ],
  );
}
