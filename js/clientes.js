// ===== CLIENTES.JS - Gerenciamento de Clientes =====

class ClientesManager {
    constructor() {
        this.clientes = [];
        this.clientesFiltrados = [];
        this.init();
    }

    async init() {
        await this.carregarClientes();
        this.setupEventListeners();
        this.renderizarClientes();
    }

    async carregarClientes() {
        try {
            this.clientes = await apiService.getClientes();
            this.clientesFiltrados = [...this.clientes];
        } catch (error) {
            console.error('Erro ao carregar clientes:', error);
            showToast('Erro ao carregar clientes: ' + error.message, 'error');
            this.clientes = [];
            this.clientesFiltrados = [];
        }
    }

    setupEventListeners() {
        // Busca
        const searchInput = document.querySelector('input[placeholder="Buscar por nome ou telefone"]');
        if (searchInput) {
            searchInput.addEventListener('input', (e) => this.filtrarClientes(e.target.value));
        }

        // Formulário novo cliente
        const novoClienteForm = document.querySelector('#newClientOffcanvas form');
        if (novoClienteForm) {
            novoClienteForm.addEventListener('submit', (e) => this.criarCliente(e));
        }

        // Toggle fiador
        const hasGuarantor = document.getElementById('hasGuarantor');
        if (hasGuarantor) {
            hasGuarantor.addEventListener('change', this.toggleFiadorFields);
        }

        // Botão salvar edição
        const saveClientBtn = document.getElementById('saveClientBtn');
        if (saveClientBtn) {
            saveClientBtn.addEventListener('click', () => this.salvarEdicaoCliente());
        }
    }

    filtrarClientes(termo) {
        if (!termo.trim()) {
            this.clientesFiltrados = [...this.clientes];
        } else {
            const termoLower = termo.toLowerCase();
            this.clientesFiltrados = this.clientes.filter(cliente => 
                cliente.nome.toLowerCase().includes(termoLower) ||
                cliente.telefone.includes(termo)
            );
        }
        this.renderizarClientes();
    }

    renderizarClientes() {
        const container = document.querySelector('.row.g-4');
        if (!container) return;

        if (this.clientesFiltrados.length === 0) {
            container.innerHTML = `
                <div class="col-12 text-center py-5">
                    <div class="text-muted">
                        <span class="material-icons" style="font-size: 48px;">person_off</span>
                        <p class="mt-2">Nenhum cliente encontrado</p>
                    </div>
                </div>
            `;
            return;
        }

        container.innerHTML = this.clientesFiltrados.map(cliente => this.criarCardCliente(cliente)).join('');
        this.setupCardEventListeners();
    }

    criarCardCliente(cliente) {
        const iniciais = this.getIniciais(cliente.nome);
        const saldoDevedor = cliente.saldoDevedor || 0;
        const status = this.getStatusCliente(saldoDevedor);
        const statusClass = this.getStatusClass(status);

        return `
            <div class="col-md-4 col-lg-3 fade-in">
                <div class="card border-0 bg-white p-3 h-100">
                    <div class="d-flex align-items-center mb-3">
                        <div class="avatar me-3">${iniciais}</div>
                        <div>
                            <h5 class="mb-0">${cliente.nome}</h5>
                            <small class="text-muted">${cliente.telefone || 'Sem telefone'}</small>
                        </div>
                    </div>
                    <div class="d-flex justify-content-between align-items-center mb-3">
                        <div>
                            <small class="text-muted d-block">Saldo devedor</small>
                            <div class="${saldoDevedor > 0 ? 'debt-amount' : 'text-success fw-bold'}">
                                R$ ${this.formatarMoeda(saldoDevedor)}
                            </div>
                        </div>
                        <span class="badge badge-status ${statusClass}">${status}</span>
                    </div>
                    <div class="d-flex gap-2">
                        <button class="btn btn-sm btn-outline-primary flex-fill view-client-btn" 
                                data-client-id="${cliente.id}">
                            <span class="material-icons me-1" style="font-size: 16px;">visibility</span>
                            Detalhes
                        </button>
                        <button class="btn btn-sm btn-outline-secondary flex-fill edit-client-btn" 
                                data-client-id="${cliente.id}">
                            <span class="material-icons me-1" style="font-size: 16px;">edit</span>
                            Editar
                        </button>
                    </div>
                </div>
            </div>
        `;
    }

