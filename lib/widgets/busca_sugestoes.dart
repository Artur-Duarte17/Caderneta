import 'dart:async';
import 'package:flutter/material.dart';

/// Combina texto livre, debounce e escolha por teclado sem conhecer o domínio.
class BuscaSugestoes<T extends Object> extends StatefulWidget {
  const BuscaSugestoes({
    super.key,
    required this.label,
    required this.buscar,
    required this.texto,
    required this.onSelecionar,
    this.controller,
    this.validator,
    this.onChanged,
    this.inicial = '',
    this.enabled = true,
  });
  final String label, inicial;
  final Future<List<T>> Function(String) buscar;
  final String Function(T) texto;
  final ValueChanged<T> onSelecionar;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  @override
  State<BuscaSugestoes<T>> createState() => _BuscaSugestoesState<T>();
}

class _BuscaSugestoesState<T extends Object> extends State<BuscaSugestoes<T>> {
  late final _texto =
      widget.controller ?? TextEditingController(text: widget.inicial);
  final _foco = FocusNode();
  int _pedido = 0;
  bool _carregando = false;
  String? _erro;
  String? _consulta;
  Future<Iterable<T>>? _emAndamento;
  @override
  void dispose() {
    _pedido++;
    _foco.dispose();
    if (widget.controller == null) _texto.dispose();
    super.dispose();
  }

  Future<Iterable<T>> _buscar(TextEditingValue value) {
    // RawAutocomplete também notifica mudanças de seleção/composição.
    // Reutilizar a busca do mesmo texto evita cancelar a consulta válida do campo.
    if (_consulta == value.text && _emAndamento != null) return _emAndamento!;
    _consulta = value.text;
    return _emAndamento = _carregar(value.text);
  }

  Future<Iterable<T>> _carregar(String texto) async {
    final pedido = ++_pedido;
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted || pedido != _pedido) return const Iterable.empty();
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final lista = await widget.buscar(texto);
      if (!mounted || pedido != _pedido) return const Iterable.empty();
      if (lista.isEmpty) setState(() => _erro = 'Nenhuma sugestão encontrada');
      return lista;
    } catch (_) {
      if (mounted && pedido == _pedido) {
        setState(() => _erro = 'Não foi possível buscar. Tente novamente.');
      }
      return const Iterable.empty();
    } finally {
      if (mounted && pedido == _pedido) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => RawAutocomplete<T>(
      textEditingController: _texto,
      focusNode: _foco,
      displayStringForOption: widget.texto,
      optionsBuilder: _buscar,
      onSelected: widget.onSelecionar,
      fieldViewBuilder: (context, texto, foco, submit) => TextFormField(
        controller: texto,
        focusNode: foco,
        enabled: widget.enabled,
        validator: widget.validator,
        onChanged: widget.onChanged,
        onFieldSubmitted: (_) => submit(),
        decoration: InputDecoration(
          labelText: widget.label,
          helperText: _erro,
          suffixIcon: _carregando
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : const Icon(Icons.search),
        ),
      ),
      optionsViewBuilder: (context, selecionar, opcoes) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 6,
          child: SizedBox(
            width: constraints.maxWidth,
            height: 220,
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: opcoes.length,
              itemBuilder: (context, index) => ListTile(
                selected: AutocompleteHighlightedOption.of(context) == index,
                title: Text(widget.texto(opcoes.elementAt(index))),
                onTap: () => selecionar(opcoes.elementAt(index)),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
