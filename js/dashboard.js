// ===== DASHBOARD.JS - Página Principal =====

class DashboardManager {
    constructor() {
        this.init();
    }

    async init() {
        await this.carregarDados();
        this.renderizarDashboard();
    }

    async carregarDados() {
        try {
            const [vendas, clientes, dividas] = await Promise.all([
                apiService.getVendas(),
                apiService.getClientes(),
                apiService.getDividas()
            ]);

            this.vendas = vendas;
            this.clientes = clientes;
            this.dividas = dividas;
        } catch (error) {
            console.error('Erro ao carregar dados do dashboard:', error);
            showToast('Erro ao carregar dados do dashboard', 'error');
        }
    }

    renderizarDashboard() {
        this.atualizarCards();
        this.atualizarVendasRecentes();
        this.atualizarClientesAtraso();
    }

    atualizarCards() {
        // Calcular métricas
        const saldoPendente = this.calcularSaldoPendente();
        const vendasMes = this.calcularVendasMes();
        const pagamentosRecebidos = this.calcularPagamentosRecebidos();

        // Atualizar cards
        this.atualizarCard('saldo-pendente', saldoPendente, 'R$');
        this.atualizarCard('vendas-mes', vendasMes, 'R$');
        this.atualizarCard('pagamentos-recebidos', pagamentosRecebidos, 'R$');
    }

    atualizarCard(tipo, valor, prefixo = '') {
        const cards = document.querySelectorAll('.card h3');
        let cardIndex = 0;
        
        switch(tipo) {
            case 'saldo-pendente': cardIndex = 0; break;
            case 'vendas-mes': cardIndex = 1; break;
            case 'pagamentos-recebidos': cardIndex = 2; break;
        }

        if (cards[cardIndex]) {
            cards[cardIndex].textContent = `${prefixo} ${this.formatarMoeda(valor)}`;
        }
    }

    atualizarVendasRecentes() {
        const tbody = document.querySelector('tbody');
        if (!tbody || !this.vendas) return;

        const vendasRecentes = this.vendas
            .sort((a, b) => new Date(b.dataHora) - new Date(a.dataHora))
            .slice(0, 3);

        tbody.innerHTML = vendasRecentes.map(venda => {
            const cliente = this.clientes.find(c => c.id === venda.clienteId);
            const statusClass = this.getStatusClass(venda.status);
            const statusText = this.getStatusText(venda.status);

            return `
                <tr>
                    <td>#${venda.id}</td>
                    <td>${cliente ? cliente.nome : 'Cliente não encontrado'}</td>
                    <td>${this.formatarData(venda.dataHora)}</td>
                    <td>R$ ${this.formatarMoeda(venda.valorTotal)}</td>
                    <td><span class="badge badge-status ${statusClass}">${statusText}</span></td>
                    <td class="text-end">
                        <button class="btn btn-sm btn-outline-secondary">
                            <span class="material-icons">visibility</span>
                        </button>
                    </td>
                </tr>
            `;
        }).join('');
    }

    atualizarClientesAtraso() {
        const container = document.querySelector('.list-group');
        if (!container || !this.dividas) return;

        const dividasVencidas = this.dividas
            .filter(divida => divida.status === 'PENDENTE' && new Date(divida.dataVencimento) < new Date())
            .slice(0, 3);

        container.innerHTML = dividasVencidas.map(divida => {
            const cliente = this.clientes.find(c => c.id === divida.clienteId);
            const diasAtraso = this.calcularDiasAtraso(divida.dataVencimento);
            const iniciais = cliente ? this.getIniciais(cliente.nome) : 'XX';

            return `
                <div class="list-group-item d-flex align-items-center px-0">
                    <div class="avatar me-3">${iniciais}</div>
                    <div class="flex-grow-1">
                        <h6 class="mb-0">${cliente ? cliente.nome : 'Cliente não encontrado'}</h6>
                        <small class="text-muted">Vencido há ${diasAtraso} dias</small>
                    </div>
                    <div class="debt-amount">R$ ${this.formatarMoeda(divida.valorPendente)}</div>
                </div>
            `;
        }).join('');
    }

    calcularSaldoPendente() {
        if (!this.dividas) return 0;
        return this.dividas
            .filter(divida => divida.status === 'PENDENTE')
            .reduce((total, divida) => total + (divida.valorPendente || 0), 0);
    }

    calcularVendasMes() {
        if (!this.vendas) return 0;
        const inicioMes = new Date();
        inicioMes.setDate(1);
        inicioMes.setHours(0, 0, 0, 0);

        return this.vendas
            .filter(venda => new Date(venda.dataHora) >= inicioMes)
            .reduce((total, venda) => total + (venda.valorTotal || 0), 0);
    }

    calcularPagamentosRecebidos() {
        if (!this.dividas) return 0;
        const inicioMes = new Date();
        inicioMes.setDate(1);
        inicioMes.setHours(0, 0, 0, 0);

        return this.dividas
            .filter(divida => divida.status === 'PAGO' && new Date(divida.dataPagamento) >= inicioMes)
            .reduce((total, divida) => total + (divida.valorPago || 0), 0);
    }

    calcularDiasAtraso(dataVencimento) {
        const hoje = new Date();
        const vencimento = new Date(dataVencimento);
        const diffTime = hoje - vencimento;
        return Math.ceil(diffTime / (1000 * 60 * 60 * 24));
    }

    getIniciais(nome) {
        return nome.split(' ')
            .map(palavra => palavra.charAt(0))
            .slice(0, 2)
            .join('')
            .toUpperCase();
    }

    getStatusClass(status) {
        switch (status) {
            case 'PAGO': return 'badge-paid';
            case 'PENDENTE': return 'badge-pending';
            case 'CANCELADO': return 'badge-danger';
            default: return 'badge-partial';
        }
    }

    getStatusText(status) {
        switch (status) {
            case 'PAGO': return 'Quitado';
            case 'PENDENTE': return 'Pendente';
            case 'CANCELADO': return 'Cancelado';
            default: return 'Parcial';
        }
    }

    formatarData(data) {
        return new Date(data).toLocaleDateString('pt-BR');
    }

    formatarMoeda(valor) {
        return new Intl.NumberFormat('pt-BR', {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        }).format(valor);
    }
}

// Inicializar quando o DOM estiver carregado
document.addEventListener('DOMContentLoaded', function() {
    setTimeout(() => {
        new DashboardManager();
    }, 100);
});