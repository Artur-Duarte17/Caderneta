// ===== VENDAS.JS - Gerenciamento de Vendas =====

class VendasManager {
  constructor() {
    this.vendas = [];
    this.clientes = [];
    this.vendasFiltradas = [];
    this.init();
  }

  async init() {
    await this.carregarDados();
    this.setupEventListeners();
    this.renderizarVendas();
  }

  async carregarDados() {
    try {
      const [vendasData, clientesData] = await Promise.all([
        apiService.getVendas(),
        apiService.getClientes(),
      ]);

      this.vendas = vendasData;
      this.clientes = clientesData;
      this.vendasFiltradas = [...this.vendas];
    } catch (error) {
      console.error("Erro ao carregar dados:", error);
      showToast("Erro ao carregar dados: " + error.message, "error");
      this.vendas = [];
      this.clientes = [];
      this.vendasFiltradas = [];
    }
  }

  setupEventListeners() {
    // Busca
    const searchInput = document.getElementById("clienteFilter");
    if (searchInput) {
      searchInput.addEventListener("input", (e) =>
        this.filtrarVendas(e.target.value)
      );
    }

    // Filtros
    const statusFilter = document.getElementById("statusFilter");
    const periodoFilter = document.getElementById("periodoFilter");

    if (statusFilter) {
      statusFilter.addEventListener("change", () => this.aplicarFiltros());
    }

    if (periodoFilter) {
      periodoFilter.addEventListener("change", () => this.aplicarFiltros());
    }

    // Formulário nova venda
    const novaVendaForm = document.querySelector("#newSaleOffcanvas form");
    if (novaVendaForm) {
      novaVendaForm.addEventListener("submit", (e) => this.criarVenda(e));
    }

    // Botão adicionar item
    const addItemBtn = document.getElementById("addItemBtn");
    if (addItemBtn) {
      addItemBtn.addEventListener("click", () => this.adicionarItem());
    }

    // Botão salvar edição
    const saveSaleBtn = document.getElementById("saveSaleBtn");
    if (saveSaleBtn) {
      saveSaleBtn.addEventListener("click", () => this.salvarEdicaoVenda());
    }

    // Carregar clientes no select
    this.carregarClientesSelect();
  }

  carregarClientesSelect() {
    const clienteSelect = document.getElementById("clienteSelect");
    const editClientSelect = document.getElementById("editClientSelect");

    const options =
      '<option value="">Selecione um cliente</option>' +
      this.clientes
        .map(
          (cliente) =>
            `<option value="${cliente.id}">${cliente.nome} - ${
              cliente.telefone || "Sem telefone"
            }</option>`
        )
        .join("");

    if (clienteSelect) clienteSelect.innerHTML = options;
    if (editClientSelect) editClientSelect.innerHTML = options;
  }

  filtrarVendas(termo) {
    if (!termo.trim()) {
      this.vendasFiltradas = [...this.vendas];
    } else {
      const termoLower = termo.toLowerCase();
      this.vendasFiltradas = this.vendas.filter((venda) => {
        const cliente = this.clientes.find((c) => c.id === venda.clienteId);
        return (
          cliente?.nome.toLowerCase().includes(termoLower) ||
          venda.id.toString().includes(termo)
        );
      });
    }
    this.aplicarFiltros();
  }

  aplicarFiltros() {
    let vendas = [...this.vendasFiltradas];

    // Filtro por status
    const statusFilter = document.getElementById("statusFilter");
    if (statusFilter && statusFilter.value) {
      vendas = vendas.filter((venda) => venda.status === statusFilter.value);
    }

    // Filtro por período
    const periodoFilter = document.getElementById("periodoFilter");
    if (periodoFilter && periodoFilter.value) {
      const hoje = new Date();
      const dataLimite = new Date();

      switch (periodoFilter.value) {
        case "hoje":
          dataLimite.setHours(0, 0, 0, 0);
          break;
        case "semana":
          dataLimite.setDate(hoje.getDate() - 7);
          break;
        case "mes":
          dataLimite.setMonth(hoje.getMonth() - 1);
          break;
      }

      if (periodoFilter.value !== "todos") {
        vendas = vendas.filter(
          (venda) => new Date(venda.dataHora) >= dataLimite
        );
      }
    }

    this.renderizarVendas(vendas);
  }

