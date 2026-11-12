import 'dart:async';

import 'package:caderneta/core/app_runtime.dart';
import 'package:caderneta/dev/fakes.dart';
import 'package:caderneta/main.dart';
import 'package:caderneta/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app_test.dart' show fechar, user;

const _atraso = Duration(milliseconds: 300);

/// Abre o app com o servidor simulado respondendo com atraso, sem esperar as cargas terminarem.
Future<ServidorSimulado> _abrirLento(
  WidgetTester tester, {
  String? perfil,
  String path = '/',
}) async {
  tester.view.physicalSize = const Size(1280, 1000);
  tester.view.devicePixelRatio = 1;
  final fake = ServidorSimulado(latencia: _atraso);
  if (perfil != null) fake.usuario = user(perfil);
  await tester.pumpWidget(
    CadernetaApp(
      runtime: AppRuntime(client: fake.client, simulado: true),
      initialLocation: path,
    ),
  );
  return fake;
}

String _textoVisivel(WidgetTester tester, Finder f) =>
    tester.widget<Text>(f).textSpan!.toPlainText();

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets('reticências animadas: os pontos mudam com o tempo', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: TextoCarregando('Carregando')),
    );
    final texto = find.byType(Text);
    final vistos = <String>{};
    for (var i = 0; i < 8; i++) {
      // O 4º "ponto" fica transparente: conta só os pontos visíveis no primeiro filho.
      final span = tester.widget<Text>(texto).textSpan! as TextSpan;
      vistos.add('${span.text}${(span.children!.first as TextSpan).text}');
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(
      vistos,
      containsAll([
        'Carregando',
        'Carregando.',
        'Carregando..',
        'Carregando...',
      ]),
    );
  });

  testWidgets('abertura do app e da tela mostram círculo e mensagem', (
    tester,
  ) async {
    await _abrirLento(tester, perfil: 'GERENTE', path: '/clientes');
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.textContaining('Verificando sua sessão'), findsOneWidget);

    // Depois da sessão, a tela de clientes mostra a própria mensagem enquanto busca os dados.
    var viu = false;
    for (var i = 0; i < 40 && !viu; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      viu = find.textContaining('Carregando clientes').evaluate().isNotEmpty;
    }
    expect(viu, isTrue);
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    await tester.pumpAndSettle();
    expect(find.textContaining('Carregando clientes'), findsNothing);
    expect(find.text('Novo cliente'), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('busca recarrega com barra "Buscando clientes" e dados na tela', (
    tester,
  ) async {
    await _abrirLento(tester, perfil: 'GERENTE', path: '/clientes');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Cliente');
    // A busca dispara na hora; a resposta leva 300 ms.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.textContaining('Buscando clientes'), findsOneWidget);
    expect(find.text('Novo cliente'), findsOneWidget, reason: 'tela continua');
    await tester.pumpAndSettle();
    expect(find.textContaining('Buscando clientes'), findsNothing);
    await fechar(tester);
  });

  testWidgets('botão Entrar mostra "Entrando" enquanto aguarda o servidor', (
    tester,
  ) async {
    await _abrirLento(tester, path: '/login');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'gerente');
    await tester.enterText(find.byType(TextFormField).at(1), 'qualquer');
    await tester.tap(find.text('Entrar'));
    await tester.pump(const Duration(milliseconds: 100));
    final entrando = find.byWidgetPredicate(
      (w) => w is TextoCarregando && w.texto == 'Entrando',
    );
    expect(entrando, findsOneWidget);
    expect(
      _textoVisivel(
        tester,
        find.descendant(of: entrando, matching: find.byType(Text)),
      ),
      startsWith('Entrando'),
    );
    await tester.pumpAndSettle();
    expect(entrando, findsNothing);
    await fechar(tester);
  });

  testWidgets(
    'executarComCarregamento mostra a janela e fecha no fim e no erro',
    (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );
      final concluir = Completer<int>();
      final resultado = executarComCarregamento(
        ctx,
        'Excluindo venda',
        () => concluir.future,
      );
      await tester.pump();
      expect(find.textContaining('Excluindo venda'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      concluir.complete(7);
      expect(await resultado, 7);
      await tester.pumpAndSettle();
      expect(find.textContaining('Excluindo venda'), findsNothing);

      final falha = executarComCarregamento<void>(
        ctx,
        'Salvando',
        () async => throw StateError('falhou'),
      );
      // Escuta o erro desde já (senão ele seria tratado como não capturado).
      final esperado = expectLater(falha, throwsStateError);
      await tester.pump();
      await esperado;
      await tester.pumpAndSettle();
      expect(find.textContaining('Salvando'), findsNothing);
    },
  );
}
