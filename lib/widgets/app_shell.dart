import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/notificacoes_service.dart';
import '../core/theme.dart';
import 'common.dart';

class NavItem {
  const NavItem(this.path, this.label, this.icon, this.iconAtivo, {this.labelCurto});
  final String path;
  final String label;
  final IconData icon;
  final IconData iconAtivo;
  final String? labelCurto;
}

const navItems = [
  NavItem('/', 'Visão Geral', Icons.dashboard_outlined, Icons.dashboard, labelCurto: 'Início'),
  NavItem('/clientes', 'Clientes', Icons.people_outline, Icons.people),
  NavItem('/vendas', 'Vendas', Icons.receipt_long_outlined, Icons.receipt_long),
  NavItem('/pagamentos', 'Pagamentos', Icons.payments_outlined, Icons.payments),
  NavItem('/relatorios', 'Relatórios', Icons.bar_chart_outlined, Icons.bar_chart),
  NavItem('/notificacoes', 'Notificações', Icons.notifications_outlined, Icons.notifications)
];

/// No celular a notificação vai para o sino da AppBar; a barra inferior fica com 5 itens.
final _navMobile = navItems.where((i) => i.path != '/notificacoes').toList();

/// Estrutura comum: menu lateral fixo no desktop; AppBar + barra inferior no celular.
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
        width: snackWidth(context),
        content: Row(children: [
          Icon(n.tipo.icon, color: Colors.white, size: 20),
          const SizedBox(width: Gap.sm),
          Expanded(child: Text('${n.titulo}: ${n.mensagem}'))
        ]),
        action: SnackBarAction(label: 'Ver', textColor: AppColors.accent, onPressed: () => context.go('/notificacoes'))));
  }

  NavItem get _atual =>
      navItems.lastWhere((i) => i.path == '/' ? widget.location == '/' : widget.location.startsWith(i.path), orElse: () => navItems.first);

  @override
  Widget build(BuildContext context) => isMobile(context) ? _mobile(context) : _desktop(context);

  Widget _conteudo({required EdgeInsets padding}) => SingleChildScrollView(
      // Sempre rolável para o "puxar para atualizar" funcionar mesmo em páginas curtas.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      child: Align(
          alignment: Alignment.topCenter, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1440), child: widget.child)));

  Widget _desktop(BuildContext context) => Scaffold(
          body: Row(children: [
        SizedBox(width: 220, child: ColoredBox(color: AppColors.primary, child: _Sidebar(atual: _atual, onTap: (i) => context.go(i.path)))),
        Expanded(child: SelectionArea(child: _conteudo(padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xl))))
      ]));

  Widget _mobile(BuildContext context) {
    final atual = _atual;
    final idx = _navMobile.indexOf(atual);
    return Scaffold(
        appBar: AppBar(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            titleSpacing: Gap.md,
            title: const Row(children: [
              Icon(Icons.menu_book, color: AppColors.accent, size: 22),
              SizedBox(width: Gap.sm),
              Text('Caderneta', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19))
            ]),
            actions: [
              ListenableBuilder(
                  listenable: _service,
                  builder: (_, _) => IconButton(
                      tooltip: 'Notificações',
                      onPressed: () => context.go('/notificacoes'),
                      icon: Badge(
                          isLabelVisible: _service.naoLidas > 0,
                          backgroundColor: AppColors.accent,
                          textColor: AppColors.primary,
                          label: Text(_service.naoLidas > 99 ? '99+' : '${_service.naoLidas}'),
                          child: Icon(atual.path == '/notificacoes' ? Icons.notifications : Icons.notifications_outlined)))),
              const SizedBox(width: Gap.xs)
            ]),
        body: RefreshIndicator(
            onRefresh: () async {
              NotificacoesService.instance.revisao.value++;
              await NotificacoesService.instance.carregar(silencioso: true);
            },
            child: _conteudo(padding: const EdgeInsets.fromLTRB(Gap.md - 4, Gap.md, Gap.md - 4, Gap.lg))),
        bottomNavigationBar: _BarraInferior(selecionado: idx));
  }
}

class _BarraInferior extends StatelessWidget {
  const _BarraInferior({required this.selecionado});

  /// -1 quando a página atual não tem aba (ex.: Notificações).
  final int selecionado;

  @override
  Widget build(BuildContext context) {
    final nenhum = selecionado < 0;
    final barra = NavigationBar(
      selectedIndex: nenhum ? 0 : selecionado,
      onDestinationSelected: (i) => context.go(_navMobile[i].path),
      destinations: [
        for (final i in _navMobile)
          NavigationDestination(icon: Icon(i.icon), selectedIcon: Icon(nenhum ? i.icon : i.iconAtivo), label: i.labelCurto ?? i.label)
      ],
    );
    if (!nenhum) return barra;
    // NavigationBar exige um item selecionado: aqui ele recebe o mesmo visual dos demais.
    final tema = Theme.of(context).navigationBarTheme;
    return Theme(
      data: Theme.of(context).copyWith(
        navigationBarTheme: tema.copyWith(
          indicatorColor: Colors.transparent,
          labelTextStyle: WidgetStatePropertyAll(tema.labelTextStyle?.resolve({})),
          iconTheme: WidgetStatePropertyAll(tema.iconTheme?.resolve({})),
        ),
      ),
      child: barra,
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
            padding: EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.lg),
            child: Row(children: [
              Icon(Icons.menu_book, color: AppColors.accent),
              SizedBox(width: Gap.sm),
              Text('Caderneta', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700))
            ])),
        for (final item in navItems) _SidebarTile(item: item, ativo: item == atual, onTap: () => onTap(item))
      ]));
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({required this.item, required this.ativo, required this.onTap});
  final NavItem item;
  final bool ativo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.sm + 2, vertical: 1),
      child: Material(
          color: ativo ? Colors.white.withValues(alpha: .12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
              borderRadius: BorderRadius.circular(8),
              hoverColor: Colors.white.withValues(alpha: .06),
              onTap: onTap,
              child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.md - 4, vertical: 10),
                  decoration:
                      BoxDecoration(border: Border(left: BorderSide(color: ativo ? AppColors.accent : Colors.transparent, width: 3))),
                  child: Row(children: [
                    Icon(ativo ? item.iconAtivo : item.icon, color: ativo ? Colors.white : Colors.white70, size: 20),
                    const SizedBox(width: Gap.md - 4),
                    Expanded(
                        child: Text(item.label,
                            style: TextStyle(
                                color: ativo ? Colors.white : Colors.white70, fontWeight: ativo ? FontWeight.w600 : FontWeight.w500))),
                    if (item.path == '/notificacoes')
                      ListenableBuilder(
                          listenable: NotificacoesService.instance,
                          builder: (_, _) {
                            final n = NotificacoesService.instance.naoLidas;
                            return n == 0 ? const SizedBox.shrink() : Pill(label: n > 99 ? '99+' : '$n', cor: AppColors.accent);
                          })
                  ])))));
}
