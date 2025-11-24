// ===== NOTIFICACOES.JS - Gerenciamento de Notificações =====

class NotificacoesManager {
    constructor() {
        this.notificacoes = [];
        this.notificacoesFiltradas = [];
        this.init();
    }

    async init() {
        await this.carregarNotificacoes();
        this.setupEventListeners();
        this.renderizarNotificacoes();
    }

    async carregarNotificacoes() {
        try {
            this.notificacoes = await apiService.getNotificacoes();
            this.notificacoesFiltradas = [...this.notificacoes];
        } catch (error) {
            console.error('Erro ao carregar notificações:', error);
            showToast('Erro ao carregar notificações: ' + error.message, 'error');
            this.notificacoes = [];
            this.notificacoesFiltradas = [];
        }
    }

    setupEventListeners() {
        // Botão marcar todas como lidas
        const markAllBtn = document.getElementById('markAllRead');
        if (markAllBtn) {
            markAllBtn.addEventListener('click', () => this.marcarTodasComoLidas());
        }

        // Filtros
        const filtros = document.querySelectorAll('.card select');
        filtros.forEach(filtro => {
            filtro.addEventListener('change', () => this.aplicarFiltros());
        });

        // Botão aplicar filtros
        const aplicarBtn = document.querySelector('.btn-primary');
        if (aplicarBtn) {
            aplicarBtn.addEventListener('click', () => this.aplicarFiltros());
        }
    }

    aplicarFiltros() {
        const selects = document.querySelectorAll('.card select');
        const tipoFiltro = selects[0]?.value || '';
        const statusFiltro = selects[1]?.value || '';
        const periodoFiltro = selects[2]?.value || '';

        let notificacoes = [...this.notificacoes];

        // Filtro por tipo
        if (tipoFiltro) {
            notificacoes = notificacoes.filter(n => n.tipo === tipoFiltro.toUpperCase());
        }

        // Filtro por status
        if (statusFiltro) {
            const lida = statusFiltro === 'read';
            notificacoes = notificacoes.filter(n => n.lida === lida);
        }

        // Filtro por período
        if (periodoFiltro) {
            const hoje = new Date();
            let dataLimite = new Date();

            switch (periodoFiltro) {
                case 'today':
                    dataLimite.setHours(0, 0, 0, 0);
                    break;
                case 'week':
                    dataLimite.setDate(hoje.getDate() - 7);
                    break;
                case 'month':
                    dataLimite.setMonth(hoje.getMonth() - 1);
                    break;
            }

            if (periodoFiltro !== '') {
                notificacoes = notificacoes.filter(n => new Date(n.dataHora) >= dataLimite);
            }
        }

        this.notificacoesFiltradas = notificacoes;
        this.renderizarNotificacoes();
    }

    renderizarNotificacoes() {
        const container = document.querySelector('.notification-timeline');
        if (!container) return;

        if (this.notificacoesFiltradas.length === 0) {
            container.innerHTML = `
                <div class="card border-0 bg-white p-4 mb-3 text-center">
                    <div class="text-muted">
                        <span class="material-icons" style="font-size: 48px;">notifications_off</span>
                        <p class="mt-2">Nenhuma notificação encontrada</p>
                    </div>
                </div>
            `;
            return;
        }

        container.innerHTML = this.notificacoesFiltradas
            .sort((a, b) => new Date(b.dataHora) - new Date(a.dataHora))
            .map(notificacao => this.criarCardNotificacao(notificacao))
            .join('');

        this.setupNotificacaoEventListeners();
    }

