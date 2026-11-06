import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.sessao});
  final SessaoController sessao;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _login = TextEditingController(), _senha = TextEditingController();
  bool _busy = false, _oculta = true;
  String? _erro;
  Future<void> _entrar() async {
    if (_busy || widget.sessao.ocupado || !_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _busy = true;
      _erro = null;
    });
    try {
      await widget.sessao.entrar(_login.text, _senha.text);
    } catch (e) {
      if (mounted) setState(() => _erro = '$e');
      _senha.clear();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _login.dispose();
    _senha.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PublicCard(
    titulo: 'Entre na Caderneta',
    child: AutofillGroup(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.sessao.aviso != null) ...[
              Text(
                widget.sessao.aviso!,
                style: const TextStyle(color: AppColors.warning),
              ),
              const SizedBox(height: Gap.md),
              TextButton(
                onPressed: widget.sessao.ocupado
                    ? null
                    : widget.sessao.restaurar,
                child: const Text('Verificar conexão e sessão'),
              ),
            ],
            TextFormField(
              controller: _login,
              autofillHints: const [AutofillHints.username],
              decoration: const InputDecoration(labelText: 'Login'),
              textInputAction: TextInputAction.next,
              validator: obrigatorio,
            ),
            const SizedBox(height: Gap.md),
            TextFormField(
              controller: _senha,
              obscureText: _oculta,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _entrar(),
              decoration: InputDecoration(
                labelText: 'Senha',
                suffixIcon: IconButton(
                  tooltip: _oculta ? 'Mostrar senha' : 'Ocultar senha',
                  onPressed: () => setState(() => _oculta = !_oculta),
                  icon: Icon(
                    _oculta
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: obrigatorio,
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
              label: 'Entrar',
              busy: _busy || widget.sessao.ocupado,
              onPressed: _entrar,
            ),
            const SizedBox(height: Gap.sm),
            TextButton(
              onPressed: () => context.go('/ativar'),
              child: const Text('Primeiro acesso'),
            ),
          ],
        ),
      ),
    ),
  );
}

String? obrigatorio(String? value) =>
    value == null || value.trim().isEmpty ? 'Campo obrigatório' : null;

class PublicCard extends StatelessWidget {
  const PublicCard({super.key, required this.titulo, required this.child});
  final String titulo;
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Gap.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.menu_book,
                    size: 48,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: Gap.lg),
                  Text(
                    titulo,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: Gap.lg),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
