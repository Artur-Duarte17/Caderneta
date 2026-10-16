import 'package:flutter/material.dart';

import 'format.dart';
import 'theme.dart';

double _num(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);

/// Aceita datas do Jackson como string ISO ou como array [y, m, d, h, min, s].
DateTime? _date(dynamic v) {
  if (v == null) return null;
  if (v is List && v.length >= 3) {
    final p = v.map((e) => (e as num).toInt()).toList();
    return DateTime(p[0], p[1], p[2], p.length > 3 ? p[3] : 0, p.length > 4 ? p[4] : 0, p.length > 5 ? p[5] : 0);
  }
  return DateTime.tryParse('$v');
}

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
  });

  final int id;
  final String nome;
  final String? cpf, email, telefone, endereco;
  final double limiteCredito;
  final int prazoPagamentoPadraoDias;

  factory Cliente.fromJson(Map<String, dynamic> j) => Cliente(
        id: j['id'],
        nome: j['nome'] ?? '',
        cpf: j['cpf'],
        email: j['email'],
        telefone: j['telefone'],
        endereco: j['endereco'],
        limiteCredito: _num(j['limiteCredito']),
        prazoPagamentoPadraoDias: j['prazoPagamentoPadraoDias'] ?? 30,
      );
}

class ItemVenda {
  ItemVenda({required this.descricao, required this.quantidade, required this.precoUnitario, double? subtotal})
      : subtotal = subtotal ?? quantidade * precoUnitario;

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

  Map<String, dynamic> toJson() =>
      {'descricaoProduto': descricao, 'quantidade': quantidade, 'precoUnitario': precoUnitario};
}

class Venda {
  Venda({required this.id, this.dataHora, required this.valorTotal, required this.clienteId, this.dividaId, this.itens = const []});

  final int id;
  final DateTime? dataHora;
  final double valorTotal;
  final int clienteId;
  final int? dividaId;
  final List<ItemVenda> itens;

  factory Venda.fromJson(Map<String, dynamic> j) => Venda(
        id: j['id'],
        dataHora: _date(j['dataHora']),
        valorTotal: _num(j['valorTotal']),
        clienteId: j['clienteId'],
        dividaId: j['dividaId'],
        itens: ((j['itens'] as List?) ?? []).map((e) => ItemVenda.fromJson(e)).toList(),
      );
}

class Pagamento {
  Pagamento({required this.valorPago, this.dataPagamento, this.metodo});

  final double valorPago;
  final DateTime? dataPagamento;
  final MetodoPagamento? metodo;

  factory Pagamento.fromJson(Map<String, dynamic> j) => Pagamento(
        valorPago: _num(j['valorPago']),
        dataPagamento: _date(j['dataPagamento']),
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
    this.pagamentos = const [],
  });

  final int id;
  final double valorOriginal, valorPendente;
  final DateTime? dataEmissao, dataVencimento;
  final String? statusBackend;
  final int clienteId;
  final int? vendaId;
  final List<Pagamento> pagamentos;

  double get valorPago => pagamentos.fold<double>(0, (s, p) => s + p.valorPago);

  bool get vencida => dataVencimento != null && dataVencimento!.isBefore(hoje());

  int get diasAtraso => dataVencimento == null ? 0 : hoje().difference(dataVencimento!).inDays;

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
        dataEmissao: _date(j['dataEmissao']),
        dataVencimento: _date(j['dataVencimento']),
        statusBackend: j['statusDivida'],
        clienteId: j['clienteId'],
        vendaId: j['vendaId'],
        pagamentos: ((j['pagamentos'] as List?) ?? []).map((e) => Pagamento.fromJson(e)).toList(),
      );
}

enum TipoNotif {
  pagamento('Pagamentos', Icons.payments, AppColors.success),
  vencimento('Vencimentos', Icons.notifications_active, AppColors.warning),
  vencida('Vencimentos', Icons.error, AppColors.danger),
  venda('Sistema', Icons.shopping_cart, AppColors.info),
  cliente('Sistema', Icons.person_add, AppColors.secondary),
  sistema('Sistema', Icons.info, AppColors.neutral);

  const TipoNotif(this.grupo, this.icon, this.color);
  final String grupo;
  final IconData icon;
  final Color color;
}

class Notificacao {
  Notificacao({required this.id, required this.mensagem, this.dataEnvio, this.tipoBackend, this.lida = false});

  final int id;
  final String mensagem;
  final DateTime? dataEnvio;
  final String? tipoBackend;
  bool lida;

  TipoNotif get tipo => switch (tipoBackend) {
        'PAGAMENTO_RECEBIDO' || 'CONFIRMACAO_PAGAMENTO' => TipoNotif.pagamento,
        'LEMBRETE_VENCIMENTO' || 'LEMBRETE_PAGAMENTO' => TipoNotif.vencimento,
        'AVISO_DIVIDA_VENCIDA' => TipoNotif.vencida,
        'COMPRA_REALIZADA' || 'CONFIRMACAO_COMPRA' => TipoNotif.venda,
        'CADASTRO_CLIENTE' => TipoNotif.cliente,
        _ => TipoNotif.sistema,
      };

  String get titulo => switch (tipoBackend) {
        'PAGAMENTO_RECEBIDO' => 'Pagamento recebido',
        'CONFIRMACAO_PAGAMENTO' => 'Pagamento confirmado',
        'LEMBRETE_VENCIMENTO' => 'Vencimento próximo',
        'LEMBRETE_PAGAMENTO' => 'Lembrete de pagamento',
        'AVISO_DIVIDA_VENCIDA' => 'Dívida vencida',
        'COMPRA_REALIZADA' || 'CONFIRMACAO_COMPRA' => 'Nova venda',
        'CADASTRO_CLIENTE' => 'Novo cliente',
        _ => 'Sistema',
      };

  factory Notificacao.fromJson(Map<String, dynamic> j) => Notificacao(
        id: j['id'] ?? DateTime.now().millisecondsSinceEpoch,
        mensagem: j['mensagem'] ?? '',
        dataEnvio: _date(j['dataEnvio']),
        tipoBackend: j['tipoNotificacao'],
        lida: j['lida'] == true,
      );
}
