// ===== RELATORIOS.JS - Gerenciamento de Relatórios =====

class RelatoriosManager {
    constructor() {
        this.dadosVendas = [];
        this.dadosDividas = [];
        this.init();
    }

    async init() {
        await this.carregarDados();
        this.setupEventListeners();
        this.renderizarRelatorios();
    }

    async carregarDados() {
        try {
            // Carregar dados básicos
            const [vendas, dividas, clientes] = await Promise.all([
                apiService.getVendas(),
                apiService.getDividas(),
                apiService.getClientes()
            ]);

            this.dadosVendas = vendas;
            this.dadosDividas = dividas;
            this.clientes = clientes;
        } catch (error) {
            console.error('Erro ao carregar dados dos relatórios:', error);
            showToast('Erro ao carregar dados dos relatórios', 'error');
        }
    }

    async carregarRelatorios(startDate, endDate) {
        try {
            const [relatorioVendas, relatorioDividas] = await Promise.all([
                apiService.getRelatorioVendas(startDate, endDate),
                apiService.getRelatorioDividas(startDate, endDate)
            ]);

            return { relatorioVendas, relatorioDividas };
        } catch (error) {
            console.error('Erro ao carregar relatórios:', error);
            showToast('Erro ao carregar relatórios: ' + error.message, 'error');
            return null;
        }
    }

    setupEventListeners() {
        // Botão aplicar filtros
        const aplicarBtn = document.getElementById('applyFilterBtn');
        if (aplicarBtn) {
            aplicarBtn.addEventListener('click', () => this.aplicarFiltros());
        }

        // Botão exportar CSV
        const exportBtn = document.getElementById('exportTableCsvBtn');
        if (exportBtn) {
            exportBtn.addEventListener('click', () => this.exportarCSV());
        }
    }

    async aplicarFiltros() {
        const startDate = document.getElementById('startDate').value;
        const endDate = document.getElementById('endDate').value;
        const reportType = document.getElementById('reportType').value;

        if (!startDate || !endDate) {
            showToast('Por favor, selecione as datas de início e fim', 'error');
            return;
        }

        // Carregar relatórios da API
        const relatorios = await this.carregarRelatorios(startDate, endDate);
        if (relatorios) {
            this.renderizarRelatorios(startDate, endDate, reportType, relatorios);
            showToast('Relatórios atualizados com sucesso!', 'success');
        }
    }

    renderizarRelatorios(startDate = null, endDate = null, reportType = 'sales') {
        this.atualizarCards(startDate, endDate);
        this.atualizarTabela(startDate, endDate, reportType);
    }

    atualizarCards(startDate, endDate) {
        const vendas = this.filtrarPorPeriodo(this.dadosVendas, startDate, endDate, 'dataHora');
        const dividas = this.filtrarPorPeriodo(this.dadosDividas, startDate, endDate, 'dataVencimento');

        // Calcular métricas
        const totalVendas = vendas.reduce((sum, v) => sum + (v.valorTotal || 0), 0);
        const totalPagamentos = dividas.filter(d => d.status === 'PAGO').reduce((sum, d) => sum + (d.valorPago || 0), 0);
        const clientesAtivos = new Set(vendas.map(v => v.clienteId)).size;
        const fiadosPendentes = dividas.filter(d => d.status === 'PENDENTE').reduce((sum, d) => sum + (d.valorPendente || 0), 0);

        // Atualizar cards
        this.atualizarCard(0, totalVendas);
        this.atualizarCard(1, totalPagamentos);
        this.atualizarCard(2, clientesAtivos, '');
        this.atualizarCard(3, fiadosPendentes);
    }

    atualizarCard(index, valor, prefixo = 'R$ ') {
        const cards = document.querySelectorAll('.grid .bg-white p');
        const valueElements = document.querySelectorAll('.grid .bg-white .text-2xl');
        
        if (valueElements[index]) {
            const valorFormatado = prefixo === 'R$ ' ? this.formatarMoeda(valor) : valor.toString();
            valueElements[index].textContent = prefixo + valorFormatado;
        }
    }

    atualizarTabela(startDate, endDate, reportType) {
        const tbody = document.querySelector('tbody');
        if (!tbody) return;

        let dados = [];
        
        switch (reportType) {
            case 'sales':
                dados = this.filtrarPorPeriodo(this.dadosVendas, startDate, endDate, 'dataHora');
                break;
            case 'payments':
                dados = this.filtrarPorPeriodo(this.dadosDividas.filter(d => d.status === 'PAGO'), startDate, endDate, 'dataPagamento');
                break;
            case 'customers':
                dados = this.clientes;
                break;
        }

        tbody.innerHTML = dados.slice(0, 10).map(item => {
            switch (reportType) {
                case 'sales':
                    return this.criarLinhaVenda(item);
                case 'payments':
                    return this.criarLinhaPagamento(item);
                case 'customers':
                    return this.criarLinhaCliente(item);
                default:
                    return '';
            }
        }).join('');
    }

    criarLinhaVenda(venda) {
        const cliente = this.clientes.find(c => c.id === venda.clienteId);
        const statusClass = this.getStatusClass(venda.status);
        const statusText = this.getStatusText(venda.status);

        return `
            <tr>
                <td class="px-4 py-2">${this.formatarData(venda.dataHora)}</td>
                <td class="px-4 py-2">${cliente ? cliente.nome : 'Cliente não encontrado'}</td>
                <td class="px-4 py-2">R$ ${this.formatarMoeda(venda.valorTotal)}</td>
                <td class="px-4 py-2">
                    <span class="px-2 py-1 ${statusClass} rounded-full text-xs">${statusText}</span>
                </td>
                <td class="px-4 py-2">
                    <button class="text-blue-600 hover:text-blue-800 focus:outline-none">
                        <span class="material-icons text-sm">visibility</span>
                    </button>
                </td>
            </tr>
        `;
    }

