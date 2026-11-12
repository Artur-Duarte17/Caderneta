import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/app_runtime.dart';
import '../core/permissoes.dart';
import '../core/theme.dart';
import 'common.dart';

class NavItem {
  const NavItem(this.path, this.label, this.icon);
  final String path, label;
  final IconData icon;
}

const navItems = [
  NavItem('/', 'Visão Geral', Icons.dashboard_outlined),
  NavItem('/clientes', 'Clientes', Icons.people_outline),
  NavItem('/vendas', 'Vendas', Icons.receipt_long_outlined),
  NavItem('/pagamentos', 'Pagamentos', Icons.payments_outlined),
  NavItem('/relatorios', 'Relatórios', Icons.bar_chart_outlined),
  NavItem('/historico', 'Histórico', Icons.history),
  NavItem('/auditoria', 'Auditoria', Icons.policy_outlined),
  NavItem('/acessos', 'Acessos', Icons.manage_accounts_outlined),
  NavItem('/minha', 'Resumo', Icons.dashboard_outlined),
  NavItem('/minha/compras', 'Compras', Icons.shopping_bag_outlined),
  NavItem('/minha/dividas', 'Dívidas e vencimentos', Icons.event_outlined),
  NavItem('/minha/pagamentos', 'Pagamentos', Icons.payments_outlined),
  NavItem('/minha/historico', 'Histórico', Icons.history),
];

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final sessao = AppScope.of(context).sessao;
    if (!sessao.autenticado) {
      return const Scaffold(body: LoadingState(mensagem: 'Carregando'));
    }
    final user = sessao.usuario!;
    final itens = navItems
        .where((i) => rotaPermitida(user.perfil, i.path))
        .toList();
    final desktop = MediaQuery.sizeOf(context).width >= 900;
    final sidebar = SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.menu_book, color: AppColors.accent),
                    SizedBox(width: Gap.sm),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Caderneta',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (user.lojaNome.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: Gap.xs, left: 32),
                    child: Text(
                      user.lojaNome,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: Gap.md),
              children: [
                for (final item in itens)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Gap.xs),
                    child: ListTile(
                      selected: location == item.path,
                      selectedTileColor: Colors.white.withValues(alpha: .12),
                      selectedColor: Colors.white,
                      textColor: Colors.white70,
                      iconColor: Colors.white70,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      leading: Icon(item.icon),
                      title: Text(item.label),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: Gap.ms,
                      ),
                      onTap: () {
                        if (!desktop) Navigator.pop(context);
                        context.go(item.path);
                      },
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Column(
              children: [
                Row(
                  children: [
                    Avatar(user.nome),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.nome,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white),
                          ),
                          Text(
                            user.perfil?.label ?? 'Perfil desconhecido',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.sm),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  onPressed: sessao.ocupado
                      ? null
                      : () => executarComCarregamento(
                          context,
                          'Saindo',
                          sessao.sair,
                        ),
                  icon: const Icon(Icons.logout),
                  label: const Text('Sair'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return Scaffold(
      drawer: desktop
          ? null
          : Drawer(
              width: 280,
              backgroundColor: AppColors.primary,
              child: sidebar,
            ),
      appBar: desktop
          ? null
          : AppBar(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              title: Text(
                user.lojaNome.isEmpty ? 'Caderneta' : user.lojaNome,
                overflow: TextOverflow.ellipsis,
              ),
            ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (desktop)
            SizedBox(
              width: 248,
              child: Material(color: AppColors.primary, child: sidebar),
            ),
          Expanded(
            child: SelectionArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(desktop ? Gap.lg : Gap.md),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(width: double.infinity, child: child),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