    setupCardEventListeners() {
        // Botões de visualizar
        document.querySelectorAll('.view-client-btn').forEach(btn => {
            btn.addEventListener('click', (e) => this.visualizarCliente(e.target.dataset.clientId));
        });

        // Botões de editar
        document.querySelectorAll('.edit-client-btn').forEach(btn => {
            btn.addEventListener('click', (e) => this.editarCliente(e.target.dataset.clientId));
        });
    }

    async visualizarCliente(clienteId) {
        try {
            const cliente = await apiService.getClienteById(clienteId);
            this.preencherModalVisualizacao(cliente);
            
            const modal = new bootstrap.Modal(document.getElementById('viewClientModal'));
            modal.show();
        } catch (error) {
            console.error('Erro ao carregar cliente:', error);
            showToast('Erro ao carregar dados do cliente', 'error');
        }
    }

    preencherModalVisualizacao(cliente) {
        document.getElementById('viewClientName').textContent = cliente.nome;
        document.getElementById('viewClientPhone').textContent = cliente.telefone || 'Não informado';
        document.getElementById('viewClientEmail').textContent = cliente.email || 'Não informado';
        document.getElementById('viewClientCpf').textContent = cliente.cpf || 'Não informado';
        document.getElementById('viewClientAddress').textContent = cliente.endereco || 'Não informado';
        
        const limite = cliente.limiteCredito || 0;
        const divida = cliente.saldoDevedor || 0;
        const disponivel = limite - divida;
        
        document.getElementById('viewClientLimit').textContent = this.formatarMoeda(limite);
        document.getElementById('viewClientDebt').textContent = this.formatarMoeda(divida);
        document.getElementById('viewClientAvailable').textContent = this.formatarMoeda(disponivel);
        
        const status = this.getStatusCliente(divida);
        const statusBadge = document.getElementById('viewClientStatus');
        statusBadge.textContent = status;
        statusBadge.className = `badge badge-status ${this.getStatusClass(status)}`;
    }

    async editarCliente(clienteId) {
        try {
            const cliente = await apiService.getClienteById(clienteId);
            this.preencherModalEdicao(cliente);
            
            const modal = new bootstrap.Modal(document.getElementById('editClientModal'));
            modal.show();
        } catch (error) {
            console.error('Erro ao carregar cliente:', error);
            showToast('Erro ao carregar dados do cliente', 'error');
        }
    }

    preencherModalEdicao(cliente) {
        document.getElementById('editClientId').value = cliente.id;
        document.getElementById('editClientName').value = cliente.nome;
        document.getElementById('editClientPhone').value = cliente.telefone || '';
        document.getElementById('editClientEmail').value = cliente.email || '';
        document.getElementById('editClientCpf').value = cliente.cpf || '';
        document.getElementById('editClientAddress').value = cliente.endereco || '';
        document.getElementById('editClientLimit').value = cliente.limiteCredito || 0;
    }

    async salvarEdicaoCliente() {
        const form = document.getElementById('editClientForm');
        if (!this.validarFormulario(form)) return;

        const clienteId = document.getElementById('editClientId').value;
        const dadosCliente = {
            nome: document.getElementById('editClientName').value,
            telefone: document.getElementById('editClientPhone').value,
            email: document.getElementById('editClientEmail').value || null,
            cpf: document.getElementById('editClientCpf').value || null,
            endereco: document.getElementById('editClientAddress').value || null,
            limiteCredito: parseFloat(document.getElementById('editClientLimit').value) || 0
        };

        try {
            await apiService.updateCliente(clienteId, dadosCliente);
            showToast('Cliente atualizado com sucesso!', 'success');
            
            const modal = bootstrap.Modal.getInstance(document.getElementById('editClientModal'));
            modal.hide();
            
            await this.carregarClientes();
            this.renderizarClientes();
        } catch (error) {
            console.error('Erro ao atualizar cliente:', error);
            showToast('Erro ao atualizar cliente: ' + error.message, 'error');
        }
    }

