import 'http_gateway.dart';
import 'pagina.dart';

class ItemCatalogo {
  const ItemCatalogo(this.id, this.descricao, this.precoSugerido, this.ativo);
  final int id;
  final String descricao;
  final double? precoSugerido;
  final bool ativo;
  factory ItemCatalogo.fromJson(Map<String, dynamic> j) => ItemCatalogo(
    j['id'],
    j['descricao'],
    (j['precoSugerido'] as num?)?.toDouble(),
    j['ativo'] == true,
  );
}

abstract interface class ConsultaCatalogo {
  Future<Pagina<ItemCatalogo>> listar({
    int page = 0,
    String q = '',
    bool incluirInativos = false,
  });
}

abstract interface class ManutencaoCatalogo {
  Future<void> salvar({
    int? id,
    required String descricao,
    double? precoSugerido,
    bool ativo = true,
  });
}

class HttpCatalogoRepository implements ConsultaCatalogo, ManutencaoCatalogo {
  HttpCatalogoRepository(this.http);
  final HttpGateway http;
  @override
  Future<Pagina<ItemCatalogo>> listar({
    int page = 0,
    String q = '',
    bool incluirInativos = false,
  }) async => Pagina.fromJson(
    await http.send(
      'GET',
      '/catalogo',
      query: {
        'page': '$page',
        'size': '20',
        'q': q,
        'incluirInativos': '$incluirInativos',
      },
    ),
    ItemCatalogo.fromJson,
  );
  @override
  Future<void> salvar({
    int? id,
    required String descricao,
    double? precoSugerido,
    bool ativo = true,
  }) async {
    await http.send(
      id == null ? 'POST' : 'PUT',
      id == null ? '/catalogo' : '/catalogo/$id',
      body: {
        'descricao': descricao,
        'precoSugerido': precoSugerido,
        'ativo': ativo,
      },
    );
  }
}
