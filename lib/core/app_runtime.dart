import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'acessos_repository.dart';
import 'api.dart';
import 'auditoria_repository.dart';
import 'auth_repository.dart';
import 'cache_telas.dart';
import 'historico_repository.dart';
import 'historico_service.dart';
import 'http_gateway.dart';
import 'minha_caderneta_repository.dart';
import 'session.dart';

class AppRuntime {
  AppRuntime({
    http.Client? client,
    String base = apiBaseUrl,
    bool simulado = false,
  }) {
    gateway = HttpGateway(client: client, base: base);
    sessao = SessaoController(HttpAuthRepository(gateway));
    cache = CacheTelas(sessao);
    CacheTelas.instance = cache;
    gateway.epoca = () => sessao.epoca;
    gateway.usuarioId = () => sessao.usuario?.id;
    gateway.aoExpirar = () {
      gateway.csrf.limpar();
      sessao.expirar();
    };
    gateway.verificarSessao = () async {
      await gateway.send('GET', '/auth/me');
    };
    Api.instance = Api(gateway: gateway);
    historicoRepo = HttpHistoricoRepository(gateway);
    minha = HttpMinhaCadernetaRepository(gateway);
    acessos = HttpAcessosRepository(gateway, suportaBusca: simulado);
    auditoria = HttpAuditoriaRepository(gateway);
    historico = HistoricoService(sessao, historicoRepo);
    HistoricoService.instance = historico;
  }
  late final HttpGateway gateway;
  late final SessaoController sessao;
  late final CacheTelas cache;
  late final HistoricoRepository historicoRepo;
  late final MinhaCadernetaRepository minha;
  late final AcessosRepository acessos;
  late final AuditoriaRepository auditoria;
  late final HistoricoService historico;
  void dispose() {
    historico.dispose();
    cache.dispose();
    sessao.dispose();
    gateway.dispose();
  }
}

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.runtime, required super.child});
  final AppRuntime runtime;
  static AppRuntime of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.runtime;
  @override
  bool updateShouldNotify(AppScope oldWidget) => runtime != oldWidget.runtime;
}
