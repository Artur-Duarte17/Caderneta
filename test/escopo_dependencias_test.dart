import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caderneta/core/app_runtime.dart';
import 'package:caderneta/dev/fakes.dart';
import 'package:caderneta/widgets/async_view.dart';

void main() {
  testWidgets('atualizar um runtime não recarrega widgets de outro runtime', (
    t,
  ) async {
    final a = AppRuntime(
      client: ServidorSimulado(latencia: Duration.zero).client,
    );
    final b = AppRuntime(
      client: ServidorSimulado(latencia: Duration.zero).client,
    );
    var cargasA = 0, cargasB = 0;
    Widget painel(AppRuntime runtime, Future<String> Function() load) =>
        AppScope(
          runtime: runtime,
          child: AsyncView<String>(load: load, builder: (_, v, _) => Text(v)),
        );
    await t.pumpWidget(
      MaterialApp(
        home: Row(
          children: [
            Expanded(child: painel(a, () async => 'A${++cargasA}')),
            Expanded(child: painel(b, () async => 'B${++cargasB}')),
          ],
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('A1'), findsOneWidget);
    expect(find.text('B1'), findsOneWidget);
    a.historico.revisao.value++;
    await t.pumpAndSettle();
    expect(cargasA, 2);
    expect(cargasB, 1);
    expect(find.text('A2'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    a.dispose();
    b.dispose();
  });

  testWidgets(
    'trocar AppScope religa listener sem preservar dados da instância anterior',
    (t) async {
      final a = AppRuntime(
        client: ServidorSimulado(latencia: Duration.zero).client,
      );
      final b = AppRuntime(
        client: ServidorSimulado(latencia: Duration.zero).client,
      );
      var cargas = 0;
      Widget tela(AppRuntime runtime, String texto) => MaterialApp(
        home: AppScope(
          runtime: runtime,
          child: AsyncView<String>(
            load: () async {
              cargas++;
              return texto;
            },
            builder: (_, v, _) => Text(v),
          ),
        ),
      );
      await t.pumpWidget(tela(a, 'Loja A'));
      await t.pumpAndSettle();
      await t.pumpWidget(tela(b, 'Loja B'));
      await t.pumpAndSettle();
      expect(find.text('Loja A'), findsNothing);
      expect(find.text('Loja B'), findsOneWidget);
      final antes = cargas;
      a.historico.revisao.value++;
      await t.pumpAndSettle();
      expect(cargas, antes);
      b.historico.revisao.value++;
      await t.pumpAndSettle();
      expect(cargas, antes + 1);
      await t.pumpWidget(const SizedBox());
      a.dispose();
      b.dispose();
    },
  );
}
