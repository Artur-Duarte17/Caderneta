import 'package:flutter/material.dart';
import '../core/app_runtime.dart';
import '../core/entrada_numerica.dart';
import '../core/format.dart';
import '../widgets/common.dart';

class ConfiguracaoLojaPage extends StatefulWidget {
  const ConfiguracaoLojaPage({super.key});
  @override
  State<ConfiguracaoLojaPage> createState() => _ConfiguracaoLojaPageState();
}

class _ConfiguracaoLojaPageState extends State<ConfiguracaoLojaPage> {
  final _limite = TextEditingController();
  bool _carregado = false, _busy = false;
  String? _mensagem;
  Future<void> _trocarEmail() async {
    final runtime = AppScope.of(context);
    final email = TextEditingController();
    final form = GlobalKey<FormState>();
    final endereco = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('E-mail da loja'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ao trocar o endereço, a loja ficará bloqueada até a nova confirmação.',
              ),
              TextFormField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Novo e-mail *'),
                validator: (v) =>
                    RegExp(
                      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                    ).hasMatch((v ?? '').trim())
                    ? null
                    : 'Informe um e-mail válido',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(ctx, email.text.trim());
              }
            },
            child: const Text('Enviar confirmação'),
          ),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    email.dispose();
    if (endereco == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await runtime.confirmacaoEmail.solicitar(endereco);
      await runtime.sessao.restaurar();
    } catch (e) {
      if (mounted) setState(() => _mensagem = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _limite.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AsyncView<double>(
    load: () => AppScope.read(context).loja.limitePadrao(),
    builder: (context, dados, _) {
      if (!_carregado) {
        _limite.text = dados.toStringAsFixed(2).replaceAll('.', ',');
        _carregado = true;
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeader(
            titulo: 'Configurações da loja',
            subtitulo:
                'O limite padrão vale somente para novos clientes. Os limites existentes serão mantidos.',
          ),
          TextField(
            controller: _limite,
            keyboardType: tecladoValor,
            inputFormatters: somenteValorMonetario(),
            decoration: const InputDecoration(
              labelText: 'Limite de crédito padrão',
              prefixText: r'R$ ',
            ),
          ),
          if (_mensagem != null) Text(_mensagem!),
          OutlinedButton.icon(
            onPressed: _busy ? null : _trocarEmail,
            icon: const Icon(Icons.mail_outline),
            label: const Text('Alterar e-mail da loja'),
          ),
          BusyButton(
            label: 'Salvar limite padrão',
            busyLabel: 'Salvando',
            busy: _busy,
            onPressed: () async {
              final centavos = parseCentavos(_limite.text);
              if (centavos == null) {
                setState(
                  () => _mensagem =
                      'Informe um valor válido, maior ou igual a zero.',
                );
                return;
              }
              setState(() => _busy = true);
              try {
                await AppScope.read(context).loja.salvarLimite(centavos / 100);
                if (mounted) {
                  setState(() => _mensagem = 'Limite padrão atualizado.');
                }
              } catch (e) {
                if (mounted) setState(() => _mensagem = '$e');
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
          ),
        ],
      );
    },
  );
}
