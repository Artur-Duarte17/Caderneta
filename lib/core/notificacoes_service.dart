import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api.dart';
import 'models.dart';

/// Mantém a lista de notificações e o contador do menu, consultando o backend
/// periodicamente (o backend não expõe WebSocket). Quando chega notificação de
/// venda/pagamento/cliente, incrementa [revisao] para as telas abertas recarregarem.
class NotificacoesService extends ChangeNotifier {
  NotificacoesService._();
  static final instance = NotificacoesService._();

  final revisao = ValueNotifier<int>(0);
  final novas = ValueNotifier<Notificacao?>(null);

  List<Notificacao> itens = [];
  bool carregando = true;
  String? erro;
  Timer? _timer;
  bool _jaCarregou = false;
  static const _intervalo = Duration(seconds: 30);

  int get naoLidas => itens.where((n) => !n.lida).length;

  void iniciar() {
    carregar();
    _timer ??= Timer.periodic(_intervalo, (_) => carregar());
  }

  /// [silencioso]: atualiza sem avisar sobre notificações novas (ex.: as
  /// geradas pela própria ação do usuário).
  Future<void> carregar({bool silencioso = false}) async {
    try {
      final lista = await Api.instance.notificacoes()
        ..sort((a, b) => (b.dataEnvio ?? DateTime(0)).compareTo(a.dataEnvio ?? DateTime(0)));
      // Comparar com a lista atual só depois do await: outra carga pode ter terminado antes.
      final idsAntigos = itens.map((n) => n.id).toSet();
      itens = lista;
      erro = null;
      final avisar = _jaCarregou && !silencioso;
      _jaCarregou = true;
      if (avisar) {
        final chegaram = lista.where((n) => !idsAntigos.contains(n.id)).toList();
        if (chegaram.isNotEmpty) {
          novas.value = chegaram.first;
          if (chegaram.any((n) => n.tipo == TipoNotif.venda || n.tipo == TipoNotif.pagamento || n.tipo == TipoNotif.cliente)) {
            revisao.value++;
          }
        }
      }
    } catch (e) {
      erro = '$e';
    }
    carregando = false;
    notifyListeners();
  }

  Future<void> marcarLida(Notificacao n) async {
    n.lida = true;
    notifyListeners();
    try {
      await Api.instance.marcarLida(n.id);
    } catch (_) {}
  }

  Future<void> marcarTodas() async {
    for (final n in itens) {
      n.lida = true;
    }
    notifyListeners();
    try {
      await Api.instance.marcarTodasLidas();
    } catch (_) {}
  }

  /// Chamado após operações locais (criar venda, registrar pagamento…).
  /// Também sincroniza as notificações sem exibir aviso das geradas pelo próprio usuário.
  void dadosAlterados() {
    revisao.value++;
    carregar(silencioso: true);
  }
}
