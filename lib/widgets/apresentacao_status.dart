import 'package:flutter/material.dart';
import '../core/models.dart';
import '../core/theme.dart';

extension StatusVisual on Status {
  Color get color => switch (this) {
    Status.pendente => AppColors.warning,
    Status.parcial => AppColors.info,
    Status.pago => AppColors.success,
    Status.vencida => AppColors.danger,
    Status.cancelada => AppColors.neutral,
  };
  IconData get icon => switch (this) {
    Status.pendente => Icons.schedule,
    Status.parcial => Icons.timelapse,
    Status.pago => Icons.check_circle,
    Status.vencida => Icons.error,
    Status.cancelada => Icons.cancel,
  };
}

extension TipoEventoVisual on TipoEvento {
  Color get color => switch (this) {
    TipoEvento.LEMBRETE_PAGAMENTO => AppColors.warning,
    TipoEvento.AVISO_DIVIDA_VENCIDA => AppColors.danger,
    TipoEvento.CONFIRMACAO_COMPRA => AppColors.info,
    TipoEvento.CONFIRMACAO_PAGAMENTO => AppColors.success,
    TipoEvento.CADASTRO_CLIENTE => AppColors.secondary,
    TipoEvento.PAGAMENTO_RECEBIDO => AppColors.success,
    TipoEvento.COMPRA_REALIZADA => AppColors.info,
    TipoEvento.LEMBRETE_VENCIMENTO => AppColors.warning,
  };
  IconData get icon => switch (this) {
    TipoEvento.LEMBRETE_PAGAMENTO => Icons.schedule,
    TipoEvento.AVISO_DIVIDA_VENCIDA => Icons.error_outline,
    TipoEvento.CONFIRMACAO_COMPRA => Icons.shopping_bag_outlined,
    TipoEvento.CONFIRMACAO_PAGAMENTO => Icons.check_circle_outline,
    TipoEvento.CADASTRO_CLIENTE => Icons.person_add_outlined,
    TipoEvento.PAGAMENTO_RECEBIDO => Icons.payments_outlined,
    TipoEvento.COMPRA_REALIZADA => Icons.shopping_cart_outlined,
    TipoEvento.LEMBRETE_VENCIMENTO => Icons.event_outlined,
  };
}
