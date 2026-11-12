import 'package:flutter/services.dart';

/// Filtros de digitação para campos numéricos: letras e símbolos são descartados ao digitar ou colar.
/// A validação de faixa (mínimo, máximo, casas decimais) continua nos validadores de cada campo.

/// Inteiros sem sinal (quantidade, dias): só dígitos, até [maxDigitos].
List<TextInputFormatter> somenteInteiro({int maxDigitos = 9}) => [
  FilteringTextInputFormatter.digitsOnly,
  LengthLimitingTextInputFormatter(maxDigitos),
];

/// Dinheiro em reais: dígitos, ponto de milhar e uma vírgula com até 2 casas ("1.234,56").
/// Também aceita ponto como separador decimal ("1234.56"), como o [parseCentavos] já aceita.
class ValorMonetarioInputFormatter extends TextInputFormatter {
  ValorMonetarioInputFormatter({this.maxCaracteres = 16});

  final int maxCaracteres;
  static final _naoPermitido = RegExp(r'[^0-9.,]');
  static final _formato = RegExp(r'^$|^\d[\d.]*(,\d{0,2})?$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final texto = newValue.text.replaceAll(_naoPermitido, '');
    if (texto.length > maxCaracteres || !_formato.hasMatch(texto)) {
      return oldValue;
    }
    if (texto == newValue.text) return newValue;
    // Remove caracteres inválidos mantendo o cursor no mesmo ponto relativo.
    final fim = newValue.selection.end < 0
        ? newValue.text.length
        : newValue.selection.end.clamp(0, newValue.text.length);
    final removidosAntes = _naoPermitido
        .allMatches(newValue.text.substring(0, fim))
        .length;
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: fim - removidosAntes),
    );
  }
}

List<TextInputFormatter> somenteValorMonetario() => [
  ValorMonetarioInputFormatter(),
];

const tecladoValor = TextInputType.numberWithOptions(decimal: true);
