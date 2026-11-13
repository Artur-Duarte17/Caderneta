import 'package:flutter/material.dart';
import '../core/app_runtime.dart';
import '../core/dates.dart';
import '../core/format.dart';
import '../core/historico_service.dart';
import '../core/models.dart';
import '../core/paged_controller.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/paginacao.dart';

class HistoricoPage extends StatefulWidget {
  const HistoricoPage({super.key, this.pessoal = false});
  final bool pessoal;
  @override
  State<HistoricoPage> createState() => _HistoricoPageState();
}

class _HistoricoPageState extends State<HistoricoPage> {
  PagedController<EventoHistorico>? _controller;
  late HistoricoService _service;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final runtime = AppScope.of(context);
    _controller = PagedController(
      (page, size, filtros) => runtime.historicoRepo.listar(
        pessoal: widget.pessoal,
        page: page,
        size: size,
        filtros: filtros,
      ),
      cache: widget.pessoal ? 'historico-pessoal' : 'historico',
    )..atualizar();
    _service = runtime.historico;
    _service.revisao.addListener(_dadosMudaram);
  }

  void _dadosMudaram() {
    final c = _controller!;
    if (c.page == 0) {
      _service.consumirNovos();
      c.atualizar();
    } else if (mounted) {
      setState(() {});
    }
  }

  void _filtrar(String key, String? value) {
    final filtros = Map.of(_controller!.filtros)..remove(key);
    if (value != null && value.isNotEmpty) filtros[key] = value;
    _controller!.filtrar(filtros);
  }

  @override
  void dispose() {
    _service.revisao.removeListener(_dadosMudaram);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller!,
        perfil = AppScope.of(context).sessao.usuario?.perfil;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeader(
            titulo: 'Histórico',
            subtitulo: 'Eventos da caderneta, do mais recente ao mais antigo',
          ),
          Wrap(
            spacing: Gap.md,
            runSpacing: Gap.md,
            children: [
              FilterField(
                child: Dropdown<String>(
                  key: ValueKey(c.filtros['tipo']),
                  label: 'Tipo',
                  value: c.filtros['tipo'] ?? '',
                  itens: {
                    '': 'Todos os tipos',
                    for (final tipo in TipoEvento.permitidos(perfil))
                      tipo.name: tipo.label,
                  },
                  onChanged: (value) => _filtrar('tipo', value),
                ),
              ),
              PeriodoFiltro(
                filtros: c.filtros,
                onChanged: (range) {
                  final f = Map.of(c.filtros)
                    ..remove('inicio')
                    ..remove('fim');
                  if (range != null) {
                    f.addAll(limitesPeriodo(range.start, range.end));
                  }
                  c.filtrar(f);
                },
              ),
              if (c.filtros.isNotEmpty)
                TextButton(
                  onPressed: () => c.filtrar({}),
                  child: const Text('Limpar filtros'),
                ),
            ],
          ),
          if (c.filtros['inicio'] != null)
            Padding(
              padding: const EdgeInsets.only(top: Gap.sm),
              child: Text(
                'De ${data(parseData(c.filtros['inicio'])?.toLocal())} até ${data(parseData(c.filtros['fim'])?.toLocal().subtract(const Duration(days: 1)))}',
              ),
            ),
          const SizedBox(height: Gap.md),
          if (_service.novosEventos > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.md),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.history),
                label: Text(
                  '${_service.novosEventos} novos eventos · Atualizar',
                ),
                onPressed: () {
                  _service.consumirNovos();
                  c.atualizar();
                },
              ),
            ),
          PaginatedSection<EventoHistorico>(
            controller: c,
            unidade: 'eventos',
            builder: _lista,
          ),
        ],
      ),
    );
  }

  Widget _lista(List<EventoHistorico> eventos) {
    String? ultimoDia;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final e in eventos) ...[
          if (ultimoDia != data(e.dataEnvio?.toLocal()))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.md),
              child: Text(
                _dia(ultimoDia = data(e.dataEnvio?.toLocal())),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    e.tipo?.icon ?? Icons.info_outline,
                    color: e.tipo?.color ?? AppColors.neutral,
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.tipo?.label ?? 'Evento',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: Gap.xs),
                        Text(e.mensagem),
                        if (!widget.pessoal && e.destinatario.isNotEmpty)
                          Text(e.destinatario),
                        const SizedBox(height: Gap.xs),
                        Text(
                          dataHora(e.dataEnvio),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Gap.sm),
        ],
      ],
    );
  }

  String _dia(String dia) => dia == data(hoje())
      ? 'Hoje'
      : dia == data(DateTime(hoje().year, hoje().month, hoje().day - 1))
      ? 'Ontem'
      : dia;
}
