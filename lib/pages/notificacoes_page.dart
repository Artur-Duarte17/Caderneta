import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../core/notificacoes_service.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class NotificacoesPage extends StatefulWidget {
  const NotificacoesPage({super.key});
  @override
  State<NotificacoesPage> createState() => _NotificacoesPageState();
}

class _NotificacoesPageState extends State<NotificacoesPage> {
  final _service = NotificacoesService.instance;
  String? _grupo;
  bool? _lida;
  int _periodo = 0;

  @override
  void initState() {
    super.initState();
    _service.carregar();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _service,
        builder: (context, _) {
          final lista = _service.itens.where((n) {
            if (_grupo != null && n.tipo.grupo != _grupo) return false;
            if (_lida != null && n.lida != _lida) return false;
            if (_periodo > 0 && (n.dataEnvio == null || hoje().difference(n.dataEnvio!).inDays >= _periodo)) return false;
            return true;
          }).toList();

          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            PageHeader(
              titulo: 'Notificações',
              subtitulo: '${_service.naoLidas} não lida(s)',
              acoes: [
                OutlinedButton.icon(
                  onPressed: _service.naoLidas == 0 ? null : _service.marcarTodas,
                  icon: const Icon(Icons.done_all, size: 18),
                  label: Text(isMobile(context) ? 'Ler todas' : 'Marcar todas como lidas'),
                ),
              ],
            ),
            Wrap(spacing: Gap.md, runSpacing: Gap.md - 4, children: [
              FilterField(
                child: Dropdown<String?>(
                  label: 'Tipo',
                  value: _grupo,
                  itens: const {null: 'Todos', 'Pagamentos': 'Pagamentos', 'Vencimentos': 'Vencimentos', 'Sistema': 'Sistema'},
                  onChanged: (v) => setState(() => _grupo = v),
                ),
              ),
              FilterField(
                child: Dropdown<bool?>(
                  label: 'Status',
                  value: _lida,
                  itens: const {null: 'Todas', false: 'Não lidas', true: 'Lidas'},
                  onChanged: (v) => setState(() => _lida = v),
                ),
              ),
              FilterField(
                child: Dropdown<int>(
                  label: 'Período',
                  value: _periodo,
                  itens: const {0: 'Todo o período', 1: 'Hoje', 7: 'Últimos 7 dias', 30: 'Últimos 30 dias'},
                  onChanged: (v) => setState(() => _periodo = v),
                ),
              ),
            ]),
            const SizedBox(height: Gap.md),
            if (_service.carregando && _service.itens.isEmpty)
              const LoadingState()
            else if (_service.erro != null && _service.itens.isEmpty)
              ErrorState(mensagem: _service.erro!, onRetry: _service.carregar)
            else if (lista.isEmpty)
              const EmptyState(icon: Icons.notifications_off_outlined, titulo: 'Nenhuma notificação encontrada')
            else
              Card(
                child: Column(children: [
                  for (var i = 0; i < lista.length; i++) ...[
                    if (i > 0) const Divider(),
                    _NotificacaoTile(n: lista[i], onLida: () => _service.marcarLida(lista[i])),
                  ],
                ]),
              ),
          ]);
        },
      );
}

class _NotificacaoTile extends StatelessWidget {
  const _NotificacaoTile({required this.n, required this.onLida});
  final Notificacao n;
  final VoidCallback onLida;

  Widget _acao() => n.lida
      ? const Pill(label: 'Lida', cor: AppColors.neutral, icon: Icons.check)
      : TextButton(onPressed: onLida, child: const Text('Marcar como lida'));

  @override
  Widget build(BuildContext context) {
    final estreito = MediaQuery.sizeOf(context).width < 600;
    return Container(
        color: n.lida ? null : AppColors.primary.withValues(alpha: .03),
        padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.md - 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: n.tipo.color.withValues(alpha: .1), shape: BoxShape.circle),
            child: Icon(n.tipo.icon, color: n.tipo.color, size: 20),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (!n.lida) ...[
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
                  const SizedBox(width: Gap.sm),
                ],
                Expanded(
                  child: Text(n.titulo, style: TextStyle(fontWeight: n.lida ? FontWeight.w500 : FontWeight.w700)),
                ),
                Text(tempoRelativo(n.dataEnvio), style: Theme.of(context).textTheme.bodySmall),
              ]),
              const SizedBox(height: Gap.xs),
              Text(n.mensagem, style: TextStyle(color: n.lida ? AppColors.muted : AppColors.text)),
              if (estreito) ...[const SizedBox(height: Gap.sm), _acao()],
            ]),
          ),
          if (!estreito) ...[
            const SizedBox(width: Gap.md),
            SizedBox(width: 140, child: Align(alignment: Alignment.centerRight, child: _acao())),
          ],
        ]),
      );
  }
}