  renderizarVendas(vendas = this.vendasFiltradas) {
    const container = document.querySelector(".row.g-4");
    if (!container) return;

    if (vendas.length === 0) {
      container.innerHTML = `
                <div class="col-12 text-center py-5">
                    <div class="text-muted">
                        <span class="material-icons" style="font-size: 48px;">receipt_long</span>
                        <p class="mt-2">Nenhuma venda encontrada</p>
                    </div>
                </div>
            `;
      return;
    }

    container.innerHTML = vendas
      .map((venda) => this.criarCardVenda(venda))
      .join("");
    this.setupCardEventListeners();
  }

  criarCardVenda(venda) {
    const cliente = this.clientes.find((c) => c.id === venda.clienteId);
    const nomeCliente = cliente ? cliente.nome : "Cliente não encontrado";
    const statusClass = this.getStatusClass(venda.status);
    const statusText = this.getStatusText(venda.status);

    return `
            <div class="col-md-6 col-lg-4 fade-in">
                <div class="card border-0 bg-white p-3 h-100">
                    <div class="d-flex justify-content-between align-items-start mb-3">
                        <div>
                            <h6 class="mb-1">Venda #${venda.id}</h6>
                            <small class="text-muted">${this.formatarData(
                              venda.dataHora
                            )}</small>
                        </div>
                        <span class="badge ${statusClass}">${statusText}</span>
                    </div>
                    
                    <div class="mb-3">
                        <div class="d-flex align-items-center mb-2">
                            <span class="material-icons me-2 text-muted" style="font-size: 18px;">person</span>
                            <span class="fw-medium">${nomeCliente}</span>
                        </div>
                        <div class="d-flex align-items-center">
                            <span class="material-icons me-2 text-muted" style="font-size: 18px;">attach_money</span>
                            <span class="fw-bold text-primary">R$ ${this.formatarMoeda(
                              venda.valorTotal
                            )}</span>
                        </div>
                    </div>
                    
                    <div class="d-flex gap-2 mt-auto">
                        <button class="btn btn-sm btn-outline-primary flex-fill view-sale-btn" 
                                data-sale-id="${venda.id}">
                            <span class="material-icons me-1" style="font-size: 16px;">visibility</span>
                            Detalhes
                        </button>
                        <button class="btn btn-sm btn-outline-secondary flex-fill edit-sale-btn" 
                                data-sale-id="${venda.id}">
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
    document.querySelectorAll(".view-sale-btn").forEach((btn) => {
      btn.addEventListener("click", (e) => {
        try {
          const button = e.target.closest(".view-sale-btn");
          if (button && button.dataset.saleId) {
            this.visualizarVenda(button.dataset.saleId);
          }
        } catch (error) {
          console.error("Erro ao processar clique de visualização:", error);
          showToast("Erro ao processar ação", "error");
        }
      });
    });

    // Botões de editar
    document.querySelectorAll(".edit-sale-btn").forEach((btn) => {
      btn.addEventListener("click", (e) => {
        try {
          const button = e.target.closest(".edit-sale-btn");
          if (button && button.dataset.saleId) {
            this.editarVenda(button.dataset.saleId);
          }
        } catch (error) {
          console.error("Erro ao processar clique de edição:", error);
          showToast("Erro ao processar ação", "error");
        }
      });
    });
  }

  async visualizarVenda(vendaId) {
    try {
      const venda = await apiService.getVendaById(vendaId);
      this.preencherModalVisualizacao(venda);

      const modal = new bootstrap.Modal(
        document.getElementById("viewSaleModal")
      );
      modal.show();
    } catch (error) {
      console.error("Erro ao carregar venda:", error);
      showToast("Erro ao carregar dados da venda", "error");
    }
  }

  preencherModalVisualizacao(venda) {
    const cliente = this.clientes.find((c) => c.id === venda.clienteId);

    document.getElementById("viewSaleId").textContent = `#${venda.id}`;
    document.getElementById("viewSaleDate").textContent = this.formatarData(
      venda.dataHora
    );
    document.getElementById("viewSaleClient").textContent = cliente
      ? cliente.nome
      : "Cliente não encontrado";
    document.getElementById(
      "viewSaleTotal"
    ).textContent = `R$ ${this.formatarMoeda(venda.valorTotal || 0)}`;

    const statusBadge = document.getElementById("viewSaleStatus");
    statusBadge.textContent = this.getStatusText(venda.status);
    statusBadge.className = `badge ${this.getStatusClass(venda.status)}`;

    // Renderizar itens
    const itemsContainer = document.getElementById("viewSaleItems");
    if (venda.itens && venda.itens.length > 0) {
      itemsContainer.innerHTML = venda.itens
        .map(
          (item) => `
        <tr>
            <td>${this.escaparHTML(
              item.descricaoProduto || "Produto não informado"
            )}</td>
            <td class="text-center">${item.quantidade || 0}</td>
            <td class="text-end">R$ ${this.formatarMoeda(
              item.precoUnitario || 0
            )}</td>
            <td class="text-end fw-bold">R$ ${this.formatarMoeda(
              item.subtotal || item.quantidade * item.precoUnitario || 0
            )}</td>
        </tr>
    `
        )
        .join("");
    } else {
      itemsContainer.innerHTML =
        '<tr><td colspan="4" class="text-center text-muted">Nenhum item encontrado</td></tr>';
    }
  }

