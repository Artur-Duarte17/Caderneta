import 'package:flutter_test/flutter_test.dart';
import 'package:caderneta/core/app_runtime.dart';
import 'package:caderneta/core/api_error.dart';
import 'package:caderneta/dev/fakes.dart';

void main() {
  test(
    'dois clientes recebem somente recursos pessoais; troca limpa histórico',
    () async {
      final fake = ServidorSimulado(latencia: Duration.zero);
      final r = AppRuntime(client: fake.client, simulado: true);
      addTearDown(r.dispose);
      await r.sessao.restaurar();
      await r.sessao.entrar('cliente.a', 'qualquer');
      fake.caminhos.clear();
      final a = await r.minha.compras(0, 20);
      await r.minha.dividas(0, 20);
      await r.minha.pagamentos(0, 20);
      final history = await r.historicoRepo.listar(pessoal: true);
      expect(a.content.every((v) => v.clienteId == 20), true);
      expect(
        history.content.every((e) => e.mensagem.contains('Cliente A')),
        true,
      );
      expect(fake.caminhos.every((p) => p.startsWith('/api/me/')), true);
      await r.sessao.sair();
      expect(r.historico.novosEventos, 0);
      await r.sessao.entrar('cliente.b', 'qualquer');
      final b = await r.minha.compras(0, 20);
      expect(b.content.every((v) => v.clienteId == 21), true);
      expect(
        b.content
            .map((v) => v.id)
            .toSet()
            .intersection(a.content.map((v) => v.id).toSet()),
        isEmpty,
      );
    },
  );
  test(
    'funcionário tem total filtrado e tipo proibido retorna 403 sem deslogar',
    () async {
      final fake = ServidorSimulado(latencia: Duration.zero);
      final r = AppRuntime(client: fake.client);
      addTearDown(r.dispose);
      await r.sessao.entrar('funcionario', 'qualquer');
      final history = await r.historicoRepo.listar(pessoal: false, size: 50);
      expect(history.totalElements, 36);
      expect(
        history.content.every(
          (e) => [
            'CADASTRO_CLIENTE',
            'COMPRA_REALIZADA',
            'PAGAMENTO_RECEBIDO',
          ].contains(e.tipo?.name),
        ),
        true,
      );
      await expectLater(
        r.historicoRepo.listar(
          pessoal: false,
          filtros: {'tipo': 'CONFIRMACAO_COMPRA'},
        ),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)),
      );
      expect(r.sessao.autenticado, true);
    },
  );
  test(
    'convite é gerado explicitamente, ativação não autentica e reuso falha',
    () async {
      final fake = ServidorSimulado(latencia: Duration.zero);
      final r = AppRuntime(client: fake.client, simulado: true);
      addTearDown(r.dispose);
      await r.sessao.entrar('gerente', 'qualquer');
      final novo = await r.gateway.send(
        'POST',
        '/clientes',
        body: {'nome': 'Novo Cliente', 'cpf': '52998224725'},
      );
      final convite = await r.acessos.convite(novo['id']);
      await r.sessao.sair();
      final dados = {
        'cpf': '52998224725',
        'codigoConvite': convite.codigo,
        'login': 'novo',
        'senha': 'qualquer',
      };
      await r.sessao.auth.ativar(dados);
      expect(r.sessao.autenticado, false);
      expect(fake.usuario, isNull);
      await expectLater(
        r.sessao.auth.ativar({...dados, 'login': 'outro'}),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 409)),
      );
    },
  );
}
