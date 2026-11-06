import 'dart:convert';
import 'dart:math';
import 'idempotencia_native.dart'
    if (dart.library.js_interop) 'idempotencia_web.dart'
    as storage;

/// Guarda somente identificadores/hash da requisição, nunca o corpo ou credenciais.
String nomeOperacao(String identidade) {
  // Hash estável de 128 bits para localizar a chave após recarregar a página.
  var a = BigInt.parse('14695981039346656037'),
      b = BigInt.parse('1099511628211');
  final mask = (BigInt.one << 128) - BigInt.one;
  for (final c in utf8.encode(identidade)) {
    a = ((a ^ BigInt.from(c)) * b) & mask;
  }
  return 'caderneta.operacao.${a.toRadixString(16)}';
}

void concluirOperacao(String identidade) =>
    storage.remover(nomeOperacao(identidade));
String chaveOperacao(String identidade) {
  final nome = nomeOperacao(identidade);
  final existente = storage.ler(nome);
  if (existente != null) return existente;
  final rng = Random.secure();
  final valor = List.generate(
    24,
    (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  storage.salvar(nome, valor);
  return valor;
}
