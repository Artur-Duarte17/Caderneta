// ===== PAGAMENTOS.JS - Gestão de Pagamentos =====

class PagamentosManager {
  constructor() {
    this.dividas = [];
    this.dividasFiltradas = [];
    this.dividaSelecionada = null;
    this.pagarDividaModal = null;
    this.init();
  }

  async init() {
    await this.carregarDados();
    this.configurarEventListeners();
    this.renderizarDividas();
    this.atualizarEstatisticas();
    this.pagarDividaModal = new bootstrap.Modal(
      document.getElementById("pagarDividaModal")
    );
  }

  configurarEventListeners() {
    // Filtros
    document.getElementById("statusFilter").addEventListener("change", () => {
      this.aplicarFiltros();
    });
    document.getElementById("clienteFilter").addEventListener("input", () => {
      this.aplicarFiltros();
    });
    document.getElementById("periodoFilter").addEventListener("change", () => {
      this.aplicarFiltros();
    });
    document
      .getElementById("limparFiltrosBtn")
      .addEventListener("click", () => {
        this.limparFiltros();
      });

    // Modal Pagamento
    document
      .getElementById("pagarDividaForm")
      .addEventListener("submit", (e) => {
        e.preventDefault();
        this.registrarPagamento();
      });

    // Validação do valor de pagamento
    document.getElementById("valorPago").addEventListener("input", (e) => {
      this.validarValorPagamento();
    });
  }

  async carregarDados() {
    try {
      const [dividas, clientes] = await Promise.all([
        apiService.getDividas(),
        apiService.getClientes(),
      ]);

      this.dividas = (dividas || []).map((divida) => {
        const cliente = (clientes || []).find((c) => c.id === divida.clienteId);
        return {
          ...divida,
          clienteNome: cliente ? cliente.nome : "Desconhecido",
          statusDisplay: this.mapStatusDividaToDisplay(divida.statusDivida),
        };
      });

      this.dividasFiltradas = [...this.dividas];
    } catch (error) {
      console.error("Erro ao carregar dívidas:", error);
      showToast("Erro ao carregar dívidas", "error");
    }
  }

  mapStatusDividaToDisplay(statusDivida) {
    const mapa = {
      ABERTA: "PENDENTE",
      PAGA_TOTALMENTE: "PAGO",
      PAGA_PARCIALMENTE: "PARCIAL",
      CANCELADA: "CANCELADO",
      VENCIDA: "VENCIDA",
    };
    return mapa[statusDivida] || statusDivida;
  }

  aplicarFiltros() {
    const status = document.getElementById("statusFilter").value;
    const cliente = document
      .getElementById("clienteFilter")
      .value.toLowerCase();
    const periodo =
      parseInt(document.getElementById("periodoFilter").value) || null;

    this.dividasFiltradas = this.dividas.filter((divida) => {
      // Filtro de status
      if (
        status &&
        this.mapStatusDividaToDisplay(divida.statusDivida) !== status
      ) {
        return false;
      }

      // Filtro de cliente
      if (cliente && !divida.clienteNome.toLowerCase().includes(cliente)) {
        return false;
      }

      // Filtro de período
      if (periodo) {
        const dataEmissao = new Date(divida.dataEmissao);
        const agora = new Date();
        const dias = Math.floor((agora - dataEmissao) / (1000 * 60 * 60 * 24));
        if (dias > periodo) {
          return false;
        }
      }

      return true;
    });

    this.renderizarDividas();
    this.atualizarEstatisticas();
  }

  limparFiltros() {
    document.getElementById("statusFilter").value = "";
    document.getElementById("clienteFilter").value = "";
    document.getElementById("periodoFilter").value = "";
    this.dividasFiltradas = [...this.dividas];
    this.renderizarDividas();
    this.atualizarEstatisticas();
  }

  renderizarDividas() {
    const container = document.getElementById("dividasContainer");
    const emptyState = document.getElementById("emptyState");

    if (this.dividasFiltradas.length === 0) {
      container.innerHTML = "";
      emptyState.style.display = "block";
      return;
    }

    emptyState.style.display = "none";
    container.innerHTML = this.dividasFiltradas
      .map((divida) => this.criarCardDivida(divida))
      .join("");

    // Adicionar listeners aos botões
    document.querySelectorAll(".btn-pagar-divida").forEach((btn) => {
      btn.addEventListener("click", () => {
        const dividaId = parseInt(btn.dataset.dividaId);
        const divida = this.dividasFiltradas.find((d) => d.id === dividaId);
        this.abrirModalPagamento(divida);
      });
    });
  }

