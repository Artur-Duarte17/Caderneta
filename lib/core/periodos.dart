import 'format.dart';

const periodos = {
  0: 'Todo o período',
  1: 'Hoje',
  7: 'Últimos 7 dias',
  30: 'Últimos 30 dias',
  90: 'Últimos 90 dias',
};

bool dentroDoPeriodo(DateTime? d, int dias) {
  if (dias == 0) return true;
  if (d == null) return false;
  return !d.isBefore(hoje().subtract(Duration(days: dias - 1)));
}
