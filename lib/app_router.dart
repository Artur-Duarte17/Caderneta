import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/app_runtime.dart';
import 'core/permissoes.dart';
import 'core/session.dart';
import 'pages/acesso_negado_page.dart';
import 'pages/acessos_page.dart';
import 'pages/ativar_page.dart';
import 'pages/auditoria_page.dart';
import 'pages/clientes_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/historico_page.dart';
import 'pages/login_page.dart';
import 'pages/minha/caderneta_page.dart';
import 'pages/pagamentos_page.dart';
import 'pages/relatorios_page.dart';
import 'pages/vendas_page.dart';
import 'widgets/app_shell.dart';

GoRoute _rota(String path, Widget page) => GoRoute(
  path: path,
  pageBuilder: (_, _) => NoTransitionPage(child: page),
);

GoRouter criarRouter(AppRuntime runtime, {String? initialLocation}) {
  final sessao = runtime.sessao;
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: sessao,
    redirect: (context, state) {
      if (sessao.estado == EstadoSessao.verificando) return null;
      final path = state.uri.path;
      final publica = path == '/login' || path == '/ativar';
      if (!sessao.autenticado) {
        return publica
            ? null
            : Uri(path: '/login', queryParameters: {'next': path}).toString();
      }
      final perfil = sessao.usuario?.perfil;
      if (publica) {
        return destinoSeguro(state.uri.queryParameters['next'], perfil);
      }
      if (path == '/notificacoes') {
        return perfil == Perfil.cliente ? '/minha/historico' : '/historico';
      }
      if (path == '/' && perfil == Perfil.cliente) return '/minha';
      if (!rotaPermitida(perfil, path)) return '/acesso-negado';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, _) => LoginPage(sessao: sessao),
      ),
      _rota('/ativar', const AtivarPage()),
      ShellRoute(
        builder: (_, state, child) => AppShell(
          key: ValueKey(sessao.epoca),
          location: state.uri.path,
          child: child,
        ),
        routes: [
          _rota('/', const DashboardPage()),
          _rota('/clientes', const ClientesPage()),
          _rota('/vendas', const VendasPage()),
          _rota('/pagamentos', const PagamentosPage()),
          _rota('/relatorios', const RelatoriosPage()),
          _rota('/historico', const HistoricoPage()),
          _rota('/notificacoes', const SizedBox.shrink()),
          _rota('/auditoria', const AuditoriaPage()),
          _rota('/acessos', const AcessosPage()),
          _rota('/acesso-negado', const AcessoNegadoPage()),
          _rota('/minha', const MinhaCadernetaPage(secao: MinhaSecao.resumo)),
          _rota(
            '/minha/compras',
            const MinhaCadernetaPage(secao: MinhaSecao.compras),
          ),
          _rota(
            '/minha/dividas',
            const MinhaCadernetaPage(secao: MinhaSecao.dividas),
          ),
          _rota(
            '/minha/pagamentos',
            const MinhaCadernetaPage(secao: MinhaSecao.pagamentos),
          ),
          _rota('/minha/historico', const HistoricoPage(pessoal: true)),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => context.go(
            sessao.autenticado ? entrada(sessao.usuario?.perfil) : '/login',
          ),
          child: const Text('Página não encontrada · Voltar ao início'),
        ),
      ),
    ),
  );
}
