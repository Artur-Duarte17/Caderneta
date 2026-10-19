import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/notificacoes_service.dart';
import 'core/theme.dart';
import 'pages/clientes_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/notificacoes_page.dart';
import 'pages/pagamentos_page.dart';
import 'pages/relatorios_page.dart';
import 'pages/vendas_page.dart';
import 'widgets/app_shell.dart';

Future<void> main() async {
  usePathUrlStrategy();
  await initializeDateFormatting('pt_BR');
  NotificacoesService.instance.iniciar();
  runApp(const CadernetaApp());
}

GoRoute _rota(String path, Widget page) =>
    GoRoute(path: path, pageBuilder: (_, _) => NoTransitionPage(child: page));

final _router = GoRouter(
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(location: state.uri.path, child: child),
      routes: [
        _rota('/', const DashboardPage()),
        _rota('/clientes', const ClientesPage()),
        _rota('/vendas', const VendasPage()),
        _rota('/pagamentos', const PagamentosPage()),
        _rota('/relatorios', const RelatoriosPage()),
        _rota('/notificacoes', const NotificacoesPage()),
      ],
    ),
  ],
);

class CadernetaApp extends StatelessWidget {
  const CadernetaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'Caderneta - Vendas a Prazo',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        routerConfig: _router,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      );
}
