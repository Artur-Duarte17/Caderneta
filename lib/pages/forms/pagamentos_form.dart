import 'package:flutter/material.dart';
import '../../core/app_runtime.dart';
import '../../core/entrada_numerica.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

class PagamentoForm extends StatefulWidget {
  const PagamentoForm({super.key, required this.divida, required this.cliente});
  final Divida divida;
  final String cliente;
  @override
  State<PagamentoForm> createState() => PagamentoFormState();
}

class PagamentoFormState extends State<PagamentoForm> {
  final _form = GlobalKey<FormState>();
  final _valor = TextEditingController();
  MetodoPagamento? _metodo;
  bool _salvando = false;

  @override
  void dispose() {
    _valor.dispose();
    super.dispose();
  }

  double get _pendente => widget.divida.valorPendente;

  Future<void> _salvar() async {
    if (_salvando || !_form.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      await AppScope.read(context).dividas.registrarPagamento(
        widget.divida.id,
        parseCentavos(_valor.text)! / 100,
        _metodo!,
      );
      if (!mounted) return;
      toast(context, 'Pagamento registrado com sucesso');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      toast(context, '$e', erro: true);
    }
  }

  Widget? _aviso() {
    final cents = parseCentavos(_valor.text);
    final v = cents == null ? null : cents / 100;
    if (v == null || v <= 0 || v > _pendente + .001) return null;
    final quita = (v - _pendente).abs() < .01;
    return Pill(
      cor: quita ? AppColors.success : AppColors.info,
      icon: quita ? Icons.check_circle : Icons.timelapse,
      label: quita
          ? 'Este pagamento quita a dívida'
          : 'Pagamento parcial · restará ${moeda(_pendente - v)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final aviso = _aviso();
    return AlertDialog(
      title: const Text('Registrar pagamento'),
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
                InfoRow(
                  'Dívida',
                  '${widget.divida.vendaId == null ? '#${widget.divida.id}' : 'Venda #${widget.divida.vendaId}'} · ${widget.cliente}',
                ),
                InfoRow(
                  'Valor pendente',
                  moeda(_pendente),
                  destaque: AppColors.danger,
                ),
                const SizedBox(height: Gap.md),
                TextFormField(
                  controller: _valor,
                  autofocus: true,
                  keyboardType: tecladoValor,
                  inputFormatters: somenteValorMonetario(),
                  decoration: InputDecoration(
                    labelText: 'Valor pago *',
                    prefixText: r'R$ ',
                    suffixIcon: TextButton(
                      onPressed: () => setState(
                        () => _valor.text = _pendente
                            .toStringAsFixed(2)
                            .replaceAll('.', ','),
                      ),
                      child: const Text('Total'),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (t) {
                    final cents = parseCentavos(t ?? '');
                    final v = cents == null ? null : cents / 100;
                    if (v == null || v <= 0) return 'Informe um valor válido';
                    if (cents! > (_pendente * 100).round()) {
                      return 'Valor maior que o pendente';
                    }
                    return null;
                  },
                ),
                if (aviso != null) ...[
                  const SizedBox(height: Gap.sm),
                  Align(alignment: Alignment.centerLeft, child: aviso),
                ],
                const SizedBox(height: Gap.md),
                DropdownButtonFormField<MetodoPagamento>(
                  isExpanded: true,
                  initialValue: _metodo,
                  decoration: const InputDecoration(
                    labelText: 'Método de pagamento *',
                  ),
                  validator: (v) => v == null ? 'Selecione o método' : null,
                  items: [
                    for (final m in MetodoPagamento.values)
                      DropdownMenuItem(value: m, child: Text(m.label)),
                  ],
                  onChanged: (v) => setState(() => _metodo = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _salvando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        BusyButton(
          label: 'Confirmar pagamento',
          busyLabel: 'Registrando pagamento',
          busy: _salvando,
          onPressed: _salvar,
        ),
      ],
    );
  }
}
