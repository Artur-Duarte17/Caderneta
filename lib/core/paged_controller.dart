import 'package:flutter/foundation.dart';
import 'cache_telas.dart';
import 'pagina.dart';

typedef PageLoader<T> =
    Future<Pagina<T>> Function(int page, int size, Map<String, String> filtros);

class PagedController<T> extends ChangeNotifier {
  PagedController(this.load, {this.cache});
  final PageLoader<T> load;

  /// Nome da tela no [CacheTelas]: a página já vista aparece na hora e é
  /// atualizada em segundo plano.
  final String? cache;
  int page = 0, size = 20;
  Map<String, String> filtros = {};
  Pagina<T>? dados;
  Object? erro;
  bool carregando = false, _disposed = false;
  int _pedido = 0;

  Future<void> atualizar() async {
    if (_disposed) return;
    final pedido = ++_pedido;
    final consulta = _consulta();
    final guardado = cache == null
        ? null
        : CacheTelas.instance?.ler<Pagina<T>>(cache!, consulta);
    if (guardado != null) dados = guardado;
    carregando = true;
    erro = null;
    notifyListeners();
    try {
      final r = await load(page, size, Map.of(filtros));
      if (_disposed || pedido != _pedido) return;
      if (cache != null && r.content.isNotEmpty) {
        CacheTelas.instance?.gravar(cache!, consulta, r);
      }
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

  String _consulta() {
    final f = filtros.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return '$page|$size|${f.map((e) => '${e.key}=${e.value}').join('&')}';
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
