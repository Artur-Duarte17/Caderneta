import 'session.dart';

/// Cache em memória das telas (stale-while-revalidate).
///
/// Ao reabrir uma tela, os últimos dados vistos aparecem na hora e uma nova
/// busca é feita em segundo plano. Nada é gravado no navegador
/// (localStorage/sessionStorage): recarregar a página começa do zero.
///
/// O cache é esvaziado sempre que a sessão muda (login, logout ou expiração)
/// e as chaves levam o id do usuário, então dados de um usuário ou de uma loja
/// nunca aparecem para outro.
class CacheTelas {
  CacheTelas(this._sessao, {this.limite = 60}) {
    _epoca = _sessao.epoca;
    _sessao.addListener(_aoMudarSessao);
  }

  /// Instância usada pelos widgets; trocada a cada [AppRuntime].
  static CacheTelas? instance;

  final SessaoController _sessao;
  final int limite;
  final _itens = <String, Object>{}; // mantém a ordem de inserção (LRU)
  late int _epoca;

  void _aoMudarSessao() {
    if (_sessao.epoca != _epoca || !_sessao.autenticado) {
      _epoca = _sessao.epoca;
      limpar();
    }
  }

  String? _chave(String tela, Object? consulta) {
    final usuario = _sessao.usuario?.id;
    if (usuario == null || !_sessao.autenticado) return null;
    return '$_epoca|$usuario|$tela|$consulta';
  }

  /// Último valor guardado para a tela/consulta, ou `null`.
  T? ler<T>(String tela, [Object? consulta]) {
    final k = _chave(tela, consulta);
    if (k == null) return null;
    final v = _itens.remove(k);
    if (v == null) return null;
    _itens[k] = v; // marca como usado recentemente
    return v is T ? v as T : null;
  }

  void gravar(String tela, Object? consulta, Object? valor) {
    final k = _chave(tela, consulta);
    if (k == null || valor == null) return;
    _itens.remove(k);
    _itens[k] = valor;
    while (_itens.length > limite) {
      _itens.remove(_itens.keys.first);
    }
  }

  int get tamanho => _itens.length;

  void limpar() => _itens.clear();

  void dispose() {
    _sessao.removeListener(_aoMudarSessao);
    _itens.clear();
    if (identical(instance, this)) instance = null;
  }
}
