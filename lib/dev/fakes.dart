import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Client criarClienteSimulado() => ServidorSimulado().client;

/// Transporte de desenvolvimento. Não persiste credenciais nem simula garantias do servidor real.
class ServidorSimulado {
  ServidorSimulado({this.latencia = const Duration(milliseconds: 150)}) {
    client = MockClient(_handle);
  }
  static const marcador = 'CADERNETA_SIMULACAO_DEV';
  late final http.Client client;
  final Duration latencia;
  final falhas = <String, int>{};
  final caminhos = <String>[];
  Map<String, dynamic>? usuario;
  int _token = 1, _sequencia = 100;
  final _convites = <String, int>{};
  final _contas = <Map<String, dynamic>>[
    {
      'id': 1,
      'pessoaId': 10,
      'nome': 'Gerente de exemplo',
      'login': 'gerente',
      'perfil': 'GERENTE',
      'ativo': true,
    },
    {
      'id': 2,
      'pessoaId': 11,
      'nome': 'Funcionário de exemplo',
      'login': 'funcionario',
      'perfil': 'FUNCIONARIO',
      'ativo': true,
    },
    {
      'id': 3,
      'pessoaId': 20,
      'nome': 'Cliente A',
      'login': 'cliente.a',
      'perfil': 'CLIENTE',
      'ativo': true,
    },
    {
      'id': 4,
      'pessoaId': 21,
      'nome': 'Cliente B',
      'login': 'cliente.b',
      'perfil': 'CLIENTE',
      'ativo': true,
    },
  ];
  final _clientes = <Map<String, dynamic>>[
    {
      'id': 20,
      'nome': 'Cliente A',
      'cpf': '52998224725',
      'telefone': '(11) 90000-0020',
      'limiteCredito': 1000,
      'prazoPagamentoPadraoDias': 30,
    },
    {
      'id': 21,
      'nome': 'Cliente B',
      'cpf': '11144477735',
      'telefone': '(11) 90000-0021',
      'limiteCredito': 1500,
      'prazoPagamentoPadraoDias': 30,
    },
  ];
  late final _vendas = <Map<String, dynamic>>[
    for (var n = 0; n < 46; n++)
      {
        'id': n + 1,
        'clienteId': n.isEven ? 20 : 21,
        'dividaId': n + 1,
        'valorTotal': 50.0 + n,
        'dataHora': DateTime.now()
            .subtract(Duration(days: n % 14))
            .toUtc()
            .toIso8601String(),
        'itens': [
          {
            'descricaoProduto': 'Compra de exemplo ${n + 1}',
            'quantidade': 1,
            'precoUnitario': 50 + n,
          },
        ],
      },
  ];
  late final _dividas = <Map<String, dynamic>>[
    for (final v in _vendas)
      {
        'id': v['id'],
        'clienteId': v['clienteId'],
        'vendaId': v['id'],
        'valorOriginal': v['valorTotal'],
        'valorPendente': v['valorTotal'],
        'statusDivida': 'ABERTA',
        'dataEmissao': DateTime.now().toIso8601String().substring(0, 10),
        'dataVencimento': DateTime.now()
            .add(Duration(days: (v['id'] as int) % 10 - 3))
            .toIso8601String()
            .substring(0, 10),
        'pagamentos': <Map<String, dynamic>>[],
      },
  ];
  late final _eventos = <Map<String, dynamic>>[
    for (var n = 96; n > 0; n--)
      {
        'id': n,
        'tipo': _tipos[n % _tipos.length],
        'mensagem': 'Evento $n de ${n.isEven ? 'Cliente A' : 'Cliente B'}',
        'dataEnvio': DateTime.now()
            .subtract(Duration(minutes: 97 - n))
            .toUtc()
            .toIso8601String(),
        'destinatario': {
          'id': n.isEven ? 20 : 21,
          'nome': n.isEven ? 'Cliente A' : 'Cliente B',
        },
      },
  ];
  static const _tipos = [
    'LEMBRETE_PAGAMENTO',
    'AVISO_DIVIDA_VENCIDA',
    'CONFIRMACAO_COMPRA',
    'CONFIRMACAO_PAGAMENTO',
    'CADASTRO_CLIENTE',
    'PAGAMENTO_RECEBIDO',
    'COMPRA_REALIZADA',
    'LEMBRETE_VENCIMENTO',
  ];
  static const _operacionais = [
    'CADASTRO_CLIENTE',
    'PAGAMENTO_RECEBIDO',
    'COMPRA_REALIZADA',
  ];

  void expirar() {
    usuario = null;
  }

