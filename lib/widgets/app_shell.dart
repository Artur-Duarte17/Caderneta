import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/notificacoes_service.dart';
import '../core/theme.dart';
import 'common.dart';

class NavItem {
  const NavItem(this.path, this.label, this.icon);
  final String path;
  final String label;
  final IconData icon;
}

const navItems = [
  NavItem('/', 'Visão Geral', Icons.dashboard_outlined),
  NavItem('/clientes', 'Clientes', Icons.people_outline),
  NavItem('/vendas', 'Vendas', Icons.receipt_long_outlined),
  NavItem('/pagamentos', 'Pagamentos', Icons.payments_outlined),
  NavItem('/relatorios', 'Relatórios', Icons.bar_chart_outlined),
  NavItem('/notificacoes', 'Notificações', Icons.notifications_outlined),
];

const _breakpoint = 900.0;

/// Estrutura comum: menu lateral fixo no desktop, gaveta no mobile.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _service = NotificacoesService.instance;

  @override
  void initState() {
    super.initState();
    _service.novas.addListener(_onNova);
  }

  @override
  void dispose() {
    _service.novas.removeListener(_onNova);
    super.dispose();
  }

  void _onNova() {
    final n = _service.novas.value;
    if (n == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.primary,
      content: Row(children: [
        Icon(n.tipo.icon, color: Colors.white, size: 20),
        const SizedBox(width: Gap.sm),
        Expanded(child: Text('${n.titulo}: ${n.mensagem}')),
      ]),
      action: SnackBarAction(label: 'Ver', textColor: AppColors.accent, onPressed: () => context.go('/notificacoes')),
    ));
  }

  NavItem get _atual =>
      navItems.lastWhere((i) => i.path == '/' ? widget.location == '/' : widget.location.startsWith(i.path),
          orElse: () => navItems.first);

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= _breakpoint;
    final sidebar = _Sidebar(atual: _atual, onTap: (i) {
      if (!desktop) Navigator.of(context).pop();
      context.go(i.path);
    });

    return Scaffold(
      drawer: desktop ? null : Drawer(width: 260, backgroundColor: AppColors.primary, child: sidebar),
      appBar: desktop
          ? null
          : AppBar(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              title: const Text('Caderneta', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
      body: Row(children: [
        if (desktop) SizedBox(width: 248, child: ColoredBox(color: AppColors.primary, child: sidebar)),
        Expanded(
          child: SelectionArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(desktop ? Gap.xl : Gap.md),
              child: Center(
                child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1280), child: widget.child),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.atual, required this.onTap});
  final NavItem atual;
  final ValueChanged<NavItem> onTap;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xl),
            child: Row(children: [
              Icon(Icons.menu_book, color: AppColors.accent),
              SizedBox(width: Gap.sm),
              Text('Caderneta', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
            ]),
          ),
          for (final item in navItems) _SidebarTile(item: item, ativo: item == atual, onTap: () => onTap(item)),
        ]),
      );
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({required this.item, required this.ativo, required this.onTap});
  final NavItem item;
  final bool ativo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 2),
        child: Material(
          color: ativo ? Colors.white.withValues(alpha: .12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            hoverColor: Colors.white.withValues(alpha: .06),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: Gap.md - 4, vertical: 12),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: ativo ? AppColors.accent : Colors.transparent, width: 3)),
              ),
              child: Row(children: [
                Icon(item.icon, color: ativo ? Colors.white : Colors.white70, size: 22),
                const SizedBox(width: Gap.md - 4),
                Expanded(
                  child: Text(item.label,
                      style: TextStyle(color: ativo ? Colors.white : Colors.white70, fontWeight: ativo ? FontWeight.w600 : FontWeight.w500)),
                ),
                if (item.path == '/notificacoes')
                  ListenableBuilder(
                    listenable: NotificacoesService.instance,
                    builder: (_, _) {
                      final n = NotificacoesService.instance.naoLidas;
                      return n == 0
                          ? const SizedBox.shrink()
                          : Pill(label: n > 99 ? '99+' : '$n', cor: AppColors.accent);
                    },
                  ),
              ]),
            ),
          ),
        ),
      );
}
