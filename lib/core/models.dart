import 'dart:convert';
import 'package:flutter/material.dart';

import 'format.dart';
import 'dates.dart';
import 'permissoes.dart';
export 'permissoes.dart' show Perfil;
import 'theme.dart';

double _num(dynamic v) =>
    v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);

// ===== Status (fonte única de verdade para rótulo e cor) =====

enum Status {
  pendente('Pendente', AppColors.warning, Icons.schedule),
  parcial('Parcial', AppColors.info, Icons.timelapse),
  pago('Pago', AppColors.success, Icons.check_circle),
  vencida('Vencida', AppColors.danger, Icons.error),
  cancelada('Cancelada', AppColors.neutral, Icons.cancel);

  const Status(this.label, this.color, this.icon);
  final String label;
  final Color color;
  final IconData icon;

  String get backend => switch (this) {
    Status.pendente => 'ABERTA',
    Status.parcial => 'PAGA_PARCIALMENTE',
    Status.pago => 'PAGA_TOTALMENTE',
    Status.vencida => 'VENCIDA',
    Status.cancelada => 'CANCELADA',
  };
  bool get emAberto => this == pendente || this == parcial || this == vencida;
}

enum MetodoPagamento {
  DINHEIRO('Dinheiro'),
  PIX('PIX'),
  CARTAO_DEBITO('Cartão de débito'),
  CARTAO_CREDITO('Cartão de crédito'),
  TRANSFERENCIA_BANCARIA('Transferência'),
  BOLETO_BANCARIO('Boleto');

  const MetodoPagamento(this.label);
  final String label;

  static MetodoPagamento? parse(String? s) =>
      MetodoPagamento.values.where((m) => m.name == s).firstOrNull;
}

// ===== Entidades =====

class Cliente {
  Cliente({
    required this.id,
    required this.nome,
    this.cpf,
    this.email,
    this.telefone,
    this.endereco,
    this.limiteCredito = 0,
    this.prazoPagamentoPadraoDias = 30,
    this.fiador,
    this.saldoDevedor = 0,
    this.emAtraso = false,
  });

  final int id;
  final String nome;
  final String? cpf, email, telefone, endereco;
  final double limiteCredito;
  final int prazoPagamentoPadraoDias;
  final Map<String, dynamic>? fiador;
  final double saldoDevedor;
  final bool emAtraso;

  factory Cliente.fromJson(Map<String, dynamic> j) => Cliente(
    id: j['id'],
    nome: j['nome'] ?? '',
    cpf: j['cpf'],
    email: j['email'],
    telefone: j['telefone'],
    endereco: j['endereco'],
    limiteCredito: _num(j['limiteCredito']),
    prazoPagamentoPadraoDias: j['prazoPagamentoPadraoDias'] ?? 30,
    fiador: j['fiador'],
    saldoDevedor: _num(j['saldoDevedor']),
    emAtraso: j['emAtraso'] == true,
  );
}

class ItemVenda {
  ItemVenda({
    required this.descricao,
    required this.quantidade,
    required this.precoUnitario,
    double? subtotal,
  }) : subtotal = subtotal ?? quantidade * precoUnitario;

  final String descricao;
  final int quantidade;
  final double precoUnitario;
  final double subtotal;

  factory ItemVenda.fromJson(Map<String, dynamic> j) => ItemVenda(
    descricao: j['descricaoProduto'] ?? '',
    quantidade: (j['quantidade'] as num?)?.toInt() ?? 0,
    precoUnitario: _num(j['precoUnitario']),
    subtotal: j['subtotal'] == null ? null : _num(j['subtotal']),
  );

  Map<String, dynamic> toJson() => {
    'descricaoProduto': descricao,
    'quantidade': quantidade,
    'precoUnitario': precoUnitario,
  };
}

class Venda {
  Venda({
    required this.id,
    this.dataHora,
    this.dataNegocio,
    required this.valorTotal,
    required this.clienteId,
    this.dividaId,
    this.versao = 0,
    this.temPagamentos = false,
    this.clienteNome,
    this.statusDivida,
    this.itens = const [],
  });

  final int id;
  final DateTime? dataHora;
  final DateTime? dataNegocio;
  final double valorTotal;
  final int clienteId;
  final int? dividaId;
  final int versao;
  final bool temPagamentos;
  final String? statusDivida;
  final String? clienteNome;
  final List<ItemVenda> itens;

