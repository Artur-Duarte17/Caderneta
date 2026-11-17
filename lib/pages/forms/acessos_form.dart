import 'package:flutter/material.dart';
import '../../widgets/campo_senha.dart';
import '../../core/app_runtime.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../core/documentos.dart';
import '../../core/validacoes.dart';

class FuncionarioForm extends StatefulWidget {
  const FuncionarioForm({super.key});
  @override
  State<FuncionarioForm> createState() => FuncionarioFormState();
}

class FuncionarioFormState extends State<FuncionarioForm> {
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
  final _confirmarSenha = TextEditingController();
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

      final criada = await AppScope.of(context).acessos.criarFuncionario({
        for (final e in _campos.entries) e.key: valor(e.key, e.value.text),
      });
      if (!mounted) return;
      if (criada.reativado) {
        // A operação terminou: o botão para de indicar carregamento antes do aviso.
        setState(() => _busy = false);
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Funcionário reativado'),
            content: Text(
              'Este CPF era de um funcionário excluído. A conta antiga foi reativada, '
              'com o histórico de vendas preservado.\n\n'
              'Login: ${criada.login} (o login antigo é mantido)\n'
              'Senha: a que você informou agora\n'
              'Perfil: Funcionário',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Entendi'),
              ),
            ],
          ),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _erro = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _confirmarSenha.dispose();
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
              const LegendaObrigatorios(),
              for (final e in campos.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: Gap.md),
                  child: e.key == 'senha'
                      ? Column(
                          children: [
                            CampoSenha(controller: _campos['senha']!),
                            CampoSenha(
                              controller: _confirmarSenha,
                              confirmar: _campos['senha']!,
                              label: 'Confirmar senha *',
                            ),
                          ],
                        )
                      : TextFormField(
                          controller: _campos[e.key],
                          obscureText: e.key == 'senha',
                          // Obrigatório: " *"; opcional: etiqueta "opcional".
                          decoration: InputDecoration(
                            labelText: _opcionais.contains(e.key)
                                ? null
                                : '${e.value} *',
                            label: _opcionais.contains(e.key)
                                ? RotuloOpcional(e.value)
                                : null,
                            hintText: switch (e.key) {
                              'cpf' => '000.000.000-00',
                              'telefone' => '(00) 00000-0000',
                              'matricula' =>
                                'Identificação interna, ex.: CX-01',
                              'cargo' => 'Função comercial, ex.: Caixa',
                              _ => null,
                            },
                            helperText: e.key == 'cargo'
                                ? 'Função comercial. As permissões dependem do perfil em Acessos.'
                                : null,
                          ),
                          // Cargo descreve a função; perfil/permissão é gerenciado em Acessos.
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
                              (v) => cpfValido(v ?? '')
                                  ? null
                                  : 'Informe um CPF válido',
                            'telefone' =>
                              (v) =>
                                  (v ?? '').trim().isEmpty || telefoneValido(v)
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

/// Pede a senha nova para restaurar uma conta excluída.
class RestaurarDialog extends StatefulWidget {
  const RestaurarDialog({super.key, required this.conta});
  final ContaAcesso conta;
  @override
  State<RestaurarDialog> createState() => RestaurarDialogState();
}

class RestaurarDialogState extends State<RestaurarDialog> {
  final _form = GlobalKey<FormState>();
  final _senha = TextEditingController(),
      _confirmacao = TextEditingController();

  @override
  void dispose() {
    _senha.dispose();
    _confirmacao.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Restaurar acesso'),
    content: SizedBox(
      width: 400,
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.conta.nome} (${widget.conta.login}) volta como funcionário, com o mesmo '
              'login. Defina uma senha nova: a antiga deixa de valer.',
            ),
            const SizedBox(height: Gap.md),
            CampoSenha(controller: _senha, label: 'Senha nova *'),
            const SizedBox(height: Gap.md),
            CampoSenha(
              controller: _confirmacao,
              confirmar: _senha,
              label: 'Confirmar senha *',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: AppColors.success),
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, _senha.text);
          }
        },
        child: const Text('Restaurar'),
      ),
    ],
  );
}
