import 'package:flutter/material.dart';
import '../core/app_runtime.dart';
import '../core/models.dart';
import '../core/paged_controller.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/paginacao.dart';
import 'ativar_page.dart' show validarLogin, validarSenha;
import '../core/documentos.dart';
import '../core/validacoes.dart';

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
      await executarComCarregamento(
        context,
        conta.ativo ? 'Desativando acesso' : 'Ativando acesso',
        () => runtime.acessos.ativo(conta.id, !conta.ativo),
      );
      if (!mounted) return;
      toast(context, 'Acesso atualizado.');
      _c!.atualizar();
    } catch (e) {
      if (mounted) toast(context, '$e', erro: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Gerente promove funcionário a gerente (ou o inverso) com o mesmo login.
  Future<void> _perfil(ContaAcesso conta) async {
    if (_busy) return;
    final runtime = AppScope.of(context);
    final promover = conta.perfil == Perfil.funcionario;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(promover ? 'Tornar gerente?' : 'Tornar funcionário?'),
        content: Text(
          '${conta.nome} (${conta.login})\n\n'
          '${promover ? 'Passa a ter acesso de gerente: relatórios, auditoria, acessos, limite de crédito e edição de vendas.' : 'Perde o acesso de gerente e volta a ser funcionário.'}\n\n'
          'O login e a senha continuam os mesmos. Se a pessoa estiver conectada, '
          'precisará entrar de novo para o novo perfil valer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(promover ? 'Tornar gerente' : 'Tornar funcionário'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      await executarComCarregamento(
        context,
        promover ? 'Tornando gerente' : 'Tornando funcionário',
        () => runtime.acessos.alterarPerfil(
          conta.id,
          promover ? Perfil.gerente : Perfil.funcionario,
        ),
      );
      if (!mounted) return;
      toast(
        context,
        promover
            ? '${conta.nome} agora é gerente.'
            : '${conta.nome} agora é funcionário.',
      );
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
                      : Row(
                          // Uma linha só: a tabela tem altura de linha fixa (empilhar cortaria o botão).
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: _busy ? null : () => _ativo(conta),
                              child: Text(conta.ativo ? 'Desativar' : 'Ativar'),
                            ),
                            // Só contas da equipe; clientes não viram gerente.
                            if (conta.perfil == Perfil.funcionario ||
                                conta.perfil == Perfil.gerente)
                              TextButton(
                                onPressed: _busy ? null : () => _perfil(conta),
                                child: Text(
                                  conta.perfil == Perfil.funcionario
                                      ? 'Tornar gerente'
                                      : 'Tornar funcionário',
                                ),
                              ),
                          ],
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
  static const _opcionais = {'email', 'telefone', 'endereco', 'matricula'};
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
      String? valor(String chave, String texto) {
        final t = chave == 'senha' ? texto : texto.trim();
        final v = chave == 'cpf' || chave == 'telefone' ? soDigitos(t) : t;
        // Opcionais vazios vão como null (não grava texto vazio no banco).
        return v.isEmpty && _opcionais.contains(chave) ? null : v;
      }

      await AppScope.of(context).acessos.criarFuncionario({
        for (final e in _campos.entries) e.key: valor(e.key, e.value.text),
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
                    decoration: InputDecoration(
                      labelText: e.value,
                      hintText: switch (e.key) {
                        'cpf' => '000.000.000-00',
                        'telefone' => '(00) 00000-0000',
                        _ => null,
                      },
                    ),
                    keyboardType: switch (e.key) {
                      'cpf' || 'telefone' => TextInputType.number,
                      'email' => TextInputType.emailAddress,
                      _ => null,
                    },
                    textCapitalization: e.key == 'nome'
                        ? TextCapitalization.words
                        : TextCapitalization.none,
                    autocorrect: !const {
                      'login',
                      'senha',
                      'email',
                    }.contains(e.key),
                    inputFormatters: switch (e.key) {
                      'cpf' => [MascaraInputFormatter.cpf()],
                      'telefone' => [MascaraInputFormatter.telefone()],
                      'nome' => filtroNome,
                      'email' => filtroEmail,
                      'endereco' => filtroEndereco,
                      'matricula' => filtroMatricula,
                      'cargo' => filtroCargo,
                      'login' => filtroLoginNovo,
                      'senha' => filtroSenha,
                      _ => null,
                    },
                    validator: switch (e.key) {
                      'cpf' =>
                        (v) =>
                            cpfValido(v ?? '') ? null : 'Informe um CPF válido',
                      'telefone' =>
                        (v) => (v ?? '').trim().isEmpty || telefoneValido(v)
                            ? null
                            : 'Informe um telefone com DDD',
                      'senha' => validarSenha,
                      'login' => validarLogin,
                      'nome' => validarNome,
                      'cargo' => validarCargo,
                      'email' => validarEmail,
                      'endereco' => validarEndereco,
                      'matricula' => validarMatricula,
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
      BusyButton(
        label: 'Criar acesso',
        busyLabel: 'Criando acesso',
        busy: _busy,
        onPressed: _salvar,
      ),
    ],
  );
}
