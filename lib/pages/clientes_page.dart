import 'forms/clientes_form.dart';
import 'package:flutter/material.dart';

import '../core/snapshot.dart';
import '../core/app_runtime.dart';
import '../core/permissoes.dart';
import '../core/documentos.dart';
import '../widgets/convite_dialog.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class ClientesPage extends StatefulWidget {
  const ClientesPage({super.key});
  @override
  State<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends State<ClientesPage> {
  String _busca = '';
  int _page = 0;

  @override
  Widget build(BuildContext context) => AsyncView<Snapshot>(
    cache: 'clientes',
    queryKey: (_page, _busca),
    mensagem: 'Carregando clientes',
    mensagemAtualizando: 'Buscando clientes',
    load: () => AppScope.of(
      context,
    ).operacoes.carregar(recurso: 'clientes', page: _page, q: _busca),
    builder: (context, s, reload) {
      final lista = s.clientes;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            titulo: 'Clientes',
            subtitulo: '${s.total} cliente(s) cadastrado(s)',
            acoes: [
              FilledButton.icon(
                onPressed: () => _abrirForm(context, null),
                icon: const Icon(Icons.person_add_alt, size: 18),
                label: const Text('Novo cliente'),
              ),
            ],
          ),
          FilterField(
            width: 360,
            child: SearchField(
              hint: 'Buscar por nome, CPF ou telefone',
              onChanged: (v) => setState(() {
                _busca = v;
                _page = 0;
              }),
            ),
          ),
          const SizedBox(height: Gap.lg),
          OperacaoPaginador(
            page: _page,
            total: s.total,
            last: s.last,
            onPage: (p) => setState(() => _page = p),
          ),
          if (lista.isEmpty)
            const EmptyState(
              icon: Icons.person_off_outlined,
              titulo: 'Nenhum cliente encontrado',
            )
          else
            ResponsiveGrid(
              minWidth: 300,
              children: [
                for (final c in lista)
                  _ClienteCard(
                    cliente: c,
                    saldo: s.saldoDevedor(c.id),
                    atraso: s.emAtraso(c.id),
                    onDetalhes: () => _detalhes(context, s, c),
                    onEditar: () => _abrirForm(context, c),
                  ),
              ],
            ),
        ],
      );
    },
  );

  void _detalhes(BuildContext context, Snapshot s, Cliente c) {
    final saldo = s.saldoDevedor(c.id);
    final disponivel = c.limiteCredito - saldo;
    showAppDialog(
      context,
      titulo: 'Detalhes do cliente',
      builder: (ctx, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Avatar(c.nome, size: 48),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Text(
                    c.nome,
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                ),
                _situacao(saldo, s.emAtraso(c.id)),
              ],
            ),
            const SizedBox(height: Gap.md),
            const FormSection('Informações pessoais'),
            InfoRow(
              'Telefone',
              exibirTelefone(c.telefone, vazio: 'Não informado'),
            ),
            InfoRow('E-mail', c.email ?? 'Não informado'),
            InfoRow('CPF', exibirCpf(c.cpf, vazio: 'Não informado')),
            InfoRow('Endereço', c.endereco ?? 'Não informado'),
            const SizedBox(height: Gap.sm),
            const FormSection('Situação financeira'),
            InfoRow('Limite de crédito', moeda(c.limiteCredito)),
            InfoRow(
              'Saldo devedor',
              moeda(saldo),
              destaque: saldo > 0 ? AppColors.danger : AppColors.success,
            ),
            InfoRow(
              'Crédito disponível',
              moeda(disponivel),
              destaque: disponivel < 0 ? AppColors.danger : null,
            ),
            InfoRow('Prazo padrão', '${c.prazoPagamentoPadraoDias} dias'),
            InfoRow(
              'Cadastro',
              c.ativo ? 'Ativo' : 'Desativado — somente consulta',
            ),
            OutlinedButton.icon(
              icon: Icon(
                c.ativo ? Icons.person_off_outlined : Icons.person_add_alt,
              ),
              label: Text(c.ativo ? 'Desativar cliente' : 'Reativar cliente'),
              onPressed:
                  c.ativo &&
                      AppScope.of(context).sessao.usuario?.perfil !=
                          Perfil.gerente
                  ? null
                  : () async {
                      final runtime = AppScope.of(context);
                      final ok = await showDialog<bool>(
                        context: ctx,
                        builder: (d) => AlertDialog(
                          title: Text(
                            c.ativo
                                ? 'Desativar cliente?'
                                : 'Reativar cliente?',
                          ),
                          content: Text(
                            c.ativo
                                ? 'O histórico será mantido. Vendas, edições e recebimentos ficarão bloqueados até reativar.'
                                : 'O cliente voltará a permitir operações. Histórico e limite serão mantidos.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(d, false),
                              child: const Text('Cancelar'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(d, true),
                              child: const Text('Confirmar'),
                            ),
                          ],
                        ),
                      );
                      if (ok != true || !ctx.mounted) return;
                      try {
                        await runtime.clientes.alterarAtivo(c.id, !c.ativo);
                        if (ctx.mounted) Navigator.pop(ctx);
                        runtime.historico.dadosAlterados();
                      } catch (e) {
                        if (ctx.mounted) toast(ctx, '$e', erro: true);
                      }
                    },
            ),
          ],
        );
      },
    );
  }

  Future<void> _abrirForm(BuildContext context, Cliente? c) async {
    if (c != null && !c.ativo) {
      toast(context, 'Cliente desativado: somente consulta.', erro: true);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => ClienteForm(cliente: c),
    );
    if (ok == true && context.mounted) {
      AppScope.read(context).historico.dadosAlterados();
    }
  }
}

Widget _situacao(double saldo, bool atraso) {
  if (atraso) {
    return const Pill(
      label: 'Em atraso',
      cor: AppColors.danger,
      icon: Icons.error,
    );
  }
  if (saldo > 0) {
    return const Pill(
      label: 'Devendo',
      cor: AppColors.warning,
      icon: Icons.schedule,
    );
  }
  return const Pill(
    label: 'Em dia',
    cor: AppColors.success,
    icon: Icons.check_circle,
  );
}

class _ClienteCard extends StatelessWidget {
  const _ClienteCard({
    required this.cliente,
    required this.saldo,
    required this.atraso,
    required this.onDetalhes,
    required this.onEditar,
  });
  final Cliente cliente;
  final double saldo;
  final bool atraso;
  final VoidCallback onDetalhes, onEditar;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(Gap.ml),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Avatar(cliente.nome),
              const SizedBox(width: Gap.ms),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cliente.nome,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      exibirTelefone(cliente.telefone, vazio: 'Sem telefone'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saldo devedor',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      moeda(saldo),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: saldo > 0 ? AppColors.danger : AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
              _situacao(saldo, atraso),
            ],
          ),
          const SizedBox(height: Gap.md),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDetalhes,
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('Detalhes'),
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: cliente.ativo ? onEditar : null,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Editar'),
                ),
              ),
            ],
          ),
          if (cliente.ativo &&
              pode(
                AppScope.of(context).sessao.usuario?.perfil,
                Acao.gerarConvite,
              )) ...[
            const SizedBox(height: Gap.sm),
            OutlinedButton.icon(
              onPressed: () => showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => ConviteDialog(cliente: cliente),
              ),
              icon: const Icon(Icons.key_outlined),
              label: const Text('Gerar convite'),
            ),
          ],
        ],
      ),
    ),
  );
}
