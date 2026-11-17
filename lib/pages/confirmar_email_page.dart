import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/app_runtime.dart';
import '../core/permissoes.dart';
import '../widgets/common.dart';

class ConfirmarEmailPage extends StatefulWidget {
  const ConfirmarEmailPage({super.key, this.parametros = const {}});
  final Map<String, String> parametros;
  @override
  State<ConfirmarEmailPage> createState() => _ConfirmarEmailPageState();
}

class _ConfirmarEmailPageState extends State<ConfirmarEmailPage> {
  final _email = TextEditingController();
  bool _busy = false;
  String? _mensagem;
  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _executar(bool confirmar) async {
    if (_busy) return;
    final runtime = AppScope.of(context);
    final router = GoRouter.of(context);
    setState(() {
      _busy = true;
      _mensagem = null;
    });
    try {
      if (confirmar) {
        final args = widget.parametros;
        await runtime.gateway.send(
          'POST',
          '/auth/email/confirmar',
          autenticado: false,
          body: {
            'lojaId': int.tryParse(args['loja'] ?? ''),
            'token': args['token'] ?? '',
          },
        );
        if (!mounted) return;
        if (runtime.sessao.autenticado) await runtime.sessao.restaurar();
        // A restauração da sessão pode reconstruir e desmontar esta página.
        // O router pertence ao aplicativo e continua válido após essa atualização.
        router.go(
          runtime.sessao.autenticado
              ? entrada(runtime.sessao.usuario?.perfil)
              : '/login',
        );
      } else {
        final r = await runtime.gateway.send(
          'POST',
          '/auth/email/solicitar',
          body: {'email': _email.text.trim()},
        );
        if (mounted) setState(() => _mensagem = r['message']);
      }
    } catch (e) {
      if (mounted) setState(() => _mensagem = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final runtime = AppScope.of(context);
    final link = widget.parametros.containsKey('token');
    final gerente = runtime.sessao.usuario?.perfil == Perfil.gerente;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: 480,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Confirme o e-mail da loja',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'A loja só poderá ser utilizada depois da confirmação. Confira também a pasta de spam.',
                      ),
                      if (link)
                        BusyButton(
                          label: 'Confirmar e-mail',
                          busyLabel: 'Confirmando',
                          busy: _busy,
                          onPressed: () => _executar(true),
                        )
                      else if (gerente) ...[
                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'E-mail da loja',
                          ),
                        ),
                        BusyButton(
                          label: 'Enviar / reenviar confirmação',
                          busyLabel: 'Enviando',
                          busy: _busy,
                          onPressed: () => _executar(false),
                        ),
                      ] else
                        const Text(
                          'Peça ao gerente para confirmar o e-mail da loja.',
                        ),
                      if (_mensagem != null)
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(_mensagem!),
                          ),
                        ),
                      if (runtime.sessao.autenticado) ...[
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () async {
                                  await runtime.sessao.restaurar();
                                },
                          child: const Text(
                            'Já confirmei: verificar novamente',
                          ),
                        ),
                        TextButton(
                          onPressed: _busy ? null : () => runtime.sessao.sair(),
                          child: const Text('Sair'),
                        ),
                      ] else
                        TextButton(
                          onPressed: () => context.go('/login'),
                          child: const Text('Ir para o login'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
