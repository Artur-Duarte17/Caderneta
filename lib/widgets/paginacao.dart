import 'package:flutter/material.dart';
import '../core/paged_controller.dart';
import '../core/dates.dart';
import '../core/theme.dart';
import 'common.dart';

class PaginatedSection<T> extends StatelessWidget {
  const PaginatedSection({
    super.key,
    required this.controller,
    required this.builder,
    this.unidade = 'registros',
  });
  final PagedController<T> controller;
  final Widget Function(List<T>) builder;
  final String unidade;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final c = controller, r = c.dados;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: Gap.md,
            runSpacing: Gap.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 160,
                child: Dropdown<int>(
                  key: ValueKey(c.size),
                  label: 'Por página',
                  value: c.size,
                  itens: const {10: '10', 20: '20', 50: '50'},
                  onChanged: c.tamanho,
                ),
              ),
              OutlinedButton.icon(
                onPressed: c.carregando ? null : c.atualizar,
                icon: const Icon(Icons.refresh),
                label: const Text('Atualizar'),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          if (c.carregando && r != null)
            const BarraAtualizando(mensagem: 'Buscando registros'),
          if (c.erro != null)
            ErrorState(mensagem: '${c.erro}', onRetry: c.atualizar)
          else if (r == null)
            const LoadingState(mensagem: 'Carregando registros')
          else if (r.content.isEmpty)
            EmptyState(
              icon: Icons.history,
              titulo: 'Nenhum registro encontrado',
              acao: c.filtros.isEmpty
                  ? null
                  : TextButton(
                      onPressed: () => c.filtrar({}),
                      child: const Text('Limpar filtros'),
                    ),
            )
          else
            builder(r.content),
          if (r != null)
            Padding(
              padding: const EdgeInsets.only(top: Gap.md),
              child: Wrap(
                spacing: Gap.sm,
                runSpacing: Gap.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Página ${r.totalPages == 0 ? 0 : r.number + 1} de ${r.totalPages} · ${r.totalElements} $unidade',
                  ),
                  IconButton(
                    tooltip: 'Página anterior',
                    onPressed: c.carregando || r.first
                        ? null
                        : () => c.ir(r.number - 1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  IconButton(
                    tooltip: 'Próxima página',
                    onPressed: c.carregando || r.last
                        ? null
                        : () => c.ir(r.number + 1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}

class PeriodoFiltro extends StatefulWidget {
  const PeriodoFiltro({
    super.key,
    required this.onChanged,
    this.filtros = const {},
  });
  final ValueChanged<DateTimeRange?> onChanged;
  final Map<String, String> filtros;
  @override
  State<PeriodoFiltro> createState() => _PeriodoFiltroState();
}

class _PeriodoFiltroState extends State<PeriodoFiltro> {
  int _versao = 0;
  int get _valor {
    if (widget.filtros['inicio'] == null) return 0;
    final n = DateTime.now(),
        hoje = DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
        );
    for (final dias in [1, 7, 30]) {
      final limites = limitesPeriodo(
        DateTime(n.year, n.month, n.day - dias + 1),
        hoje,
      );
      if (limites['inicio'] == widget.filtros['inicio'] &&
          limites['fim'] == widget.filtros['fim']) {
        return dias;
      }
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) => FilterField(
    child: Dropdown<int>(
      key: ValueKey((_valor, _versao)),
      label: 'Período',
      value: _valor,
      itens: const {
        0: 'Todo o período',
        1: 'Hoje',
        7: 'Últimos 7 dias',
        30: 'Últimos 30 dias',
        -1: 'Personalizado',
      },
      onChanged: (dias) async {
        if (dias == 0) {
          widget.onChanged(null);
          return;
        }
        final now = DateTime.now(),
            hoje = DateTime(
              DateTime.now().year,
              DateTime.now().month,
              DateTime.now().day,
            );
        if (dias > 0) {
          widget.onChanged(
            DateTimeRange(
              start: DateTime(hoje.year, hoje.month, hoje.day - dias + 1),
              end: hoje,
            ),
          );
          return;
        }
        final range = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2000),
          lastDate: DateTime(now.year + 1, 12, 31),
          initialEntryMode: DatePickerEntryMode.input,
        );
        if (!mounted) return;
        if (range != null) widget.onChanged(range);
        setState(() => _versao++);
      },
    ),
  );
}
