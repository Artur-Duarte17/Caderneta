import 'dart:async';
import 'package:flutter/foundation.dart';
import 'historico_repository.dart';
import 'permissoes.dart';
import 'session.dart';
import 'visibility.dart';

class HistoricoService extends ChangeNotifier {
  HistoricoService(
    this.sessao,
    this.repo, {
    bool Function()? visivel,
    void Function() Function(void Function())? observar,
    this.intervalo = const Duration(seconds: 30),
  }) : visivel = visivel ?? abaVisivel {
    _removerVisibilidade = (observar ?? observarVisibilidade)(
      _visibilidadeMudou,
    );
    sessao.addListener(_sessaoMudou);
    _sessaoMudou();
  }
  static late HistoricoService instance;
  final SessaoController sessao;
  final HistoricoRepository repo;
  final bool Function() visivel;
  final Duration intervalo;
  final revisao = ValueNotifier<int>(0);
  late final void Function() _removerVisibilidade;
  Timer? _timer;
  bool _consultando = false, _disposed = false;
  int? _maiorId;
  int _epoca = -1;
  int novosEventos = 0;

  void _sessaoMudou() {
    if (_epoca != sessao.epoca || !sessao.autenticado) {
      parar();
      _epoca = sessao.epoca;
    }
    if (sessao.autenticado && sessao.usuario?.perfil != null) iniciar();
  }

  void iniciar() {
    if (_timer != null || !sessao.autenticado || _disposed) return;
    _timer = Timer.periodic(intervalo, (_) => consultar());
    unawaited(consultar());
  }

  void parar() {
    _timer?.cancel();
    _timer = null;
    _maiorId = null;
    novosEventos = 0;
  }

  void _visibilidadeMudou() {
    if (visivel() && _timer != null) unawaited(consultar());
  }

  Future<void> consultar() async {
    if (_disposed ||
        _consultando ||
        _timer == null ||
        !visivel() ||
        !sessao.autenticado) {
      return;
    }
    _consultando = true;
    final inicio = sessao.epoca;
    try {
      final page = await repo.listar(
        pessoal: sessao.usuario?.perfil == Perfil.cliente,
        size: 10,
      );
      if (_disposed || inicio != sessao.epoca || !sessao.autenticado) return;
      final ids = page.content.map((e) => e.id);
      final maxId = ids.fold<int>(0, (a, b) => a > b ? a : b);
      if (_maiorId != null && maxId > _maiorId!) {
        novosEventos += ids.where((id) => id > _maiorId!).length;
        revisao.value++;
        notifyListeners();
      }
      if (_maiorId == null || maxId > _maiorId!) _maiorId = maxId;
    } catch (_) {
      /* A tela preserva dados e oferece atualização manual. */
    } finally {
      _consultando = false;
      if (!_disposed && inicio != sessao.epoca && sessao.autenticado) {
        unawaited(consultar());
      }
    }
  }

  void consumirNovos() {
    novosEventos = 0;
  }

  void dadosAlterados() {
    if (!sessao.autenticado) return;
    revisao.value++;
    unawaited(consultar());
  }

  @override
  void dispose() {
    _disposed = true;
    parar();
    sessao.removeListener(_sessaoMudou);
    _removerVisibilidade();
    revisao.dispose();
    super.dispose();
  }
}