  async editarVenda(vendaId) {
    try {
      console.log("Carregando venda para edição:", vendaId);
      const venda = await apiService.getVendaById(vendaId);
      console.log("Dados da venda carregados:", venda);

      this.preencherFormularioEdicao(venda);

      const modal = new bootstrap.Modal(
        document.getElementById("editSaleModal")
      );
      modal.show();
    } catch (error) {
      console.error("Erro ao carregar venda para edição:", error);
      showToast("Erro ao carregar dados da venda", "error");
    }
  }

  preencherFormularioEdicao(venda) {
    console.log("Preenchendo formulário com:", venda);

    document.getElementById("editSaleId").value = venda.id;
    document.getElementById("editClientSelect").value = venda.clienteId;
    document.getElementById("editSaleDate").value = venda.dataHora
      ? venda.dataHora.split("T")[0]
      : "";
    document.getElementById("editSaleValue").value = venda.valorTotal || 0;

    // Preencher descrição com os itens
    if (venda.itens && venda.itens.length > 0) {
      const descricao = venda.itens
        .map(
          (item) =>
            `${item.descricaoProduto || "Produto"} (${
              item.quantidade || 1
            }x R$ ${this.formatarMoeda(item.precoUnitario || 0)})`
        )
        .join(", ");
      document.getElementById("editSaleDescription").value = descricao;
    } else {
      document.getElementById("editSaleDescription").value = "";
    }

    console.log(
      "Formulário preenchido - Cliente:",
      venda.clienteId,
      "Valor:",
      venda.valorTotal
    );
  }

  async salvarEdicaoVenda() {
    const clienteId = document.getElementById("editClientSelect").value;
    const valorTotal = document.getElementById("editSaleValue").value;
    const dataVenda = document.getElementById("editSaleDate").value;

    if (!clienteId) {
      showToast("Por favor, selecione um cliente", "error");
      return;
    }

    if (!valorTotal || parseFloat(valorTotal) <= 0) {
      showToast("Por favor, informe um valor válido", "error");
      return;
    }

    const vendaId = document.getElementById("editSaleId").value;

    const dadosAtualizados = {
      clienteId: parseInt(clienteId),
      valorTotal: parseFloat(valorTotal),
      funcionarioId: 1,
    };

    // Adicionar data se fornecida
    if (dataVenda) {
      dadosAtualizados.dataHora = dataVenda + "T00:00:00";
    }

    console.log("Atualizando venda:", vendaId, "com dados:", dadosAtualizados);

    try {
      const resultado = await apiService.updateVenda(vendaId, dadosAtualizados);
      
      showToast("Venda atualizada com sucesso!", "success");
      
      const modal = bootstrap.Modal.getInstance(document.getElementById("editSaleModal"));
      if (modal) modal.hide();
      
      await this.carregarDados();
      this.renderizarVendas();
    } catch (error) {
      console.error("Erro ao atualizar venda:", error);
      showToast("Erro: " + error.message, "error");
    }
  }