    criarCardNotificacao(notificacao) {
        const icone = this.getIconeNotificacao(notificacao.tipo);
        const corIcone = this.getCorIcone(notificacao.tipo);
        const badge = this.getBadgeNotificacao(notificacao.tipo);
        const tempoRelativo = this.getTempoRelativo(notificacao.dataHora);
        const opacidade = notificacao.lida ? 'opacity-75' : '';

        return `
            <div class="card border-0 bg-white p-4 mb-3 fade-in ${opacidade}" data-notification-id="${notificacao.id}">
                <div class="d-flex">
                    <span class="material-icons ${corIcone} me-3">${icone}</span>
                    <div class="flex-grow-1">
                        <div class="d-flex justify-content-between align-items-center mb-2">
                            <h6 class="mb-0">${notificacao.titulo}</h6>
                            <small class="text-muted">${tempoRelativo}</small>
                        </div>
                        <p class="mb-2">${notificacao.mensagem}</p>
                        <div class="d-flex justify-content-between align-items-center">
                            ${badge}
                            ${!notificacao.lida ? `
                                <button class="btn btn-sm btn-outline-primary mark-read-btn" data-id="${notificacao.id}">
                                    Marcar como lida
                                </button>
                            ` : ''}
                        </div>
                    </div>
                </div>
            </div>
        `;
    }

    setupNotificacaoEventListeners() {
        // Botões marcar como lida
        document.querySelectorAll('.mark-read-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const id = e.target.dataset.id;
                this.marcarComoLida(id);
            });
        });
    }

    async marcarComoLida(id) {
        try {
            await apiService.marcarNotificacaoComoLida(id);
            
            // Atualizar localmente
            const notificacao = this.notificacoes.find(n => n.id == id);
            if (notificacao) {
                notificacao.lida = true;
            }

            this.renderizarNotificacoes();
            showToast('Notificação marcada como lida', 'success');
        } catch (error) {
            console.error('Erro ao marcar notificação como lida:', error);
            showToast('Erro ao marcar notificação como lida', 'error');
        }
    }

    async marcarTodasComoLidas() {
        try {
            const naoLidas = this.notificacoes.filter(n => !n.lida);
            
            for (const notificacao of naoLidas) {
                await apiService.marcarNotificacaoComoLida(notificacao.id);
                notificacao.lida = true;
            }

            this.renderizarNotificacoes();
            showToast('Todas as notificações foram marcadas como lidas!', 'success');
        } catch (error) {
            console.error('Erro ao marcar todas como lidas:', error);
            showToast('Erro ao marcar notificações como lidas', 'error');
        }
    }

    getIconeNotificacao(tipo) {
        switch (tipo) {
            case 'PAGAMENTO': return 'notifications';
            case 'VENCIMENTO': return 'warning';
            case 'VENCIDO': return 'error';
            case 'SISTEMA': return 'info';
            case 'CLIENTE': return 'person_add';
            default: return 'notifications';
        }
    }

    getCorIcone(tipo) {
        switch (tipo) {
            case 'PAGAMENTO': return 'text-primary';
            case 'VENCIMENTO': return 'text-warning';
            case 'VENCIDO': return 'text-danger';
            case 'SISTEMA': return 'text-info';
            case 'CLIENTE': return 'text-success';
            default: return 'text-primary';
        }
    }

    getBadgeNotificacao(tipo) {
        switch (tipo) {
            case 'PAGAMENTO': return '<span class="badge bg-success">Concluído</span>';
            case 'VENCIMENTO': return '<span class="badge bg-warning text-dark">Atenção</span>';
            case 'VENCIDO': return '<span class="badge bg-danger">Vencido</span>';
            case 'SISTEMA': return '<span class="badge badge-status badge-partial">Informação</span>';
            case 'CLIENTE': return '<span class="badge bg-info">Novo</span>';
            default: return '<span class="badge bg-secondary">Geral</span>';
        }
    }

    getTempoRelativo(dataHora) {
        const agora = new Date();
        const data = new Date(dataHora);
        const diffMs = agora - data;
        const diffHoras = Math.floor(diffMs / (1000 * 60 * 60));
        const diffDias = Math.floor(diffMs / (1000 * 60 * 60 * 24));

        if (diffHoras < 1) return 'há poucos minutos';
        if (diffHoras < 24) return `há ${diffHoras} horas`;
        if (diffDias === 1) return 'ontem';
        if (diffDias < 7) return `${diffDias} dias atrás`;
        if (diffDias < 30) return `${Math.floor(diffDias / 7)} semanas atrás`;
        return data.toLocaleDateString('pt-BR');
    }
}

// Inicializar quando o DOM estiver carregado
document.addEventListener('DOMContentLoaded', function() {
    setTimeout(() => {
        new NotificacoesManager();
    }, 100);
});