  factory Venda.fromJson(Map<String, dynamic> j) => Venda(
    id: j['id'],
    dataHora: parseData(j['dataHora']),
    dataNegocio: parseData(j['dataNegocio']),
    valorTotal: _num(j['valorTotal']),
    clienteId: j['clienteId'],
    dividaId: j['dividaId'],
    versao: j['versao'] ?? 0,
    temPagamentos: j['temPagamentos'] == true,
    statusDivida: j['statusDivida'],
    clienteNome: j['clienteNome'],
    itens: ((j['itens'] as List?) ?? [])
        .map((e) => ItemVenda.fromJson(e))
        .toList(),
  );
}

class Pagamento {
  Pagamento({
    required this.valorPago,
    this.dataPagamento,
    this.metodo,
    this.id,
    this.dividaId,
  });
  final int? id;
  final int? dividaId;

  final double valorPago;
  final DateTime? dataPagamento;
  final MetodoPagamento? metodo;

  factory Pagamento.fromJson(Map<String, dynamic> j) => Pagamento(
    id: j['id'],
    dividaId: j['dividaId'],
    valorPago: _num(j['valorPago']),
    dataPagamento: parseData(j['dataPagamento']),
    metodo: MetodoPagamento.parse(j['metodoPagamento']),
  );
}

class Divida {
  Divida({
    required this.id,
    required this.valorOriginal,
    required this.valorPendente,
    this.dataEmissao,
    this.dataVencimento,
    this.statusBackend,
    required this.clienteId,
    this.vendaId,
    this.clienteNome,
    this.pagamentos = const [],
  });

  final int id;
  final double valorOriginal, valorPendente;
  final DateTime? dataEmissao, dataVencimento;
  final String? statusBackend;
  final int clienteId;
  final int? vendaId;
  final String? clienteNome;
  final List<Pagamento> pagamentos;

  double get valorPago => pagamentos.fold<double>(0, (s, p) => s + p.valorPago);

  bool get vencida =>
      dataVencimento != null && dataVencimento!.isBefore(hoje());

  int get diasAtraso =>
      dataVencimento == null ? 0 : hoje().difference(dataVencimento!).inDays;

  /// Status exibido: o backend só marca VENCIDA em rotina; aqui qualquer dívida
  /// em aberto com vencimento passado já aparece como vencida.
  Status get status {
    switch (statusBackend) {
      case 'PAGA_TOTALMENTE':
        return Status.pago;
      case 'CANCELADA':
        return Status.cancelada;
      case 'VENCIDA':
        return Status.vencida;
      case 'PAGA_PARCIALMENTE':
        return vencida ? Status.vencida : Status.parcial;
      default:
        return vencida ? Status.vencida : Status.pendente;
    }
  }

  factory Divida.fromJson(Map<String, dynamic> j) => Divida(
    id: j['id'],
    valorOriginal: _num(j['valorOriginal']),
    valorPendente: _num(j['valorPendente']),
    dataEmissao: parseData(j['dataEmissao']),
    dataVencimento: parseData(j['dataVencimento']),
    statusBackend: j['statusDivida'],
    clienteId: j['clienteId'],
    vendaId: j['vendaId'],
    clienteNome: j['clienteNome'],
    pagamentos: ((j['pagamentos'] as List?) ?? [])
        .map((e) => Pagamento.fromJson(e))
        .toList(),
  );
}

class Usuario {
  const Usuario({
    required this.id,
    required this.pessoaId,
    required this.nome,
    required this.perfil,
    this.login = '',
  });
  final int id, pessoaId;
  final String nome, login;
  final Perfil? perfil;
  factory Usuario.fromJson(Map<String, dynamic> j) => Usuario(
    id: (j['id'] as num?)?.toInt() ?? 0,
    pessoaId: (j['pessoaId'] as num?)?.toInt() ?? 0,
    nome: j['nome'] as String? ?? '',
    login: j['login'] as String? ?? '',
    perfil: Perfil.parse(j['perfil']),
  );
}