  async criarVenda(event) {
    event.preventDefault();

    const form = event.target;
    if (!this.validarFormularioVenda(form)) return;

    const clienteId = document.getElementById("clienteSelect").value;
    const observacoes = document.getElementById("observacoes").value;

    // Coletar itens
    const itens = this.coletarItens();
    if (itens.length === 0) {
      showToast("Adicione pelo menos um item à venda", "error");
      return;
    }

    const dadosVenda = {
      clienteId: parseInt(clienteId),
      funcionarioId: 1, // ID padrão do funcionário
      itens: itens,
    };

    try {
      await apiService.createVenda(dadosVenda);
      showToast("Venda criada com sucesso!", "success");

      const offcanvas = bootstrap.Offcanvas.getInstance(
        document.getElementById("newSaleOffcanvas")
      );
      offcanvas.hide();

      form.reset();
      this.limparItens();

      await this.carregarDados();
      this.renderizarVendas();
    } catch (error) {
      console.error("Erro ao criar venda:", error);
      showToast("Erro ao criar venda: " + error.message, "error");
    }
  }

  adicionarItem() {
    const itemsContainer = document.getElementById("itemsContainer");
    const itemIndex = itemsContainer.children.length;

    const itemHtml = `
            <div class="item-row border rounded p-3 mb-3">
                <div class="d-flex justify-content-between align-items-center mb-2">
                    <h6 class="mb-0">Item ${itemIndex + 1}</h6>
                    <button type="button" class="btn btn-sm btn-outline-danger remove-item-btn">
                        <span class="material-icons" style="font-size: 16px;">delete</span>
                    </button>
                </div>
                <div class="row g-3">
                    <div class="col-md-6">
                        <label class="form-label">Descrição *</label>
                        <input type="text" class="form-control item-descricao" required>
                    </div>
                    <div class="col-md-2">
                        <label class="form-label">Qtd *</label>
                        <input type="number" class="form-control item-quantidade" min="1" value="1" required>
                    </div>
                    <div class="col-md-4">
                        <label class="form-label">Valor Unitário *</label>
                        <div class="input-group">
                            <span class="input-group-text">R$</span>
                            <input type="number" class="form-control item-valor" step="0.01" min="0" required>
                        </div>
                    </div>
                </div>
            </div>
        `;

    itemsContainer.insertAdjacentHTML("beforeend", itemHtml);

    // Adicionar event listener para remover item
    const removeBtn =
      itemsContainer.lastElementChild.querySelector(".remove-item-btn");
    removeBtn.addEventListener("click", (e) => {
      e.target.closest(".item-row").remove();
      this.atualizarNumeracaoItens();
    });
  }

  atualizarNumeracaoItens() {
    const items = document.querySelectorAll(".item-row");
    items.forEach((item, index) => {
      item.querySelector("h6").textContent = `Item ${index + 1}`;
    });
  }

  coletarItens() {
    const items = [];
    const itemRows = document.querySelectorAll(".item-row");

    itemRows.forEach((row) => {
      const descricao = row.querySelector(".item-descricao").value;
      const quantidade = parseInt(row.querySelector(".item-quantidade").value);
      const valorUnitario = parseFloat(row.querySelector(".item-valor").value);

      if (descricao && quantidade && valorUnitario) {
        items.push({
          descricaoProduto: descricao,
          quantidade,
          precoUnitario: valorUnitario,
        });
      }
    });

    return items;
  }

  limparItens() {
    document.getElementById("itemsContainer").innerHTML = "";
  }

  validarFormularioVenda(form) {
    let isValid = true;
    const requiredFields = form.querySelectorAll("[required]");

    requiredFields.forEach((field) => {
      if (!field.value.trim()) {
        field.classList.add("is-invalid");
        isValid = false;
      } else {
        field.classList.remove("is-invalid");
      }
    });

    return isValid;
  }

  getStatusClass(status) {
    switch (status) {
      case "PAGO":
        return "badge-success";
      case "PENDENTE":
        return "badge-warning";
      case "CANCELADO":
        return "badge-danger";
      default:
        return "badge-secondary";
    }
  }

  getStatusText(status) {
    switch (status) {
      case "PAGO":
        return "Pago";
      case "PENDENTE":
        return "Pendente";
      case "CANCELADO":
        return "Cancelado";
      default:
        return status;
    }
  }

  formatarData(data) {
    return new Date(data).toLocaleDateString("pt-BR");
  }

  formatarMoeda(valor) {
    return new Intl.NumberFormat("pt-BR", {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    }).format(valor);
  }

  escaparHTML(texto) {
    const div = document.createElement("div");
    div.textContent = texto;
    return div.innerHTML;
  }
}

// Inicializar quando o DOM estiver carregado
document.addEventListener("DOMContentLoaded", function () {
  // Aguardar o carregamento do app.js e componentes
  setTimeout(() => {
    new VendasManager();
  }, 100);
});
