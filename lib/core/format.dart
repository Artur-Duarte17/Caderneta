import 'package:intl/intl.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');
final _data = DateFormat('dd/MM/yyyy', 'pt_BR');
final _dataHora = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');

String moeda(num? v) => _moeda.format(v ?? 0);
String data(DateTime? d) => d == null ? '—' : _data.format(d);
String dataHora(DateTime? d) => d == null ? '—' : _dataHora.format(d);
String isoDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

String iniciais(String nome) {
  final partes = nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (partes.isEmpty) return '?';
  if (partes.length == 1) return partes.first[0].toUpperCase();
  return (partes.first[0] + partes.last[0]).toUpperCase();
}

String tempoRelativo(DateTime? d) {
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'agora';
  if (diff.inHours < 1) return 'há ${diff.inMinutes} min';
  if (diff.inDays < 1) return 'há ${diff.inHours} h';
  if (diff.inDays < 7) return 'há ${diff.inDays} dia${diff.inDays > 1 ? 's' : ''}';
  return data(d);
}

/// Converte texto digitado ("1.234,56" ou "1234.56") em número.
double? parseValor(String s) {
  var t = s.trim().replaceAll(r'R$', '').replaceAll(' ', '');
  if (t.isEmpty) return null;
  if (t.contains(',')) t = t.replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(t);
}

DateTime hoje() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}
