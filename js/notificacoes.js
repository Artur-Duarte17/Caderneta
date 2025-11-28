// ===== NOTIFICACOES.JS - Lógica Corrigida e Visual Original =====

class NotificacoesManager {
  constructor() {
    this.notificacoes = [];
    this.notificacoesFiltradas = [];
    this.init();
  }

  async init() {
    await this.carregarNotificacoes();
    this.setupEventListeners();
  }

  async carregarNotificacoes() {
    try {
      const dados = await apiService.getNotificacoes();

      // MAPEAMENTO: Backend (Java) -> Frontend (Visual)
      this.notificacoes = dados.map(n => {
        // Define o visual e o tipo de filtro baseado no dado do banco
        const visual = this.definirVisual(n.tipoNotificacao);

        return {
          id: n.id,
          mensagem: n.mensagem,
          dataHora: n.dataEnvio,
          lida: n.lida,

          // Dados Visuais mapeados
          titulo: visual.titulo,
          tipoFiltro: visual.tipoFiltro, // 'payment', 'due', 'system'
          icone: visual.icone,
          corIcone: visual.corIcone,
          badgeHTML: visual.badgeHTML
        };
      });

      // Inicializa a lista
      this.notificacoesFiltradas = [...this.notificacoes];
      this.renderizar();
      this.atualizarBadge();

    } catch (error) {
      console.error("Erro:", error);
      this.renderizarErro();
    }
  }

  setupEventListeners() {
    // 1. Botão APLICAR (Obrigatório clicar para filtrar)
    const btnAplicar = document.getElementById('btnAplicar');
    if (btnAplicar) {
      btnAplicar.addEventListener('click', () => this.aplicarFiltros());
    }

    // 2. Botão Marcar Todas
    const btnTodas = document.getElementById('markAllRead');
    if (btnTodas) {
      btnTodas.addEventListener('click', () => this.marcarTodasLidas());
    }

    // 3. Botão Individual (Delegação de Evento)
    const container = document.querySelector('.notification-timeline');
    if (container) {
      container.addEventListener('click', (e) => {
        const btn = e.target.closest('.mark-read-btn');
        if (btn) {
          this.marcarUmaLida(btn.dataset.id);
        }
      });
    }
  }

  aplicarFiltros() {
    const tipo = document.getElementById('filtroTipo').value;
    const status = document.getElementById('filtroStatus').value;
    const periodo = document.getElementById('filtroPeriodo').value;

    let lista = [...this.notificacoes];

    // Filtro 1: Tipo (Compara o valor do select com o tipoFiltro mapeado)
    if (tipo && tipo !== '') {
      lista = lista.filter(n => n.tipoFiltro === tipo);
    }

    // Filtro 2: Status
    if (status && status !== '') {
      const deveEstarLida = (status === 'read');
      lista = lista.filter(n => n.lida === deveEstarLida);
    }

    // Filtro 3: Período
    if (periodo && periodo !== '') {
      const hoje = new Date();
      hoje.setHours(0,0,0,0);

      lista = lista.filter(n => {
        const d = new Date(n.dataHora);
        d.setHours(0,0,0,0);
        const diffMs = hoje - d;
        const diffDias = Math.floor(diffMs / (1000 * 60 * 60 * 24));

        if (periodo === 'today') return diffDias === 0;
        if (periodo === 'week') return diffDias <= 7 && diffDias >= 0;
        if (periodo === 'month') return diffDias <= 30 && diffDias >= 0;
        return true;
      });
    }

    // Ordenar: Mais recente primeiro
    lista.sort((a, b) => new Date(b.dataHora) - new Date(a.dataHora));

    this.notificacoesFiltradas = lista;
    this.renderizar();
  }

