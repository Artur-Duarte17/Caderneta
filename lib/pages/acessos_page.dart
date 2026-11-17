import 'forms/acessos_form.dart';
import 'package:flutter/material.dart';
import '../core/app_runtime.dart';
import '../core/models.dart';
import '../core/paged_controller.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/paginacao.dart';

class AcessosPage extends StatefulWidget {
  const AcessosPage({super.key});
  @override
  State<AcessosPage> createState() => _AcessosPageState();
}

class _AcessosPageState extends State<AcessosPage> {
  PagedController<ContaAcesso>? _c;
  bool _busy = false;
  bool _mostrarExcluidos = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _c ??= PagedController(
      AppScope.of(context).acessos.listar,
      cache: 'acessos',
      armazenamento: AppScope.of(context).cache,
    )..atualizar();
  }

  Future<void> _ativo(ContaAcesso conta) async {
    if (_busy) return;
    final runtime = AppScope.of(context);
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${conta.ativo ? 'Desativar' : 'Ativar'} acesso?'),
        content: Text('${conta.nome} (${conta.login})'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      await executarComCarregamento(
        context,
        conta.ativo ? 'Desativando acesso' : 'Ativando acesso',
        () => runtime.acessos.ativo(conta.id, !conta.ativo),
      );
      if (!mounted) return;
      toast(context, 'Acesso atualizado.');
      _c!.atualizar();
    } catch (e) {
      if (mounted) toast(context, '$e', erro: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Gerente promove funcionário a gerente (ou o inverso) com o mesmo login.
  Future<void> _perfil(ContaAcesso conta) async {
    if (_busy) return;
    final runtime = AppScope.of(context);
    final promover = conta.perfil == Perfil.funcionario;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(promover ? 'Tornar gerente?' : 'Tornar funcionário?'),
        content: Text(
          '${conta.nome} (${conta.login})\n\n'
          '${promover ? 'Passa a ter acesso de gerente: relatórios, auditoria, acessos, limite de crédito e edição de vendas.' : 'Perde o acesso de gerente e volta a ser funcionário.'}\n\n'
          'O login e a senha continuam os mesmos. Se a pessoa estiver conectada, '
          'precisará entrar de novo para o novo perfil valer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(promover ? 'Tornar gerente' : 'Tornar funcionário'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      await executarComCarregamento(
        context,
        promover ? 'Tornando gerente' : 'Tornando funcionário',
        () => runtime.acessos.alterarPerfil(
          conta.id,
          promover ? Perfil.gerente : Perfil.funcionario,
        ),
      );
      if (!mounted) return;
      toast(
        context,
        promover
            ? '${conta.nome} agora é gerente.'
            : '${conta.nome} agora é funcionário.',
      );
      _c!.atualizar();
    } catch (e) {
      if (mounted) toast(context, '$e', erro: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Exclusão lógica: some da lista e perde o acesso; o cadastro e as vendas continuam no banco.
  Future<void> _excluir(ContaAcesso conta) async {
    if (_busy) return;
    final runtime = AppScope.of(context);
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir funcionário?'),
        content: Text(
          '${conta.nome} (${conta.login})\n\n'
          'A pessoa perde o acesso na hora e sai desta lista. Nada é apagado: o cadastro e as '
          'vendas que ela registrou continuam no histórico.\n\n'
          'Se for recontratada, cadastre de novo com o mesmo CPF (a conta antiga é reativada) '
          'ou use "Mostrar excluídos" → Restaurar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      await executarComCarregamento(
        context,
        'Excluindo acesso',
        () => runtime.acessos.excluir(conta.id),
      );
      if (!mounted) return;
      toast(context, '${conta.nome} foi excluído.');
      _c!.atualizar();
    } catch (e) {
      if (mounted) toast(context, '$e', erro: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Restaura conta excluída; exige senha nova (a antiga deixa de valer).
  Future<void> _restaurar(ContaAcesso conta) async {
    if (_busy) return;
    final runtime = AppScope.of(context);
    final senha = await showDialog<String>(
      context: context,
      builder: (_) => RestaurarDialog(conta: conta),
    );
    if (senha == null || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      await executarComCarregamento(
        context,
        'Restaurando acesso',
        () => runtime.acessos.restaurar(conta.id, senha),
      );
      if (!mounted) return;
      toast(context, '${conta.nome} foi restaurado como funcionário.');
      _c!.atualizar();
    } catch (e) {
      if (mounted) toast(context, '$e', erro: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _filtrarExcluidos(bool mostrar) {
    setState(() => _mostrarExcluidos = mostrar);
    final f = Map.of(_c!.filtros);
    if (mostrar) {
      f['excluidas'] = 'true';
    } else {
      f.remove('excluidas');
    }
    _c!.filtrar(f);
  }

  Future<void> _funcionario() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const FuncionarioForm(),
    );
    if (ok == true && mounted) _c!.atualizar();
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = AppScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          titulo: 'Acessos',
          subtitulo: 'Contas e situação de acesso',
          acoes: [
            if (r.acessos.permiteCriarFuncionario)
              FilledButton.icon(
                onPressed: _funcionario,
                icon: const Icon(Icons.person_add_outlined),
                label: const Text('Criar funcionário'),
              ),
          ],
        ),
        if (r.acessos.suportaBusca)
          FilterField(
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar nome ou login',
                suffixIcon: Icon(Icons.search),
              ),
              onSubmitted: (value) => _c!.filtrar({
                if (value.trim().isNotEmpty) 'busca': value.trim(),
                if (_mostrarExcluidos) 'excluidas': 'true',
              }),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: FilterChip(
            label: const Text('Mostrar excluídos'),
            selected: _mostrarExcluidos,
            onSelected: _busy ? null : _filtrarExcluidos,
          ),
        ),
        const SizedBox(height: Gap.md),
        PaginatedSection<ContaAcesso>(
          controller: _c!,
          builder: (lista) => AppTable(
            colunas: const ['Nome', 'Login', 'Perfil', 'Situação', 'Ação'],
            linhas: [
              for (final conta in lista)
                [
                  Text(conta.nome),
                  Text(conta.login),
                  Text(conta.perfil?.label ?? 'Desconhecido'),
                  // Excluído em destaque (etiqueta vermelha) para se distinguir na lista.
                  conta.excluido
                      ? const Pill(
                          label: 'Excluído',
                          cor: AppColors.danger,
                          icon: Icons.person_off_outlined,
                        )
                      : Text(conta.ativo ? 'Ativo' : 'Inativo'),
                  conta.id == r.sessao.usuario!.id
                      ? const Text('Sua conta')
                      : conta.excluido
                      // Verde (sucesso) com ícone e fundo: a única ação desta linha, distinta das
                      // ações azuis (Desativar, Tornar gerente) das contas ativas.
                      ? TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.success,
                            backgroundColor: AppColors.success.withValues(
                              alpha: .1,
                            ),
                          ),
                          onPressed: _busy ? null : () => _restaurar(conta),
                          icon: const Icon(Icons.restore, size: 18),
                          label: const Text('Restaurar'),
                        )
                      : Row(
                          // Uma linha só: a tabela tem altura de linha fixa (empilhar cortaria o botão).
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: _busy ? null : () => _ativo(conta),
                              child: Text(conta.ativo ? 'Desativar' : 'Ativar'),
                            ),
                            // Só contas da equipe; clientes não viram gerente.
                            if (conta.perfil == Perfil.funcionario ||
                                conta.perfil == Perfil.gerente)
                              TextButton(
                                onPressed: _busy ? null : () => _perfil(conta),
                                child: Text(
                                  conta.perfil == Perfil.funcionario
                                      ? 'Tornar gerente'
                                      : 'Tornar funcionário',
                                ),
                              ),
                            if (conta.perfil == Perfil.funcionario ||
                                conta.perfil == Perfil.gerente)
                              IconButton(
                                tooltip: 'Excluir',
                                icon: const Icon(Icons.delete_outline),
                                color: AppColors.danger,
                                onPressed: _busy ? null : () => _excluir(conta),
                              ),
                          ],
                        ),
                ],
            ],
          ),
        ),
      ],
    );
  }
}
