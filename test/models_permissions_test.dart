import 'package:flutter_test/flutter_test.dart';
import 'package:caderneta/core/auditoria_repository.dart';
import 'package:caderneta/core/dates.dart';
import 'package:caderneta/core/models.dart';
import 'package:caderneta/core/permissoes.dart';
import 'package:caderneta/pages/ativar_page.dart';
import 'package:caderneta/main.dart' show verificarModo;

void main() {
  test(
    'DTO real de auditoria lê ator/recurso e decodifica alterações antes de sanitizar',
    () {
      final evento = AuditoriaEvento.fromJson({
        'ator': {'login': 'maria', 'perfil': 'GERENTE'},
        'recurso': {'tipo': 'VENDA', 'id': 4},
        'alteracoes':
            '{"senhaHash":"segredo","nome":{"antes":"A","depois":"B"}}',
      });
      expect(evento.ator, 'maria');
      expect(evento.perfil, 'GERENTE');
      expect(evento.recurso, 'VENDA #4');
      expect(semSegredos(evento.json)['alteracoes'], {
        'nome': {'antes': 'A', 'depois': 'B'},
      });
    },
  );
  test('perfis desconhecidos e ausentes ficam sem acesso', () {
    expect(Usuario.fromJson({'perfil': 'ADMIN'}).perfil, isNull);
    expect(Usuario.fromJson({}).perfil, isNull);
    for (final p in Perfil.values) {
      expect(Perfil.parse(p.name.toUpperCase()), p);
    }
    for (final acao in Acao.values) {
      expect(pode(null, acao), false);
    }
    expect(pode(Perfil.funcionario, Acao.editarVenda), true);
    expect(pode(Perfil.gerente, Acao.editarVenda), true);
    expect(rotaPermitida(Perfil.cliente, '/clientes'), false);
    expect(rotaPermitida(Perfil.cliente, '/minha/compras'), true);
    expect(rotaPermitida(Perfil.funcionario, '/auditoria'), false);
  });
  test('next aceita somente rota interna conhecida e permitida', () {
    expect(destinoSeguro('/clientes', Perfil.gerente), '/clientes');
    for (final next in [
      '//evil.com',
      'https://x',
      'javascript:',
      '/\\evil.com',
      '/%2F%2Fevil.com',
      '/desconhecida',
      '/auditoria',
    ]) {
      expect(destinoSeguro(next, Perfil.cliente), '/minha');
    }
  });
  test('8 tipos exatos, fallback e campo tipo do contrato', () {
    expect(TipoEvento.values.length, 8);
    expect(
      TipoEvento.permitidos(Perfil.funcionario).map((e) => e.name).toSet(),
      {'CADASTRO_CLIENTE', 'COMPRA_REALIZADA', 'PAGAMENTO_RECEBIDO'},
    );
    final evento = EventoHistorico.fromJson({
      'id': 1,
      'tipo': 'NOVO',
      'tipoNotificacao': 'COMPRA_REALIZADA',
    });
    expect(evento.tipo, isNull);
    for (final t in TipoEvento.values) {
      expect(EventoHistorico.fromJson({'id': 1, 'tipo': t.name}).tipo, t);
    }
  });
  test('datas ISO, offset, sem fuso, Jackson e null', () {
    expect(parseData('2026-11-05T12:00:00Z'), DateTime.utc(2026, 11, 5, 12));
    expect(
      parseData('2026-11-05T09:00:00-03:00'),
      DateTime.utc(2026, 11, 5, 12),
    );
    expect(parseData('2026-11-05T00:00:00'), DateTime(2026, 11, 5));
    expect(parseData([2026, 11, 5, 9, 30]), DateTime(2026, 11, 5, 9, 30));
    expect(parseData(null), isNull);
    final limites = limitesPeriodo(
      DateTime(2026, 12, 31, 15),
      DateTime(2026, 12, 31),
    );
    expect(DateTime.parse(limites['inicio']!), DateTime(2026, 12, 31).toUtc());
    expect(DateTime.parse(limites['fim']!), DateTime(2027, 1, 1).toUtc());
  });
  test('auditoria remove segredos recursivamente', () {
    expect(
      semSegredos({
        'antes': {'nome': 'A', 'senhaHash': 'x'},
        'token': 'x',
        'lista': [
          {'codigoConvite': 'x', 'ativo': true},
        ],
      }),
      {
        'antes': {'nome': 'A'},
        'lista': [
          {'ativo': true},
        ],
      },
    );
  });
  test('CPF exige dígitos verificadores e release recusa simulação', () {
    expect(cpfValido('529.982.247-25'), true);
    expect(cpfValido('11111111111'), false);
    expect(cpfValido('52998224726'), false);
    expect(() => verificarModo(release: true, mock: true), throwsStateError);
    verificarModo(release: true, mock: false);
  });
}
