import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/app_runtime.dart';
import '../core/documentos.dart';
import '../core/theme.dart';
import '../core/validacoes.dart';
import '../widgets/common.dart';
import 'ativar_page.dart' show validarLogin, validarSenha;
import 'login_page.dart';

/// Cadastro público: cria uma loja nova e o dono dela (gerente). Cada loja só enxerga os próprios
/// clientes, vendas e funcionários.
class CriarLojaPage extends StatefulWidget {
  const CriarLojaPage({super.key});
  @override
  State<CriarLojaPage> createState() => _CriarLojaPageState();
}

class _CriarLojaPageState extends State<CriarLojaPage> {
  final _form = GlobalKey<FormState>();
  final _loja = TextEditingController(),
      _nome = TextEditingController(),
      _cpf = TextEditingController(),
      _email = TextEditingController(),
      _telefone = TextEditingController(),
      _login = TextEditingController(),
      _senha = TextEditingController(),
      _confirmacao = TextEditingController();
  bool _busy = false;
  String? _erro;

  String? _opcional(TextEditingController c, {bool digitos = false}) {
    final t = digitos ? soDigitos(c.text) : c.text.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _criar() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _erro = null;
    });
    try {
      await AppScope.of(context).sessao.auth.criarLoja({
        'nomeLoja': _loja.text.trim(),
        'nome': _nome.text.trim(),
        'cpf': soDigitos(_cpf.text),
        'email': _opcional(_email),
        'telefone': _opcional(_telefone, digitos: true),
        'login': _login.text.trim(),
        'senha': _senha.text,
      });
      if (!mounted) return;
      context.go('/login');
      toast(
        context,
        'Loja "${_loja.text.trim()}" criada. Entre com seu login e senha.',
      );
    } catch (e) {
      if (mounted) setState(() => _erro = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _loja,
      _nome,
      _cpf,
      _email,
      _telefone,
      _login,
      _senha,
      _confirmacao,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _campo(Widget w) => Padding(
    padding: const EdgeInsets.only(bottom: Gap.md),
    child: w,
  );

  @override
  Widget build(BuildContext context) => PublicCard(
    titulo: 'Criar minha loja',
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LegendaObrigatorios(),
          const Text(
            'Cadastre seu comércio e comece a registrar suas vendas a prazo. '
            'Você será o gerente da loja; os dados dela são só seus.',
          ),
          const SizedBox(height: Gap.md),
          const FormSection('Sua loja'),
          _campo(
            TextFormField(
              controller: _loja,
              decoration: const InputDecoration(
                labelText: 'Nome da loja *',
                hintText: 'ex.: Mercado São José',
              ),
              textCapitalization: TextCapitalization.words,
              inputFormatters: filtroNomeLoja,
              validator: validarNomeLoja,
            ),
          ),
          const FormSection('Seus dados'),
          _campo(
            TextFormField(
              controller: _nome,
              decoration: const InputDecoration(labelText: 'Seu nome *'),
              textCapitalization: TextCapitalization.words,
              inputFormatters: filtroNome,
              validator: validarNome,
            ),
          ),
          _campo(
            TextFormField(
              controller: _cpf,
              decoration: const InputDecoration(
                labelText: 'CPF *',
                hintText: '000.000.000-00',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [MascaraInputFormatter.cpf()],
              validator: (v) =>
                  cpfValido(v ?? '') ? null : 'Informe um CPF válido',
            ),
          ),
          _campo(
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(
                label: RotuloOpcional('E-mail'),
              ),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              inputFormatters: filtroEmail,
              validator: validarEmail,
            ),
          ),
          _campo(
            TextFormField(
              controller: _telefone,
              decoration: const InputDecoration(
                label: RotuloOpcional('Telefone'),
                hintText: '(00) 00000-0000',
              ),
              keyboardType: TextInputType.phone,
              inputFormatters: [MascaraInputFormatter.telefone()],
              validator: (v) => (v ?? '').trim().isEmpty || telefoneValido(v)
                  ? null
                  : 'Informe um telefone com DDD',
            ),
          ),
          const FormSection('Acesso'),
          _campo(
            TextFormField(
              controller: _login,
              decoration: const InputDecoration(labelText: 'Login *'),
              autocorrect: false,
              inputFormatters: filtroLoginNovo,
              validator: validarLogin,
            ),
          ),
          _campo(
            TextFormField(
              controller: _senha,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Senha *'),
              inputFormatters: filtroSenha,
              validator: validarSenha,
            ),
          ),
          TextFormField(
            controller: _confirmacao,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Confirmar senha *'),
            inputFormatters: filtroSenha,
            validator: (v) =>
                v == _senha.text ? obrigatorio(v) : 'As senhas não coincidem',
            onFieldSubmitted: (_) => _criar(),
          ),
          if (_erro != null)
            Padding(
              padding: const EdgeInsets.only(top: Gap.md),
              child: Text(
                _erro!,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          const SizedBox(height: Gap.lg),
          BusyButton(
            label: 'Criar loja',
            busyLabel: 'Criando loja',
            icon: Icons.storefront_outlined,
            busy: _busy,
            onPressed: _criar,
          ),
          TextButton(
            onPressed: () => context.go('/login'),
            child: const Text('Já tenho conta'),
          ),
        ],
      ),
    ),
  );
}
