enum Perfil {
  gerente('Gerente'),
  funcionario('Funcionário'),
  cliente('Cliente');

  const Perfil(this.label);
  final String label;
  static Perfil? parse(dynamic value) => switch (value) {
    'GERENTE' => gerente,
    'FUNCIONARIO' => funcionario,
    'CLIENTE' => cliente,
    _ => null,
  };
}

enum Acao { operacao, editarVenda, gerencial, minhaCaderneta, gerarConvite }

bool pode(Perfil? perfil, Acao acao) => switch (acao) {
  Acao.operacao ||
  Acao.editarVenda ||
  Acao.gerarConvite => perfil == Perfil.gerente || perfil == Perfil.funcionario,
  Acao.gerencial => perfil == Perfil.gerente,
  Acao.minhaCaderneta => perfil == Perfil.cliente,
};

const rotasAcoes = {
  '/': Acao.operacao,
  '/clientes': Acao.operacao,
  '/vendas': Acao.operacao,
  '/pagamentos': Acao.operacao,
  '/historico': Acao.operacao,
  '/relatorios': Acao.gerencial,
  '/auditoria': Acao.gerencial,
  '/acessos': Acao.gerencial,
  '/minha': Acao.minhaCaderneta,
  '/minha/compras': Acao.minhaCaderneta,
  '/minha/dividas': Acao.minhaCaderneta,
  '/minha/pagamentos': Acao.minhaCaderneta,
  '/minha/historico': Acao.minhaCaderneta,
};
String entrada(Perfil? perfil) => perfil == Perfil.cliente ? '/minha' : '/';
bool rotaPermitida(Perfil? perfil, String path) =>
    path == '/acesso-negado' ||
    (rotasAcoes.containsKey(path) && pode(perfil, rotasAcoes[path]!));
String destinoSeguro(String? next, Perfil? perfil) {
  if (next == null ||
      !next.startsWith('/') ||
      next.startsWith('//') ||
      next.contains('\\') ||
      next.contains('%') ||
      next.contains(':')) {
    return entrada(perfil);
  }
  final uri = Uri.tryParse(next);
  if (uri == null ||
      uri.hasAuthority ||
      uri.hasScheme ||
      !rotaPermitida(perfil, uri.path)) {
    return entrada(perfil);
  }
  return uri.path;
}