  http.Response _json(dynamic body, [int status = 200]) => http.Response(
    body == null ? '' : jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
  http.Response _erro(
    int status, [
    String code = 'ERRO',
    String message = 'Operação não permitida.',
  ]) => _json({'code': code, 'message': message}, status);

  Future<http.Response> _handle(http.Request req) async {
    caminhos.add(req.url.path);
    if (latencia > Duration.zero) await Future<void>.delayed(latencia);
    final path = req.url.path.replaceFirst('/api', '');
    final forced = falhas.remove(path);
    if (forced != null) return _erro(forced);
    final method = req.method, q = req.url.queryParameters;
    final body = req.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(req.body) as Map<String, dynamic>;
    if (path == '/auth/csrf') {
      return _json({'token': '$_token', 'headerName': 'X-CSRF-TOKEN'});
    }
    if (!['GET', 'HEAD'].contains(method) &&
        req.headers['X-CSRF-TOKEN'] != '$_token') {
      return _erro(403, 'CSRF_INVALID');
    }
    if (path == '/auth/login') {
      final conta = _contas
          .where((c) => c['login'] == body['login'] && c['ativo'] == true)
          .firstOrNull;
      if (conta == null || (body['senha'] as String? ?? '').isEmpty) {
        return _erro(401);
      }
      usuario = Map.of(conta);
      _token++;
      return _json({'usuario': usuario, 'ambiente': marcador});
    }
    if (path == '/auth/logout') {
      usuario = null;
      _token++;
      return _json(null, 204);
    }
    if (path == '/auth/registro-cliente') {
      final codigoInformado = '${body['codigoConvite']}'
          .replaceAll(RegExp(r'[\s-]'), '')
          .toUpperCase();
      final clienteId = _convites[codigoInformado];
      final cliente = _clientes
          .where((c) => c['id'] == clienteId && c['cpf'] == body['cpf'])
          .firstOrNull;
      if (cliente == null) {
        return _erro(
          409,
          'CONVITE_INVALIDO',
          'Convite inválido ou indisponível.',
        );
      }
      if (_contas.any(
        (c) => c['login'] == body['login'] || c['pessoaId'] == clienteId,
      )) {
        return _erro(409, 'LOGIN_EM_USO', 'Login ou acesso já cadastrado.');
      }
      _contas.add({
        'id': ++_sequencia,
        'pessoaId': clienteId,
        'nome': cliente['nome'],
        'login': body['login'],
        'perfil': 'CLIENTE',
        'ativo': true,
      });
      _convites.remove(codigoInformado);
      return _json(null, 201);
    }
    if (usuario == null) return _erro(401);
    final perfil = usuario!['perfil'];
    final gerente = perfil == 'GERENTE', cliente = perfil == 'CLIENTE';
    if (path == '/auth/me') return _json({'usuario': usuario});
    if (path == '/resumo' || path == '/me/resumo') {
      return _json({
        'saldo': 150.0,
        'vencidas': 2,
        'vendasMes': 100.0,
        'recebidoMes': 50.0,
        'proximoVencimento': '2026-11-20',
      });
    }
    if (path.startsWith('/me/')) {
      if (!cliente) return _erro(403);
      final pessoaId = usuario!['pessoaId'];
      if (path == '/me/vendas') {
        return _pagina(_vendas.where((v) => v['clienteId'] == pessoaId), q);
      }
      if (path == '/me/dividas') {
        return _pagina(_dividas.where((d) => d['clienteId'] == pessoaId), q);
      }
      if (path == '/me/pagamentos') {
        return _pagina(
          _dividas
              .where((d) => d['clienteId'] == pessoaId)
              .expand<Map<String, dynamic>>(
                (d) => (d['pagamentos'] as List).cast<Map<String, dynamic>>(),
              ),
          q,
        );
      }
      if (path != '/me/historico') return _erro(404);
    } else if (cliente) {
      return _erro(403);
    }
    if (path == '/historico' || path == '/me/historico') {
      if (q['tipo'] != null && !_tipos.contains(q['tipo'])) return _erro(400);
      if (perfil == 'FUNCIONARIO' &&
          q['tipo'] != null &&
          !_operacionais.contains(q['tipo'])) {
        return _erro(403);
      }
      var lista = _eventos.where(
        (e) =>
            (!cliente || e['destinatario']['id'] == usuario!['pessoaId']) &&
            (perfil != 'FUNCIONARIO' || _operacionais.contains(e['tipo'])) &&
            (q['tipo'] == null || q['tipo'] == e['tipo']),
      );
      lista = lista.where((e) {
        final date = DateTime.parse(e['dataEnvio']);
        return (q['inicio'] == null ||
                !date.isBefore(DateTime.parse(q['inicio']!))) &&
            (q['fim'] == null || date.isBefore(DateTime.parse(q['fim']!)));
      });
      return _pagina(lista, q);
    }
    if (path.startsWith('/usuarios') ||
        path == '/auditoria' ||
        path == '/auth/funcionarios' ||
        path.startsWith('/relatorios/')) {
      if (!gerente) return _erro(403);
      if (path == '/usuarios') {
        return _pagina(
          _contas.where(
            (c) =>
                q['busca'] == null ||
                '${c['nome']} ${c['login']}'.toLowerCase().contains(
                  q['busca']!.toLowerCase(),
                ),
          ),
          q,
        );
      }
      if (path.endsWith('/ativo')) {
        final id = int.tryParse(path.split('/')[2]);
        final conta = _contas.where((c) => c['id'] == id).firstOrNull;
        if (conta == null) return _erro(404);
        if (conta['perfil'] == 'GERENTE' &&
            body['ativo'] == false &&
            _contas
                    .where(
                      (c) => c['perfil'] == 'GERENTE' && c['ativo'] == true,
                    )
                    .length ==
                1) {
          return _erro(
            409,
            'ULTIMO_GERENTE',
            'O último gerente ativo não pode ser desativado.',
          );
        }
        conta['ativo'] = body['ativo'];
        return _json(null, 204);
      }
      if (path == '/auth/funcionarios') {
        if (_contas.any((c) => c['login'] == body['login'])) {
          return _erro(409, 'LOGIN_EM_USO', 'Login já cadastrado.');
        }
        _contas.add({
          'id': ++_sequencia,
          'pessoaId': _sequencia,
          'nome': body['nome'],
          'login': body['login'],
          'perfil': 'FUNCIONARIO',
          'ativo': true,
        });
        return _json(null, 201);
      }
      if (path == '/auditoria') {
        final rows = <Map<String, dynamic>>[
          for (var i = 40; i > 0; i--)
            {
              'id': i,
              'ocorridoEm': DateTime.now().toUtc().toIso8601String(),
              'ator': {'usuarioId': 1, 'login': 'gerente', 'perfil': 'GERENTE'},
              'acao': 'ATUALIZAR',
              'recurso': {'tipo': 'CLIENTE', 'id': i},
              'resultado': 'SUCESSO',
              'alteracoes': {
                'antes': {'nome': 'Nome anterior'},
                'depois': {'nome': 'Nome atualizado'},
              },
            },
        ];
        return _pagina(
          rows.where(
            (r) =>
                (q['acao'] == null || q['acao'] == r['acao']) &&
                (q['recursoTipo'] == null ||
                    q['recursoTipo'] == r['recurso']['tipo']),
          ),
          q,
        );
      }
      if (path == '/relatorios/resumo') {
        return _json({
          'vendido': 100,
          'recebido': 20,
          'saldo': 80,
          'inadimplencia': 0,
          'quantidadeVendas': 1,
          'clientesAtivos': 1,
        });
      }
      if (path == '/relatorios/clientes') return _json(_clientes);
      if (path == '/relatorios/pagamentos') {
        return _json(
          _dividas.expand((d) => (d['pagamentos'] as List)).toList(),
        );
      }
      return _json(
        path.endsWith('vendas-a-prazo')
            ? {'vendas': _vendas}
            : {'dividas': _dividas},
      );
    }
    if (path.startsWith('/clientes/') && path.endsWith('/convite')) {
      final id = int.tryParse(path.split('/')[2]);
      if (!_clientes.any((c) => c['id'] == id)) return _erro(404);
      // Mesmo formato do backend: 20 caracteres, alfabeto sem 0/O/1/I.
      const alfabeto = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      var n = ++_sequencia;
      final b = StringBuffer('DEVDEVDEVD');
      for (var i = 0; i < 10; i++) {
        b.write(alfabeto[n % alfabeto.length]);
        n ~/= alfabeto.length;
      }
      final codigo = b.toString();
      _convites[codigo] = id!;
      return _json({
        'codigo': codigo,
        'expiraEm': DateTime.now()
            .add(const Duration(days: 7))
            .toUtc()
            .toIso8601String(),
      }, 201);
    }
    if (path.startsWith('/clientes/') && method == 'GET') {
      final id = int.tryParse(path.split('/')[2]);
      final c = _clientes.where((c) => c['id'] == id).firstOrNull;
      return c == null ? _erro(404) : _json(c);
    }
    if (path == '/clientes' && method == 'GET') {
      return _pagina(
        _clientes.where(
          (c) =>
              (q['q'] ?? '').isEmpty ||
              c['nome'].toString().toLowerCase().contains(
                q['q']!.toLowerCase(),
              ),
        ),
        q,
      );
    }
    if (path == '/vendas' && method == 'GET') {
      return _pagina(
        _vendas.map(
          (v) => {
            ...v,
            'versao': 0,
            'statusDivida': 'ABERTA',
            'clienteNome': v['clienteId'] == 20 ? 'Cliente A' : 'Cliente B',
          },
        ),
        q,
      );
    }
    if (path == '/dividas' && method == 'GET') return _pagina(_dividas, q);
    if (path == '/clientes' && method == 'POST') {
      final novo = {...body, 'id': ++_sequencia};
      _clientes.add(novo);
      _evento('CADASTRO_CLIENTE', novo['id'], novo['nome']);
      return _json(novo, 201);
    }
    if (path.startsWith('/clientes/') && method == 'PUT') {
      final id = int.tryParse(path.split('/')[2]);
      final c = _clientes.where((c) => c['id'] == id).firstOrNull;
      if (c == null) return _erro(404);
      c.addAll(body);
      return _json(c);
    }
    if (path == '/vendas' && method == 'POST') {
      final itens = body['itens'] as List;
      final total = (body['valorTotal'] as num).toDouble();
      final id = ++_sequencia;
      final v = {
        'id': id,
        'clienteId': body['clienteId'],
        'dividaId': id,
        'itens': itens,
        'valorTotal': total,
        'dataHora': DateTime.now().toUtc().toIso8601String(),
      };
      _vendas.insert(0, v);
      _dividas.add({
        'id': id,
        'vendaId': id,
        'clienteId': body['clienteId'],
        'valorOriginal': total,
        'valorPendente': total,
        'statusDivida': 'ABERTA',
        'pagamentos': <Map<String, dynamic>>[],
        'dataVencimento': DateTime.now()
            .add(const Duration(days: 30))
            .toIso8601String()
            .substring(0, 10),
      });
      _evento('COMPRA_REALIZADA', body['clienteId'], 'Compra registrada');
      return _json(v, 201);
    }
    if (path.startsWith('/vendas/')) {
      final id = int.tryParse(path.split('/')[2]);
      final v = _vendas.where((v) => v['id'] == id).firstOrNull;
      if (v == null) return _erro(404);
      if (method == 'PUT') {
        if (cliente) return _erro(403);
        v.addAll(body);
      }
      return _json(v);
    }
    if (path.startsWith('/dividas/') && path.endsWith('/pagamentos')) {
      final id = int.tryParse(path.split('/')[2]);
      final d = _dividas.where((d) => d['id'] == id).firstOrNull;
      if (d == null) return _erro(404);
      final valor = (body['valorPago'] as num).toDouble(),
          saldo = (d['valorPendente'] as num).toDouble();
      if (valor <= 0 || valor > saldo) {
        return _erro(409, 'VALOR_INVALIDO', 'Valor incompatível com o saldo.');
      }
      (d['pagamentos'] as List).add({
        ...body,
        'dataPagamento': DateTime.now().toUtc().toIso8601String(),
      });
      d['valorPendente'] = saldo - valor;
      d['statusDivida'] = saldo == valor
          ? 'PAGA_TOTALMENTE'
          : 'PAGA_PARCIALMENTE';
      _evento('PAGAMENTO_RECEBIDO', d['clienteId'], 'Pagamento recebido');
      return _json(null, 201);
    }
    if (path == '/fiadores' && method == 'POST') {
      return _json({...body, 'id': ++_sequencia}, 201);
    }
    if (path.startsWith('/fiadores/associar/')) return _json(null, 204);
    return _erro(404);
  }

  void _evento(String tipo, int clienteId, String mensagem) {
    _eventos.insert(0, {
      'id': ++_sequencia,
      'tipo': tipo,
      'mensagem': mensagem,
      'dataEnvio': DateTime.now().toUtc().toIso8601String(),
      'destinatario': {'id': clienteId, 'nome': 'Cliente #$clienteId'},
    });
  }

  http.Response _pagina(
    Iterable<Map<String, dynamic>> itens,
    Map<String, String> query,
  ) {
    final page = int.tryParse(query['page'] ?? '0') ?? -1,
        size = int.tryParse(query['size'] ?? '20') ?? 0;
    if (page < 0 || size < 1 || size > 100) return _erro(400);
    final lista = itens.toList(), total = itens.length;
    return _json({
      'content': lista.skip(page * size).take(size).toList(),
      'number': page,
      'size': size,
      'totalElements': total,
      'totalPages': (total / size).ceil(),
      'first': page == 0,
      'last': (page + 1) * size >= total,
    });
  }
}
