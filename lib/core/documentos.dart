import 'package:flutter/services.dart';

/// Padronização de CPF e telefone (Brasil).
///
/// Regra: a tela mostra com máscara; a API recebe só dígitos. Valores antigos gravados com máscara
/// continuam aparecendo certos, porque a exibição sempre parte dos dígitos.

final _naoDigito = RegExp(r'\D');

/// CPF: exatamente 11 dígitos, com ou sem a máscara 000.000.000-00.
final cpfRegex = RegExp(r'^\d{3}\.?\d{3}\.?\d{3}-?\d{2}$');

/// Telefone, só dígitos: DDD (11–99) + celular (9 + 8 dígitos) ou fixo (8 dígitos iniciados em 2–5).
final telefoneRegex = RegExp(r'^[1-9]{2}(?:9\d{8}|[2-5]\d{7})$');

String soDigitos(String? valor) => (valor ?? '').replaceAll(_naoDigito, '');

bool cpfValido(String value) {
  final texto = value.trim();
  if (!cpfRegex.hasMatch(texto)) return false;
  final cpf = soDigitos(texto);
  if (cpf.split('').toSet().length == 1) return false;
  final nums = cpf.split('').map(int.parse).toList();
  for (var n = 9; n <= 10; n++) {
    var soma = 0;
    for (var i = 0; i < n; i++) {
      soma += nums[i] * (n + 1 - i);
    }
    final resto = (soma * 10) % 11;
    if ((resto == 10 ? 0 : resto) != nums[n]) return false;
  }
  return true;
}

bool telefoneValido(String? value) => telefoneRegex.hasMatch(soDigitos(value));

/// 000.000.000-00 (parcial enquanto digita). Mais de 11 dígitos: devolve como veio.
String formatarCpf(String? valor) {
  final d = soDigitos(valor);
  if (d.length > 11) return valor ?? '';
  final b = StringBuffer();
  for (var i = 0; i < d.length; i++) {
    if (i == 3 || i == 6) b.write('.');
    if (i == 9) b.write('-');
    b.write(d[i]);
  }
  return b.toString();
}

/// (00) 00000-0000 ou (00) 0000-0000 (parcial enquanto digita). Mais de 11 dígitos: como veio.
String formatarTelefone(String? valor) {
  final d = soDigitos(valor);
  if (d.length > 11) return valor ?? '';
  if (d.isEmpty) return '';
  final b = StringBuffer('(');
  for (var i = 0; i < d.length; i++) {
    if (i == 2) b.write(') ');
    // Hífen antes dos 4 últimos: posição 6 no fixo (10 dígitos), 7 no celular (11).
    if (i == (d.length == 11 ? 7 : 6) && d.length > 6) b.write('-');
    b.write(d[i]);
  }
  return b.toString();
}

/// Exibição: formata quando o valor é válido; senão mostra como foi gravado.
String exibirCpf(String? valor, {String vazio = '—'}) {
  if ((valor ?? '').trim().isEmpty) return vazio;
  return soDigitos(valor).length == 11 ? formatarCpf(valor) : valor!;
}

String exibirTelefone(String? valor, {String vazio = '—'}) {
  if ((valor ?? '').trim().isEmpty) return vazio;
  final n = soDigitos(valor).length;
  return n == 10 || n == 11 ? formatarTelefone(valor) : valor!;
}

/// Máscara durante a digitação: aceita só dígitos (até [maxDigitos]) e mantém o cursor depois do
/// mesmo dígito em que estava, mesmo editando no meio do texto.
class MascaraInputFormatter extends TextInputFormatter {
  MascaraInputFormatter(this.formatar, {required this.maxDigitos});

  factory MascaraInputFormatter.cpf() =>
      MascaraInputFormatter(formatarCpf, maxDigitos: 11);
  factory MascaraInputFormatter.telefone() =>
      MascaraInputFormatter(formatarTelefone, maxDigitos: 11);

  final String Function(String) formatar;
  final int maxDigitos;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digitos = soDigitos(newValue.text);
    if (digitos.length > maxDigitos) digitos = digitos.substring(0, maxDigitos);
    final cursor = newValue.selection.baseOffset < 0
        ? newValue.text.length
        : newValue.selection.baseOffset.clamp(0, newValue.text.length);
    final digitosAntes = soDigitos(
      newValue.text.substring(0, cursor),
    ).length.clamp(0, digitos.length);
    final texto = formatar(digitos);
    var pos = texto.length;
    if (digitosAntes < digitos.length) {
      var vistos = 0;
      for (var i = 0; i < texto.length; i++) {
        if (vistos == digitosAntes) {
          pos = i;
          break;
        }
        if (_naoDigito.hasMatch(texto[i])) continue;
        vistos++;
      }
    }
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: pos),
    );
  }
}