    criarLinhaPagamento(divida) {
        const cliente = this.clientes.find(c => c.id === divida.clienteId);

        return `
            <tr>
                <td class="px-4 py-2">${this.formatarData(divida.dataPagamento)}</td>
                <td class="px-4 py-2">${cliente ? cliente.nome : 'Cliente não encontrado'}</td>
                <td class="px-4 py-2">R$ ${this.formatarMoeda(divida.valorPago)}</td>
                <td class="px-4 py-2">
                    <span class="px-2 py-1 bg-green-100 text-green-800 rounded-full text-xs">Pago</span>
                </td>
                <td class="px-4 py-2">
                    <button class="text-blue-600 hover:text-blue-800 focus:outline-none">
                        <span class="material-icons text-sm">visibility</span>
                    </button>
                </td>
            </tr>
        `;
    }

    criarLinhaCliente(cliente) {
        const saldoDevedor = cliente.saldoDevedor || 0;
        const statusClass = saldoDevedor > 0 ? 'bg-red-100 text-red-800' : 'bg-green-100 text-green-800';
        const statusText = saldoDevedor > 0 ? 'Devendo' : 'Quitado';

        return `
            <tr>
                <td class="px-4 py-2">${this.formatarData(cliente.dataCadastro || new Date())}</td>
                <td class="px-4 py-2">${cliente.nome}</td>
                <td class="px-4 py-2">R$ ${this.formatarMoeda(saldoDevedor)}</td>
                <td class="px-4 py-2">
                    <span class="px-2 py-1 ${statusClass} rounded-full text-xs">${statusText}</span>
                </td>
                <td class="px-4 py-2">
                    <button class="text-blue-600 hover:text-blue-800 focus:outline-none">
                        <span class="material-icons text-sm">visibility</span>
                    </button>
                </td>
            </tr>
        `;
    }

    filtrarPorPeriodo(dados, startDate, endDate, campoData) {
        if (!startDate || !endDate) return dados;

        const inicio = new Date(startDate);
        const fim = new Date(endDate);
        fim.setHours(23, 59, 59, 999);

        return dados.filter(item => {
            const dataItem = new Date(item[campoData]);
            return dataItem >= inicio && dataItem <= fim;
        });
    }

    exportarCSV() {
        const reportType = document.getElementById('reportType').value;
        const startDate = document.getElementById('startDate').value;
        const endDate = document.getElementById('endDate').value;

        let dados = [];
        let headers = [];

        switch (reportType) {
            case 'sales':
                dados = this.filtrarPorPeriodo(this.dadosVendas, startDate, endDate, 'dataHora');
                headers = ['Data', 'Cliente', 'Valor', 'Status'];
                break;
            case 'payments':
                dados = this.filtrarPorPeriodo(this.dadosDividas.filter(d => d.status === 'PAGO'), startDate, endDate, 'dataPagamento');
                headers = ['Data', 'Cliente', 'Valor', 'Status'];
                break;
            case 'customers':
                dados = this.clientes;
                headers = ['Nome', 'Telefone', 'Email', 'Saldo Devedor'];
                break;
        }

        this.gerarCSV(dados, headers, reportType);
        showToast('CSV exportado com sucesso!', 'success');
    }

    gerarCSV(dados, headers, tipo) {
        let csv = headers.join(',') + '\n';

        dados.forEach(item => {
            let linha = [];
            switch (tipo) {
                case 'sales':
                    const clienteVenda = this.clientes.find(c => c.id === item.clienteId);
                    linha = [
                        this.formatarData(item.dataHora),
                        clienteVenda ? clienteVenda.nome : 'N/A',
                        item.valorTotal,
                        this.getStatusText(item.status)
                    ];
                    break;
                case 'payments':
                    const clientePagamento = this.clientes.find(c => c.id === item.clienteId);
                    linha = [
                        this.formatarData(item.dataPagamento),
                        clientePagamento ? clientePagamento.nome : 'N/A',
                        item.valorPago,
                        'Pago'
                    ];
                    break;
                case 'customers':
                    linha = [
                        item.nome,
                        item.telefone || 'N/A',
                        item.email || 'N/A',
                        item.saldoDevedor || 0
                    ];
                    break;
            }
            csv += linha.join(',') + '\n';
        });

        // Download do arquivo
        const blob = new Blob([csv], { type: 'text/csv' });
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `relatorio_${tipo}_${new Date().toISOString().split('T')[0]}.csv`;
        a.click();
        window.URL.revokeObjectURL(url);
    }

    getStatusClass(status) {
        switch (status) {
            case 'PAGO': return 'bg-green-100 text-green-800';
            case 'PENDENTE': return 'bg-red-100 text-red-800';
            case 'CANCELADO': return 'bg-gray-100 text-gray-800';
            default: return 'bg-yellow-100 text-yellow-800';
        }
    }

    getStatusText(status) {
        switch (status) {
            case 'PAGO': return 'Pago';
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
        new RelatoriosManager();
    }, 100);
});