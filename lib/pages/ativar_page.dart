import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/app_runtime.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'login_page.dart';
import '../core/documentos.dart';
import '../core/validacoes.dart';

export '../core/documentos.dart' show cpfValido;

String? validarLogin(String? value) =>
    RegExp(r'^[A-Za-z0-9._-]{3,50}$').hasMatch(value ?? '')
    ? null
    : 'Use 3 a 50 caracteres: letras, números, ponto, hífen ou sublinhado';
String? validarSenha(String? value) =>
    value != null && value.length >= 8 && value.length <= 72
    ? null
    : 'A senha deve ter de 8 a 72 caracteres';

class AtivarPage extends StatefulWidget {
  const AtivarPage({super.key});
  @override
  State<AtivarPage> createState() => _AtivarPageState();
}

class _AtivarPageState extends State<AtivarPage> {
  final _form = GlobalKey<FormState>();
  final _cpf = TextEditingController(),
      _codigo = TextEditingController(),
      _login = TextEditingController(),
      _senha = TextEditingController(),
      _confirmacao = TextEditingController();
  bool _busy = false;
  String? _erro;
  Future<void> _ativar() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _erro = null;
    });
    try {
      await AppScope.of(context).sessao.auth.ativar({
        'cpf': soDigitos(_cpf.text),
        'codigoConvite': _codigo.text.trim(),
        'login': _login.text.trim(),
        'senha': _senha.text,
      });
      if (!mounted) return;
      context.go('/login');
      toast(context, 'Acesso criado. Entre com seu login e senha.');
    } catch (e) {
      if (mounted) setState(() => _erro = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    for (final c in [_cpf, _codigo, _login, _senha, _confirmacao]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PublicCard(
    titulo: 'Ativar acesso',
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _cpf,
            decoration: const InputDecoration(
              labelText: 'CPF',
              hintText: '000.000.000-00',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [MascaraInputFormatter.cpf()],
            validator: (v) =>
                cpfValido(v ?? '') ? null : 'Informe um CPF válido',
          ),
          const SizedBox(height: Gap.md),
          TextFormField(
            controller: _codigo,
            decoration: const InputDecoration(
              labelText: 'Código do convite',
              hintText: '20 letras e números',
            ),
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            inputFormatters: filtroConvite,
            validator: validarConvite,
          ),
          const SizedBox(height: Gap.md),
          TextFormField(
            controller: _login,
            decoration: const InputDecoration(labelText: 'Login'),
            autocorrect: false,
            inputFormatters: filtroLoginNovo,
            validator: validarLogin,
          ),
          const SizedBox(height: Gap.md),
          TextFormField(
            controller: _senha,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Senha'),
            inputFormatters: filtroSenha,
            validator: validarSenha,
          ),
          const SizedBox(height: Gap.md),
          TextFormField(
            controller: _confirmacao,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Confirmar senha'),
            inputFormatters: filtroSenha,
            validator: (v) =>
                v == _senha.text ? obrigatorio(v) : 'As senhas não coincidem',
            onFieldSubmitted: (_) => _ativar(),
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
          BusyButton(label: 'Ativar acesso', busy: _busy, onPressed: _ativar),
          TextButton(
            onPressed: () => context.go('/login'),
            child: const Text('Voltar para entrar'),
          ),
        ],
      ),
    ),
  );
}
