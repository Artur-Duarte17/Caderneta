import 'package:caderneta/dev/fakes.dart';
import 'package:caderneta/widgets/app_shell.dart';
import 'package:caderneta/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app_test.dart' show abrir, fechar, user;

void _ir(WidgetTester tester, String rota) =>
    GoRouter.of(tester.element(find.byType(AppShell))).go(rota);

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets('ao voltar para uma tela, os dados aparecem na hora (cache)', (
    tester,
  ) async {
    final servidor = ServidorSimulado(
      latencia: const Duration(milliseconds: 400),
    )..usuario = user('GERENTE');
    final runtime = await abrir(tester, servidor: servidor, path: '/clientes');
    expect(find.text('Cliente A'), findsWidgets);
    expect(runtime.cache.tamanho, greaterThan(0));

    _ir(tester, '/vendas');
    await tester.pumpAndSettle();

    _ir(tester, '/clientes');
    await tester.pump(const Duration(milliseconds: 50));
    // Sem tela de "Carregando": a lista guardada já está visível e a
    // atualização acontece em segundo plano.
    expect(find.byType(LoadingState), findsNothing);
    expect(find.text('Cliente A'), findsWidgets);
    expect(find.byType(BarraAtualizando), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(BarraAtualizando), findsNothing);
    await fechar(tester);
  });

  testWidgets('o cache é apagado ao sair da conta', (tester) async {
    final runtime = await abrir(tester, perfil: 'GERENTE', path: '/clientes');
    expect(runtime.cache.tamanho, greaterThan(0));
    await runtime.sessao.sair();
    await tester.pumpAndSettle();
    expect(runtime.cache.tamanho, 0);
    expect(runtime.cache.ler<Object>('clientes', (0, '')), isNull);
    await fechar(tester);
  });

  testWidgets('cards surgem com fade e subindo, e terminam no lugar', (
    tester,
  ) async {
    await abrir(tester, perfil: 'GERENTE', path: '/clientes');
    // Depois de assentar, tudo está opaco e sem deslocamento.
    final surgir = find.byType(Surgir);
    expect(surgir, findsWidgets);
    for (final f in tester.widgetList<FadeTransition>(
      find.descendant(of: surgir, matching: find.byType(FadeTransition)),
    )) {
      expect(f.opacity.value, 1);
    }
    await fechar(tester);
  });

  testWidgets('Surgir: começa invisível e abaixo, termina visível', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Surgir(ordem: 2, child: Text('olá'))),
    );
    FadeTransition fade() => tester.widget<FadeTransition>(
      find.descendant(
        of: find.byType(Surgir),
        matching: find.byType(FadeTransition),
      ),
    );
    Offset deslocamento() {
      final t = tester
          .widget<Transform>(
            find.descendant(
              of: find.byType(Surgir),
              matching: find.byType(Transform),
            ),
          )
          .transform
          .getTranslation();
      return Offset(t.x, t.y);
    }

    expect(fade().opacity.value, 0);
    expect(deslocamento().dy, greaterThan(0));
    await tester.pump(const Duration(milliseconds: 250));
    final meio = fade().opacity.value;
    expect(meio, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(fade().opacity.value, 1);
    expect(deslocamento().dy, 0);
  });

  testWidgets('Surgir respeita "reduzir movimento"', (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(home: Surgir(child: Text('olá'))),
      ),
    );
    final fade = tester.widget<FadeTransition>(
      find.descendant(
        of: find.byType(Surgir),
        matching: find.byType(FadeTransition),
      ),
    );
    expect(fade.opacity.value, 1);
  });
}
