import 'package:flutter/material.dart';

import '../core/theme.dart';

class AppTable extends StatelessWidget {
  const AppTable({
    super.key,
    required this.colunas,
    required this.linhas,
    this.numericas = const {},
  });
  final List<String> colunas;
  final List<List<Widget>> linhas;
  final Set<int> numericas;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: c.maxWidth),
        child: DataTable(
          headingRowHeight: 40,
          dataRowMinHeight: 52,
          dataRowMaxHeight: 60,
          horizontalMargin: 0,
          columnSpacing: Gap.lg,
          headingTextStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.muted,
          ),
          columns: [
            for (var i = 0; i < colunas.length; i++)
              DataColumn(
                label: Text(colunas[i]),
                numeric: numericas.contains(i),
              ),
          ],
          rows: [
            for (final l in linhas)
              DataRow(cells: [for (final w in l) DataCell(w)]),
          ],
        ),
      ),
    ),
  );
}

class OperacaoPaginador extends StatelessWidget {
  const OperacaoPaginador({
    super.key,
    required this.page,
    required this.total,
    required this.last,
    required this.onPage,
  });
  final int page, total;
  final bool last;
  final ValueChanged<int> onPage;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Gap.md),
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: Gap.md,
      children: [
        Text('$total registro(s) · Página ${page + 1}'),
        IconButton(
          tooltip: 'Página anterior',
          onPressed: page == 0 ? null : () => onPage(page - 1),
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          tooltip: 'Próxima página',
          onPressed: last ? null : () => onPage(page + 1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    ),
  );
}
