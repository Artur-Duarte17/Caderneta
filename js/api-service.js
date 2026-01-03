// ===== API SERVICE - Integração com Backend =====

class ApiService {
  constructor() {
    this.baseURL = "http://localhost:8080/api";
    this.headers = {
      "Content-Type": "application/json",
      Accept: "application/json",
    };
  }

  // Método genérico para fazer requisições
  async request(endpoint, options = {}) {
    const url = `${this.baseURL}${endpoint}`;
    const config = {
      headers: this.headers,
      ...options,
    };

    try {
      const response = await fetch(url, config);

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        throw new Error(
          errorData.message || `HTTP ${response.status}: ${response.statusText}`
        );
      }

      // Se não há conteúdo (204), retorna null
      if (response.status === 204) {
        return null;
      }

      return await response.json();
    } catch (error) {
      console.error(`Erro na requisição para ${endpoint}:`, error);
      throw error;
    }
  }

  // ===== CLIENTES =====
  async getClientes() {
    return await this.request("/clientes");
  }

  async getClienteById(id) {
    return await this.request(`/clientes/${id}`);
  }

  async createCliente(clienteData) {
    return await this.request("/clientes", {
      method: "POST",
      body: JSON.stringify(clienteData),
    });
  }

  async updateCliente(id, clienteData) {
    return await this.request(`/clientes/${id}`, {
      method: "PUT",
      body: JSON.stringify(clienteData),
    });
  }

  async deleteCliente(id) {
    return await this.request(`/clientes/${id}`, {
      method: "DELETE",
    });
  }

  async updateLimiteCredito(id, limite) {
    return await this.request(`/clientes/${id}/limite-credito`, {
      method: "PATCH",
      body: JSON.stringify({ limiteCredito: limite }),
    });
  }

  async updatePrazoPagamento(id, prazo) {
    return await this.request(`/clientes/${id}/prazo-pagamento`, {
      method: "PATCH",
      body: JSON.stringify({ prazoPagamento: prazo }),
    });
  }

  // ===== VENDAS =====
  async getVendas() {
    return await this.request("/vendas");
  }

  async getVendaById(id) {
    return await this.request(`/vendas/${id}`);
  }

  async createVenda(vendaData) {
    return await this.request("/vendas", {
      method: "POST",
      body: JSON.stringify(vendaData),
    });
  }

  async updateVenda(id, vendaData) {
    return await this.request(`/vendas/${id}`, {
      method: "PUT",
      body: JSON.stringify(vendaData),
    });
  }

  async deleteVenda(id) {
    return await this.request(`/vendas/${id}`, {
      method: "DELETE",
    });
  }

  // ===== DÍVIDAS =====
  async getDividas() {
    return await this.request("/dividas");
  }

  async getDividaById(id) {
    return await this.request(`/dividas/${id}`);
  }

  async getDividasByCliente(clienteId) {
    return await this.request(`/dividas/cliente/${clienteId}`);
  }

  async createPagamento(dividaId, pagamentoData) {
    return await this.request(`/dividas/${dividaId}/pagamentos`, {
      method: "POST",
      body: JSON.stringify(pagamentoData),
    });
  }

  async registrarPagamento(dividaId, valorPago, metodoPagamento) {
    const pagamentoData = {
      valorPago: parseFloat(valorPago),
      metodoPagamento: metodoPagamento,
    };
    return await this.createPagamento(dividaId, pagamentoData);
  }

  // ===== FUNCIONÁRIOS =====
  async getFuncionarios() {
    return await this.request("/funcionarios");
  }

  async getFuncionarioById(id) {
    return await this.request(`/funcionarios/${id}`);
  }

  async createFuncionario(funcionarioData) {
    return await this.request("/funcionarios", {
      method: "POST",
      body: JSON.stringify(funcionarioData),
    });
  }

  async updateFuncionario(id, funcionarioData) {
    return await this.request(`/funcionarios/${id}`, {
      method: "PUT",
      body: JSON.stringify(funcionarioData),
    });
  }

  async deleteFuncionario(id) {
    return await this.request(`/funcionarios/${id}`, {
      method: "DELETE",
    });
  }

  // ===== FIADORES =====
  async getFiadores() {
    return await this.request("/fiadores");
  }

  async createFiador(fiadorData) {
    return await this.request("/fiadores", {
      method: "POST",
      body: JSON.stringify(fiadorData),
    });
  }

  // ===== NOTIFICAÇÕES =====
  async getNotificacoes() {
    // Tenta o endpoint geral primeiro; se não existir (backend pode expor apenas /cliente/{id}), tenta fallback
    try {
      return await this.request("/notificacoes");
    } catch (err) {
      // Se falhar (404 ou outro), tenta buscar notificações de um cliente padrão (desenvolvimento).
      // Ideal: adaptar para usar o cliente atual logado. Aqui usamos '1' como fallback.
      try {
        return await this.request("/notificacoes/cliente/1");
      } catch (err2) {
        // Re-throw o erro original para tratamento pelo chamador
        throw err;
      }
    }
  }

  async createNotificacao(notificacaoData) {
    return await this.request("/notificacoes", {
      method: "POST",
      body: JSON.stringify(notificacaoData),
    });
  }

  async marcarNotificacaoComoLida(id) {
    return await this.request(`/notificacoes/${id}/marcar-lida`, {
      method: "PATCH",
    });
  }

  // ===== RELATÓRIOS =====
  async getRelatorioVendas(dataInicio, dataFim) {
    const params = new URLSearchParams({ dataInicio, dataFim });
    return await this.request(
      "/relatorios/vendas-a-prazo?" + params.toString()
    );
  }

  async getRelatorioDividas(dataInicio, dataFim, status = null) {
    const params = new URLSearchParams({ dataInicio, dataFim });
    if (status) params.append("status", status);
    return await this.request(
      "/relatorios/debitos-pendentes?" + params.toString()
    );
  }

  // ===== PROPRIETÁRIO =====
  async getProprietario() {
    return await this.request("/proprietario");
  }

  async updateProprietario(proprietarioData) {
    return await this.request("/proprietario", {
      method: "PUT",
      body: JSON.stringify(proprietarioData),
    });
  }
}

// Instância global do serviço
const apiService = new ApiService();

// Exportar para uso global
window.apiService = apiService;