  criarCardDivida(divida) {
    const statusDisplay = this.mapStatusDividaToDisplay(divida.statusDivida);
    const statusClass =
      statusDisplay === "PENDENTE" || statusDisplay === "PARCIAL"
        ? "warning"
        : "success";
    const statusIcon =
      this.mapStatusDividaToDisplay(divida.statusDivida) === "PENDENTE"
        ? "pending_actions"
        : "check_circle";

    const dataVencimento = new Date(divida.dataVencimento);
    const agora = new Date();
    const estaVencido = dataVencimento < agora;
    const vencidoClass = estaVencido ? "text-danger" : "";
    const vencidoIcon = estaVencido ? "error" : "calendar_today";

    return `
      <div class="col-md-6 col-lg-4 mb-3">
        <div class="card border-0 bg-white h-100 shadow-sm hover-shadow transition">
          <div class="card-body">
            <!-- Header -->
            <div class="d-flex justify-content-between align-items-start mb-3">
              <div>
                <h6 class="fw-bold mb-1">Venda #${divida.vendaId}</h6>
                <p class="text-muted small mb-0">${divida.clienteNome}</p>
              </div>
              <span class="badge bg-${statusClass} d-flex align-items-center gap-1">
                <span class="material-icons" style="font-size: 14px;">${statusIcon}</span>
                ${this.mapStatusDividaToDisplay(divida.statusDivida)}
              </span>
            </div>

            <!-- Valores -->
            <div class="bg-light rounded p-3 mb-3">
              <div class="row g-3">
                <div class="col-6">
                  <small class="text-muted d-block">Valor Original</small>
                  <strong class="text-dark">R$ ${this.formatarMoeda(
                    divida.valorOriginal
                  )}</strong>
                </div>
                <div class="col-6">
                  <small class="text-muted d-block">Valor Pendente</small>
                  <strong class="text-danger">R$ ${this.formatarMoeda(
                    divida.valorPendente
                  )}</strong>
                </div>
              </div>
            </div>

            <!-- Datas -->
            <div class="row g-2 mb-3 text-small">
              <div class="col-6">
                <small class="text-muted d-block">Emissão</small>
                <span>${this.formatarData(divida.dataEmissao)}</span>
              </div>
              <div class="col-6">
                <small class="text-muted d-block">Vencimento</small>
                <span class="${vencidoClass}">
                  <span class="material-icons align-text-bottom" style="font-size: 16px;">${vencidoIcon}</span>
                  ${this.formatarData(divida.dataVencimento)}
                </span>
              </div>
            </div>

            <!-- Histórico de Pagamentos -->
            ${this.renderizarPagamentos(divida)}

            <!-- Botão Pagar -->
              ${
                statusDisplay === "PENDENTE" || statusDisplay === "PARCIAL"
                  ? `
                <button class="btn btn-primary w-100 btn-pagar-divida" data-divida-id="${divida.id}">
                  <span class="material-icons me-2" style="font-size: 18px;">payment</span>
                  Registrar Pagamento
                </button>
              `
                  : `
                <button class="btn btn-success w-100" disabled>
                  <span class="material-icons me-2" style="font-size: 18px;">check_circle</span>
                  Dívida Paga
                </button>
              `
              }
          </div>
        </div>
      </div>
    `;
  }

  renderizarPagamentos(divida) {
    if (!divida.pagamentos || divida.pagamentos.length === 0) {
      return "";
    }

    const pagamentosHtml = divida.pagamentos
      .map(
        (pag) => `
      <div class="small mb-2">
        <div class="d-flex justify-content-between">
          <span class="text-success">
            <span class="material-icons align-text-bottom" style="font-size: 16px;">check_circle</span>
            R$ ${this.formatarMoeda(pag.valorPago)}
          </span>
          <span class="text-muted">${this.formatarData(pag.dataPagamento)} (${
          pag.metodoPagamento
        })</span>
        </div>
      </div>
    `
      )
      .join("");

    return `
      <div class="border-top pt-3 mb-3">
        <small class="text-muted d-block fw-semibold mb-2">Pagamentos Realizados</small>
        ${pagamentosHtml}
      </div>
    `;
  }

  abrirModalPagamento(divida) {
    this.dividaSelecionada = divida;

    // Preencher informações do modal
    document.getElementById(
      "modalDividaInfo"
    ).textContent = `Venda #${divida.vendaId} - ${divida.clienteNome}`;
    document.getElementById(
      "modalValorPendente"
    ).textContent = `R$ ${this.formatarMoeda(divida.valorPendente)}`;

    // Limpar e resetar formulário
    document.getElementById("pagarDividaForm").reset();
    document.getElementById("valorPago").max = divida.valorPendente;
    document.getElementById("avisoValor").textContent = "";
    document.getElementById("alertaPagamentoTotal").style.display = "none";

    this.pagarDividaModal.show();
  }