  renderizar() {
    const container = document.querySelector('.notification-timeline');

    if (!this.notificacoesFiltradas.length) {
      container.innerHTML = `
                <div class="text-center py-5 text-muted">
                    <span class="material-icons fs-1" style="opacity:0.3">notifications_off</span>
                    <p class="mt-2">Nenhuma notificação encontrada</p>
                </div>`;
      return;
    }

    container.innerHTML = this.notificacoesFiltradas.map(n => `
            <div class="card border-0 bg-white p-4 mb-3 shadow-sm fade-in ${n.lida ? 'opacity-50 bg-light' : ''}">
                <div class="d-flex align-items-start">
                    <div class="me-3 mt-1">
                        <span class="material-icons ${n.corIcone} fs-4">${n.icone}</span>
                    </div>
                    <div class="flex-grow-1">
                        <div class="d-flex justify-content-between align-items-center mb-1">
                            <h6 class="mb-0 fw-bold text-dark">${n.titulo}</h6>
                            <small class="text-muted" style="font-size:0.8rem">${this.getTempoRelativo(n.dataHora)}</small>
                        </div>
                        <p class="mb-2 text-secondary small">${n.mensagem}</p>
                        <div class="d-flex justify-content-between align-items-center">
                            ${n.badgeHTML}
                            ${!n.lida
        ? `<button class="btn btn-outline-primary btn-sm mark-read-btn" data-id="${n.id}" style="font-size: 0.8rem;">Marcar lida</button>`
        : '<span class="text-success small fw-bold"><i class="material-icons align-middle" style="font-size:16px">check_circle</i> Lida</span>'}
                        </div>
                    </div>
                </div>
            </div>
        `).join('');
  }

  // Lógica Visual: Mapeia o ENUM do Java para o Filtro do HTML
  definirVisual(tipoBackend) {
    // 1. Pagamentos
    if (['PAGAMENTO_RECEBIDO', 'CONFIRMACAO_PAGAMENTO', 'LEMBRETE_PAGAMENTO'].includes(tipoBackend)) {
      return {
        tipoFiltro: 'payment', // Valor do <option>
        titulo: 'Pagamento Recebido',
        icone: 'payments',
        corIcone: 'text-primary',
        badgeHTML: '<span class="badge bg-success">Concluído</span>'
      };
    }
    // 2. Vencimentos
    if (['LEMBRETE_VENCIMENTO', 'AVISO_DIVIDA_VENCIDA'].includes(tipoBackend)) {
      const isAtrasado = tipoBackend === 'AVISO_DIVIDA_VENCIDA';
      return {
        tipoFiltro: 'due', // Valor do <option>
        titulo: isAtrasado ? 'Conta Vencida' : 'Vencimento Próximo',
        icone: isAtrasado ? 'error' : 'notifications_active',
        corIcone: isAtrasado ? 'text-danger' : 'text-warning',
        badgeHTML: isAtrasado ? '<span class="badge bg-danger">Vencido</span>' : '<span class="badge bg-warning text-dark">Atenção</span>'
      };
    }
    // 3. Sistema (Padrão)
    return {
      tipoFiltro: 'system', // Valor do <option>
      titulo: 'Sistema',
      icone: 'info',
      corIcone: 'text-info',
      badgeHTML: '<span class="badge bg-info text-dark">Info</span>'
    };
  }

  async marcarUmaLida(id) {
    const item = this.notificacoes.find(n => n.id == id);
    if (item) {
      item.lida = true;
      this.aplicarFiltros(); // Re-renderiza na hora
      this.atualizarBadge();
      try { await apiService.marcarNotificacaoComoLida(id); } catch(e) {}
    }
  }

  async marcarTodasLidas() {
    this.notificacoes.forEach(n => n.lida = true);
    this.renderizar();
    this.atualizarBadge();
    try { await apiService.request('/notificacoes/marcar-todas-lidas', { method: 'PATCH' }); } catch(e) {}
  }

  getTempoRelativo(dataISO) {
    if(!dataISO) return '';
    const diff = (new Date() - new Date(dataISO)) / 1000;
    if (diff < 60) return 'agora';
    if (diff < 3600) return `há ${Math.floor(diff/60)} min`;
    if (diff < 86400) return `há ${Math.floor(diff/3600)} h`;
    return new Date(dataISO).toLocaleDateString('pt-BR');
  }

  atualizarBadge() {
    const count = this.notificacoes.filter(n => !n.lida).length;
    const badge = document.getElementById('notificationBadge');
    if(badge) {
      badge.textContent = count;
      badge.style.display = count > 0 ? 'inline-block' : 'none';
    }
  }

  renderizarErro() {
    document.querySelector('.notification-timeline').innerHTML = '<div class="alert alert-danger text-center">Erro ao carregar dados.</div>';
  }
}

document.addEventListener('DOMContentLoaded', () => new NotificacoesManager());