enum TipoEvento {
  LEMBRETE_PAGAMENTO(
    'Lembrete de pagamento',
    Icons.schedule,
    AppColors.warning,
  ),
  AVISO_DIVIDA_VENCIDA('Dívida vencida', Icons.error_outline, AppColors.danger),
  CONFIRMACAO_COMPRA(
    'Compra confirmada',
    Icons.shopping_bag_outlined,
    AppColors.info,
  ),
  CONFIRMACAO_PAGAMENTO(
    'Pagamento confirmado',
    Icons.check_circle_outline,
    AppColors.success,
  ),
  CADASTRO_CLIENTE(
    'Cliente cadastrado',
    Icons.person_add_outlined,
    AppColors.secondary,
  ),
  PAGAMENTO_RECEBIDO(
    'Pagamento recebido',
    Icons.payments_outlined,
    AppColors.success,
  ),
  COMPRA_REALIZADA(
    'Compra realizada',
    Icons.shopping_cart_outlined,
    AppColors.info,
  ),
  LEMBRETE_VENCIMENTO(
    'Vencimento próximo',
    Icons.event_outlined,
    AppColors.warning,
  );

  const TipoEvento(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
  static TipoEvento? parse(dynamic value) =>
      values.where((v) => v.name == value).firstOrNull;
  static Iterable<TipoEvento> permitidos(Perfil? perfil) =>
      perfil == Perfil.funcionario
      ? const [CADASTRO_CLIENTE, COMPRA_REALIZADA, PAGAMENTO_RECEBIDO]
      : values;
}

class EventoHistorico {
  EventoHistorico({
    required this.id,
    required this.mensagem,
    this.dataEnvio,
    this.tipo,
    this.destinatario = '',
  });
  final int id;
  final String mensagem, destinatario;
  final DateTime? dataEnvio;
  final TipoEvento? tipo;
  factory EventoHistorico.fromJson(Map<String, dynamic> j) {
    final dest = j['destinatario'];
    return EventoHistorico(
      id: (j['id'] as num).toInt(),
      mensagem: mensagemFinanceira(j['mensagem'] ?? ''),
      dataEnvio: parseData(j['dataEnvio']),
      tipo: TipoEvento.parse(j['tipo']),
      destinatario: dest is Map
          ? (dest['nome'] ?? '')
          : (dest?.toString() ?? ''),
    );
  }
}

class ContaAcesso {
  ContaAcesso({
    required this.id,
    required this.nome,
    required this.login,
    required this.perfil,
    required this.ativo,
  });
  final int id;
  final String nome, login;
  final Perfil? perfil;
  final bool ativo;
  factory ContaAcesso.fromJson(Map<String, dynamic> j) => ContaAcesso(
    id: (j['id'] as num).toInt(),
    nome: j['nome'] ?? '',
    login: j['login'] ?? '',
    perfil: Perfil.parse(j['perfil']),
    ativo: j['ativo'] == true,
  );
}

class Convite {
  Convite(this.codigo, this.expiraEm);
  final String codigo;
  final DateTime? expiraEm;
  factory Convite.fromJson(Map<String, dynamic> j) =>
      Convite(j['codigo'], parseData(j['expiraEm']));
}

class AuditoriaEvento {
  AuditoriaEvento(this.json);
  final Map<String, dynamic> json;
  factory AuditoriaEvento.fromJson(Map<String, dynamic> j) {
    dynamic alteracoes = j['alteracoes'];
    if (alteracoes is String) {
      try {
        alteracoes = jsonDecode(alteracoes);
      } on FormatException {
        alteracoes = 'Detalhes indisponíveis.';
      }
    }
    return AuditoriaEvento({...j, 'alteracoes': alteracoes});
  }
  String get ator => json['ator'] is Map
      ? (json['ator']['login'] ?? json['ator']['nome'] ?? '—').toString()
      : texto('ator');
  String get perfil => json['ator'] is Map
      ? (json['ator']['perfil'] ?? '—').toString()
      : texto('perfil');
  String get recurso => json['recurso'] is Map
      ? '${json['recurso']['tipo'] ?? '—'} #${json['recurso']['id'] ?? '—'}'
      : '${texto('recursoTipo')} #${texto('recursoId')}';
  String texto(String key) {
    final v = json[key];
    return v is Map
        ? (v['nome'] ?? v['id'] ?? '—').toString()
        : (v ?? '—').toString();
  }
}
