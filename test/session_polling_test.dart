import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:caderneta/core/api_error.dart';
import 'package:caderneta/core/auth_repository.dart';
import 'package:caderneta/core/historico_repository.dart';
import 'package:caderneta/core/historico_service.dart';
import 'package:caderneta/core/models.dart';
import 'package:caderneta/core/pagina.dart';
import 'package:caderneta/core/session.dart';

class AuthStub implements AuthRepository {
  Usuario? usuario;
  Object? falhaLogout;
  final mePendente = Completer<Usuario>();
  bool aguardarMe = false;
  @override
  Future<void> renovarCsrf() async {}
  @override
  Future<Usuario> me() async {
    if (aguardarMe) return mePendente.future;
    if (usuario == null) throw const ApiException('sem sessão', status: 401);
    return usuario!;
  }

  @override
  Future<Usuario> login(String login, String senha) async => usuario = Usuario(
    id: login == 'a' ? 1 : 2,
    pessoaId: login == 'a' ? 20 : 21,
    nome: login,
    perfil: Perfil.cliente,
  );
  @override
  Future<void> logout() async {
    if (falhaLogout != null) throw falhaLogout!;
    usuario = null;
  }

  @override
  Future<void> ativar(Map<String, dynamic> dados) async {}
}

class HistoricoStub implements HistoricoRepository {
  int chamadas = 0, maior = 10;
  Completer<Pagina<EventoHistorico>>? pendente;
  @override
  Future<Pagina<EventoHistorico>> listar({
    required bool pessoal,
    int page = 0,
    int size = 20,
    Map<String, String> filtros = const {},
  }) async {
    chamadas++;
    if (pendente != null) return pendente!.future;
    return Pagina(
      content: [EventoHistorico(id: maior, mensagem: 'Evento')],
      number: 0,
      size: size,
      totalElements: 1,
      totalPages: 1,
    );
  }
}

void main() {
  test(
    'restauração começa verificando e 401 termina sem aviso de expiração',
    () async {
      final s = SessaoController(AuthStub());
      addTearDown(s.dispose);
      expect(s.estado, EstadoSessao.verificando);
      await s.restaurar();
      expect(s.estado, EstadoSessao.naoAutenticado);
      expect(s.aviso, isNull);
    },
  );
  test('expiração é idempotente e limpa usuário uma única vez', () async {
    final s = SessaoController(AuthStub());
    addTearDown(s.dispose);
    await s.entrar('a', 'senha');
    final epoca = s.epoca;
    s.expirar();
    s.expirar();
    s.expirar();
    expect(s.epoca, epoca + 1);
    expect(s.usuario, isNull);
    expect(s.aviso, contains('expirou'));
  });
  test(
    'logout com falha limpa conta e informa ausência de confirmação do servidor',
    () async {
      final auth = AuthStub()..falhaLogout = const SemConexao();
      final s = SessaoController(auth);
      addTearDown(s.dispose);
      await s.entrar('a', 'senha');
      await s.sair();
      expect(s.autenticado, false);
      expect(s.usuario, isNull);
      expect(s.aviso, contains('não foi possível confirmar'));
    },
  );
  test(
    'logout 401 é encerramento local normal e permite outra conta',
    () async {
      final auth = AuthStub()
        ..falhaLogout = const ApiException('expirada', status: 401);
      final s = SessaoController(auth);
      addTearDown(s.dispose);
      await s.entrar('a', 'senha');
      await s.sair();
      expect(s.aviso, isNull);
      await s.entrar('b', 'senha');
      expect(s.usuario!.nome, 'b');
    },
  );
  testWidgets(
    'polling tem um timer, pausa oculto, consulta no retorno e para no logout',
    (tester) async {
      final sessao = SessaoController(AuthStub()), repo = HistoricoStub();
      var visivel = true;
      void Function()? mudou;
      final service = HistoricoService(
        sessao,
        repo,
        visivel: () => visivel,
        observar: (callback) {
          mudou = callback;
          return () {};
        },
      );
      await sessao.entrar('a', 'senha');
      await tester.pump();
      expect(repo.chamadas, 1);
      service.iniciar();
      service.iniciar();
      await tester.pump(const Duration(seconds: 30));
      expect(repo.chamadas, 2);
      visivel = false;
      mudou!();
      await tester.pump(const Duration(seconds: 90));
      expect(repo.chamadas, 2);
      repo.maior = 11;
      visivel = true;
      mudou!();
      await tester.pump();
      expect(repo.chamadas, 3);
      expect(service.novosEventos, 1);
      expect(service.revisao.value, 1);
      await sessao.sair();
      await tester.pump(const Duration(seconds: 90));
      expect(repo.chamadas, 3);
      expect(service.novosEventos, 0);
      service.dispose();
      sessao.dispose();
    },
  );
  testWidgets(
    'polling não sobrepõe consultas e descarta resultado depois do logout',
    (tester) async {
      final sessao = SessaoController(AuthStub()),
          repo = HistoricoStub()
            ..pendente = Completer<Pagina<EventoHistorico>>();
      final service = HistoricoService(sessao, repo);
      await sessao.entrar('a', 'senha');
      await tester.pump();
      await tester.pump(const Duration(seconds: 90));
      expect(repo.chamadas, 1);
      await sessao.sair();
      repo.pendente!.complete(
        Pagina(
          content: [EventoHistorico(id: 99, mensagem: 'A')],
          number: 0,
          size: 10,
          totalElements: 1,
          totalPages: 1,
        ),
      );
      await tester.pump();
      expect(service.novosEventos, 0);
      expect(service.revisao.value, 0);
      service.dispose();
      sessao.dispose();
    },
  );
}
