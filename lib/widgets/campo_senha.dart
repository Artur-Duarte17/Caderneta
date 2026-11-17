import 'package:flutter/material.dart';
import '../core/validacoes.dart';

/// Interação compartilhada; a política continua no validador e no servidor.
class CampoSenha extends StatefulWidget {
  const CampoSenha({
    super.key,
    required this.controller,
    this.confirmar,
    this.label = 'Senha *',
    this.onFieldSubmitted,
  });
  final TextEditingController controller;
  final TextEditingController? confirmar;
  final String label;
  final ValueChanged<String>? onFieldSubmitted;
  @override
  State<CampoSenha> createState() => _CampoSenhaState();
}

class _CampoSenhaState extends State<CampoSenha> {
  final _campo = GlobalKey<FormFieldState<String>>();
  bool _oculta = true, _interagiu = false;
  @override
  void initState() {
    super.initState();
    widget.confirmar?.addListener(_validar);
  }

  void _validar() {
    if (_interagiu) _campo.currentState?.validate();
  }

  @override
  void didUpdateWidget(CampoSenha oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.confirmar != widget.confirmar) {
      oldWidget.confirmar?.removeListener(_validar);
      widget.confirmar?.addListener(_validar);
    }
  }

  @override
  void dispose() {
    widget.confirmar?.removeListener(_validar);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    key: _campo,
    controller: widget.controller,
    obscureText: _oculta,
    autocorrect: false,
    enableSuggestions: false,
    autofillHints: const [AutofillHints.newPassword],
    inputFormatters: filtroSenha,
    onChanged: (_) {
      _interagiu = true;
      _validar();
    },
    onFieldSubmitted: widget.onFieldSubmitted,
    validator: (v) => widget.confirmar == null
        ? validarSenha(v)
        : (v == null || v.isEmpty
              ? 'Confirme a senha'
              : v != widget.confirmar!.text
              ? 'As senhas não coincidem'
              : null),
    decoration: InputDecoration(
      labelText: widget.label,
      suffixIcon: IconButton(
        tooltip: _oculta
            ? 'Mostrar ${widget.label.replaceAll(' *', '').toLowerCase()}'
            : 'Ocultar senha',
        onPressed: () => setState(() => _oculta = !_oculta),
        icon: Icon(
          _oculta ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
      ),
    ),
  );
}
