import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:caderneta/core/paged_controller.dart';
import 'package:caderneta/core/pagina.dart';

Pagina<int> pagina(
  List<int> content, {
  int number = 0,
  int total = 100,
  int pages = 5,
}) => Pagina(
  content: content,
  number: number,
  size: 20,
  totalElements: total,
  totalPages: pages,
);
void main() {
  test(
    'filtro e tamanho reiniciam página; erro preserva consulta e retry',
    () async {
      final chamadas = <(int, int, Map<String, String>)>[];
      var falhar = false;
      final c = PagedController<int>((p, s, f) async {
        chamadas.add((p, s, f));
        if (falhar) throw StateError('offline');
        return pagina([p], number: p);
      });
      addTearDown(c.dispose);
      c.page = 3;
      await c.atualizar();
      c.filtrar({'tipo': 'COMPRA_REALIZADA'});
      await Future<void>.delayed(Duration.zero);
      expect(c.page, 0);
      c.page = 2;
      c.tamanho(50);
      await Future<void>.delayed(Duration.zero);
      expect(c.page, 0);
      expect(c.size, 50);
      c.page = 1;
      falhar = true;
      await c.atualizar();
      expect(c.page, 1);
      expect(c.filtros['tipo'], 'COMPRA_REALIZADA');
      falhar = false;
      await c.atualizar();
      expect(chamadas.last.$1, 1);
      expect(chamadas.last.$2, 50);
      expect(chamadas.last.$3, {'tipo': 'COMPRA_REALIZADA'});
      expect(c.erro, isNull);
    },
  );
  test('resposta fora de ordem não sobrescreve a consulta recente', () async {
    final a = Completer<Pagina<int>>(), b = Completer<Pagina<int>>();
    var count = 0;
    final c = PagedController<int>(
      (_, _, _) => count++ == 0 ? a.future : b.future,
    );
    addTearDown(c.dispose);
    final reqA = c.atualizar(), reqB = c.atualizar();
    b.complete(pagina([2]));
    await reqB;
    a.complete(pagina([1]));
    await reqA;
    expect(c.dados!.content, [2]);
  });
  test('página vazia além do intervalo volta à última válida', () async {
    final pedidos = <int>[];
    final c = PagedController<int>((p, _, _) async {
      pedidos.add(p);
      return pagina(p < 2 ? [p] : [], number: p, pages: 2);
    });
    addTearDown(c.dispose);
    c.page = 4;
    await c.atualizar();
    expect(pedidos, [4, 1]);
    expect(c.page, 1);
    expect(c.dados!.content, [1]);
  });
}
