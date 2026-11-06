import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_runtime.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/theme.dart';
import 'common.dart';

class ConviteDialog extends StatefulWidget {
  const ConviteDialog({super.key, required this.cliente});
  final Cliente cliente;
  @override
  State<ConviteDialog> createState() => _ConviteDialogState();
}

class _ConviteDialogState extends State<ConviteDialog> {
  Convite? _convite;
  bool _busy = false;
  String? _erro;
  Future<void> _gerar() async {
    if (_busy || _convite != null) return;
    final runtime = AppScope.of(context);
    setState(() {
      _busy = true;
      _erro = null;
    });
    try {
      final convite = await runtime.acessos.convite(widget.cliente.id);
      if (!mounted) return;
      setState(() => _convite = convite);
      runtime.historico.dadosAlterados();
    } catch (e) {
      if (mounted) setState(() => _erro = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _convite = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Convite de acesso'),
    content: SizedBox(
      width: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.cliente.nome),
          const SizedBox(height: Gap.md),
          if (_convite == null)
            const Text('Gerar um código para ativar o acesso deste cliente?')
          else ...[
            const Text(
              'Este código só é exibido agora. Compartilhe com o cliente.',
            ),
            const SizedBox(height: Gap.md),
            SelectableText(
              _convite!.codigo,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: Gap.sm),
            Text('Válido até ${dataHora(_convite!.expiraEm)}'),
          ],
          if (_erro != null)
            Text(_erro!, style: const TextStyle(color: AppColors.danger)),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Fechar'),
      ),
      if (_convite == null)
        BusyButton(label: 'Gerar código', busy: _busy, onPressed: _gerar)
      else
        FilledButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: _convite!.codigo));
            if (context.mounted) toast(context, 'Código copiado.');
          },
          icon: const Icon(Icons.copy),
          label: const Text('Copiar'),
        ),
    ],
  );
}
