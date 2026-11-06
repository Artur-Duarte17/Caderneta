import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app_router.dart';
import 'core/app_runtime.dart';
import 'core/browser_setup.dart';
import 'core/session.dart';
import 'core/theme.dart';
import 'dev/fakes.dart';

const kMockApi = bool.fromEnvironment('MOCK_API', defaultValue: false);
void verificarModo({required bool release, required bool mock}) {
  if (release && mock) {
    throw StateError(
      'MOCK_API é permitido somente em desenvolvimento e testes.',
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  verificarModo(release: kReleaseMode, mock: kMockApi);
  prepararNavegador();
  await initializeDateFormatting('pt_BR');
  final runtime = AppRuntime(
    client: kMockApi ? criarClienteSimulado() : null,
    simulado: kMockApi,
  );
  runApp(CadernetaApp(runtime: runtime));
}

class CadernetaApp extends StatefulWidget {
  const CadernetaApp({super.key, required this.runtime, this.initialLocation});
  final AppRuntime runtime;
  final String? initialLocation;
  @override
  State<CadernetaApp> createState() => _CadernetaAppState();
}

class _CadernetaAppState extends State<CadernetaApp> {
  late final GoRouter _router;
  @override
  void initState() {
    super.initState();
    _router = criarRouter(
      widget.runtime,
      initialLocation: widget.initialLocation,
    );
    unawaited(widget.runtime.sessao.restaurar());
  }

  @override
  void dispose() {
    _router.dispose();
    widget.runtime.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScope(
    runtime: widget.runtime,
    child: MaterialApp.router(
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
      builder: (context, child) => ListenableBuilder(
        listenable: widget.runtime.sessao,
        builder: (context, _) {
          if (widget.runtime.sessao.estado == EstadoSessao.verificando) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return KeyedSubtree(
            key: ValueKey(widget.runtime.sessao.epoca),
            child: child!,
          );
        },
      ),
    ),
  );
}