  validarValorPagamento() {
    const valorInput = parseFloat(document.getElementById("valorPago").value);
    const valorPendente = this.dividaSelecionada.valorPendente;
    const avisoEl = document.getElementById("avisoValor");
    const alertaEl = document.getElementById("alertaPagamentoTotal");

    if (!valorInput || valorInput <= 0) {
      avisoEl.textContent = "";
      alertaEl.style.display = "none";
      return;
    }

    if (valorInput > valorPendente) {
      avisoEl.textContent = "⚠️ Valor superior ao pendente";
      avisoEl.style.color = "#dc3545";
      alertaEl.style.display = "none";
    } else if (Math.abs(valorInput - valorPendente) < 0.01) {
      avisoEl.textContent = "";
      alertaEl.style.display = "block";
    } else {
      avisoEl.textContent = `✓ Pagamento parcial. Restará R$ ${this.formatarMoeda(
        valorPendente - valorInput
      )}`;
      avisoEl.style.color = "#28a745";
      alertaEl.style.display = "none";
    }
  }

  async registrarPagamento() {
    const valorPago = parseFloat(document.getElementById("valorPago").value);
    const metodoPagamento = document.getElementById("metodoPagamento").value;

    if (!this.dividaSelecionada || !valorPago || valorPago <= 0) {
      showToast("Dados inválidos", "error");
      return;
    }

    if (valorPago > this.dividaSelecionada.valorPendente) {
      showToast("Valor não pode ser maior que o pendente", "error");
      return;
    }

    const btnConfirmar = document.getElementById("confirmarPagamentoBtn");
    const textoBtnOriginal = btnConfirmar.innerHTML;
    btnConfirmar.disabled = true;
    btnConfirmar.innerHTML =
      '<span class="spinner-border spinner-border-sm me-2"></span>Processando...';

    try {
      await apiService.registrarPagamento(
        this.dividaSelecionada.id,
        valorPago,
        metodoPagamento
      );

      showToast("Pagamento registrado com sucesso!", "success");
      this.pagarDividaModal.hide();

      // Recarregar dados
      await this.carregarDados();
      this.renderizarDividas();
      this.atualizarEstatisticas();

      // Emitir evento para dashboard atualizar
      window.dispatchEvent(new Event("pagamentoDividaRealizado"));
    } catch (error) {
      console.error("Erro ao registrar pagamento:", error);
      showToast("Erro ao registrar pagamento: " + error.message, "error");
    } finally {
      btnConfirmar.disabled = false;
      btnConfirmar.innerHTML = textoBtnOriginal;
    }
  }

  atualizarEstatisticas() {
    // Saldo Pendente (inclui parcialmente pagas)
    const saldoPendente = this.dividasFiltradas
      .filter((d) => {
        const s = this.mapStatusDividaToDisplay(d.statusDivida);
        return s === "PENDENTE" || s === "PARCIAL";
      })
      .reduce((total, d) => total + d.valorPendente, 0);

    document.getElementById("saldoPendenteVal").textContent =
      this.formatarMoeda(saldoPendente);
    document.getElementById("dividasPendentesCt").textContent =
      this.dividasFiltradas.filter((d) => {
        const s = this.mapStatusDividaToDisplay(d.statusDivida);
        return s === "PENDENTE" || s === "PARCIAL";
      }).length;

    // Pagamentos este Mês
    const inicioMes = new Date();
    inicioMes.setDate(1);
    inicioMes.setHours(0, 0, 0, 0);

    let pagamentosNoMes = 0;
    let contagemPagamentos = 0;

    this.dividasFiltradas.forEach((divida) => {
      if (divida.pagamentos) {
        divida.pagamentos.forEach((pag) => {
          const dataPag = new Date(pag.dataPagamento);
          if (dataPag >= inicioMes) {
            pagamentosNoMes += pag.valorPago;
            contagemPagamentos++;
          }
        });
      }
    });

    document.getElementById("pagamentosNoMesVal").textContent =
      this.formatarMoeda(pagamentosNoMes);
    document.getElementById("pagamentosNoMesCt").textContent =
      contagemPagamentos;

    // Dívidas Vencidas
    const agora = new Date();
    const vencidas = this.dividasFiltradas.filter((d) => {
      const s = this.mapStatusDividaToDisplay(d.statusDivida);
      return (
        new Date(d.dataVencimento) < agora &&
        (s === "PENDENTE" || s === "PARCIAL")
      );
    }).length;

    document.getElementById("vencidosVal").textContent = vencidas;
  }

  formatarMoeda(valor) {
    return parseFloat(valor).toLocaleString("pt-BR", {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    });
  }

  formatarData(data) {
    return new Date(data).toLocaleDateString("pt-BR");
  }
}
