import 'package:flutter/foundation.dart';
import 'pagina.dart';

typedef PageLoader<T> =
    Future<Pagina<T>> Function(int page, int size, Map<String, String> filtros);

class PagedController<T> extends ChangeNotifier {
  PagedController(this.load);
  final PageLoader<T> load;
  int page = 0, size = 20;
  Map<String, String> filtros = {};
  Pagina<T>? dados;
  Object? erro;
  bool carregando = false, _disposed = false;
  int _pedido = 0;

  Future<void> atualizar() async {
    if (_disposed) return;
    final pedido = ++_pedido;
    carregando = true;
    erro = null;
    notifyListeners();
    try {
      final r = await load(page, size, Map.of(filtros));
      if (_disposed || pedido != _pedido) return;
      if (r.content.isEmpty &&
          page > 0 &&
          (r.totalPages == 0 || page >= r.totalPages)) {
        page = r.totalPages > 0 ? r.totalPages - 1 : 0;
        await atualizar();
        return;
      }
      dados = r;
    } catch (e) {
      if (_disposed || pedido != _pedido) return;
      erro = e;
    } finally {
      if (!_disposed && pedido == _pedido) {
        carregando = false;
        notifyListeners();
      }
    }
  }

  void filtrar(Map<String, String> value) {
    filtros = Map.of(value);
    page = 0;
    atualizar();
  }

  void tamanho(int value) {
    size = value;
    page = 0;
    atualizar();
  }

  void ir(int value) {
    page = value;
    atualizar();
  }

  @override
  void dispose() {
    _disposed = true;
    _pedido++;
    dados = null;
    super.dispose();
  }
}