    async criarCliente(event) {
        event.preventDefault();
        
        const form = event.target;
        if (!this.validarFormulario(form)) return;

        const formData = new FormData(form);
        const dadosCliente = {
            nome: formData.get('nome') || form.querySelector('input[type="text"]').value,
            telefone: formData.get('telefone') || form.querySelector('input[type="tel"]').value,
            email: formData.get('email') || form.querySelector('input[type="email"]').value || null,
            cpf: formData.get('cpf') || form.querySelector('input[type="text"]:nth-of-type(2)').value || null,
            endereco: formData.get('endereco') || form.querySelector('textarea').value || null,
            limiteCredito: parseFloat(formData.get('limite') || form.querySelector('input[type="number"]').value) || 0
        };

        // Dados do fiador se incluído
        const hasGuarantor = document.getElementById('hasGuarantor').checked;
        let fiadorData = null;
        
        if (hasGuarantor) {
            const guarantorFields = document.getElementById('guarantorFields');
            const inputs = guarantorFields.querySelectorAll('input, textarea');
            fiadorData = {
                nome: inputs[0].value,
                telefone: inputs[1].value,
                email: inputs[2].value || null,
                cpf: inputs[3].value || null,
                endereco: inputs[4].value || null
            };
        }

        try {
            const novoCliente = await apiService.createCliente(dadosCliente);
            
            // Criar fiador se necessário
            if (fiadorData && fiadorData.nome) {
                fiadorData.clienteId = novoCliente.id;
                await apiService.createFiador(fiadorData);
            }

            showToast('Cliente criado com sucesso!', 'success');
            
            const offcanvas = bootstrap.Offcanvas.getInstance(document.getElementById('newClientOffcanvas'));
            offcanvas.hide();
            
            form.reset();
            document.getElementById('hasGuarantor').checked = false;
            this.toggleFiadorFields();
            
            await this.carregarClientes();
            this.renderizarClientes();
        } catch (error) {
            console.error('Erro ao criar cliente:', error);
            showToast('Erro ao criar cliente: ' + error.message, 'error');
        }
    }

    toggleFiadorFields() {
        const hasGuarantor = document.getElementById('hasGuarantor');
        const guarantorFields = document.getElementById('guarantorFields');
        
        if (hasGuarantor.checked) {
            guarantorFields.classList.remove('d-none');
        } else {
            guarantorFields.classList.add('d-none');
        }
    }

    validarFormulario(form) {
        let isValid = true;
        const requiredFields = form.querySelectorAll('[required]');
        
        requiredFields.forEach(field => {
            if (!field.value.trim()) {
                field.classList.add('is-invalid');
                isValid = false;
            } else {
                field.classList.remove('is-invalid');
            }
        });
        
        return isValid;
    }

    getIniciais(nome) {
        return nome.split(' ')
            .map(palavra => palavra.charAt(0))
            .slice(0, 2)
            .join('')
            .toUpperCase();
    }

    getStatusCliente(saldoDevedor) {
        if (saldoDevedor === 0) return 'Quitado';
        if (saldoDevedor > 0) return 'Pendente';
        return 'Parcial';
    }

    getStatusClass(status) {
        switch (status) {
            case 'Quitado': return 'badge-paid';
            case 'Parcial': return 'badge-partial';
            default: return 'badge-pending';
        }
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
    // Aguardar o carregamento do app.js e componentes
    setTimeout(() => {
        new ClientesManager();
    }, 100);
});