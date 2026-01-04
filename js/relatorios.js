// ===== RELATORIOS.JS - Gerenciamento de Relatórios =====

class RelatoriosManager {
  constructor() {
    this.dadosVendas = [];
    this.dadosDividas = [];
    this.clientes = [];
    this.charts = {};
    this.relatorioVendas = null;
    this.relatorioDividas = null;
    this.init();
  }

  async init() {
    await this.carregarDados();
    this.setupEventListeners();
    this.renderizarRelatorios();
    this.updateCharts();
  }

  async carregarDados() {
    try {
      const [vendas, dividas, clientes] = await Promise.all([
        apiService.getVendas(),
        apiService.getDividas(),
        apiService.getClientes(),
      ]);

      this.dadosVendas = vendas || [];
      this.dadosDividas = dividas || [];
      this.clientes = clientes || [];

      console.log("Dados carregados:", {
        vendas: this.dadosVendas.length,
        dividas: this.dadosDividas.length,
        clientes: this.clientes.length,
      });
    } catch (error) {
      console.error("Erro ao carregar dados:", error);
      showToast("Erro ao carregar dados", "error");
    }
  }

  setupEventListeners() {
    const aplicarBtn = document.getElementById("applyFilterBtn");
    if (aplicarBtn) {
      aplicarBtn.addEventListener("click", () => this.aplicarFiltros());
    }

    const exportBtn = document.getElementById("exportTableCsvBtn");
    if (exportBtn) {
      exportBtn.addEventListener("click", () => {
        this.exportarCSV();
        showExportToast();
      });
    }

    const reportTypeSelect = document.getElementById("reportType");
    if (reportTypeSelect) {
      reportTypeSelect.addEventListener("change", () =>
        this.renderizarTabela()
      );
    }

    window.addEventListener("pagamentoDividaRealizado", () => {
      this.carregarDados().then(() => {
        this.renderizarRelatorios();
        this.updateCharts();
      });
    });
  }

  async aplicarFiltros() {
    const startDate = document.getElementById("startDate").value;
    const endDate = document.getElementById("endDate").value;

    if (!startDate || !endDate) {
      showToast("Por favor, selecione as datas de início e fim", "error");
      return;
    }

    try {
      const [relatorioVendas, relatorioDividas] = await Promise.all([
        apiService.getRelatorioVendas(startDate, endDate),
        apiService.getRelatorioDividas(startDate, endDate),
      ]);

      this.relatorioVendas = relatorioVendas;
      this.relatorioDividas = relatorioDividas;

      this.renderizarRelatorios();
      this.updateCharts();
      showToast("Relatórios atualizados com sucesso!", "success");
    } catch (error) {
      console.error("Erro ao aplicar filtros:", error);
      showToast("Erro ao aplicar filtros", "error");
    }
  }

  renderizarRelatorios() {
    this.renderizarResumo();
    this.renderizarTabela();
    this.atualizarCardsSemanal();
  }

  renderizarResumo() {
    const vendas = this.relatorioVendas?.vendas || this.dadosVendas;
    const dividas = this.relatorioDividas?.dividas || this.dadosDividas;

    const totalVendas = vendas.reduce(
      (sum, v) => sum + (parseFloat(v.valorTotal) || 0),
      0
    );
    const totalPago = dividas.reduce(
      (sum, d) => sum + (parseFloat(d.valorPago) || 0),
      0
    );
    const clientesAtivos = new Set(vendas.map((v) => v.clienteId)).size;
    const totalPendente = dividas.reduce((sum, d) => {
      return sum + (parseFloat(d.valorPendente) || 0);
    }, 0);

    document.querySelectorAll(
      ".grid .text-2xl"
    )[0].textContent = `R$ ${this.formatarMoeda(totalVendas)}`;
    document.querySelectorAll(
      ".grid .text-2xl"
    )[1].textContent = `R$ ${this.formatarMoeda(totalPago)}`;
    document.querySelectorAll(".grid .text-2xl")[2].textContent =
      clientesAtivos;
    document.querySelectorAll(
      ".grid .text-2xl"
    )[3].textContent = `R$ ${this.formatarMoeda(totalPendente)}`;
  }

  renderizarTabela() {
    const reportType = document.getElementById("reportType").value;
    const tbody = document.querySelector("tbody");
    if (!tbody) return;

    let dados = [];

    if (reportType === "sales") {
      dados = this.relatorioVendas?.vendas || this.dadosVendas;
      tbody.innerHTML = dados
        .slice(0, 10)
        .map((venda) => this.criarLinhaVenda(venda))
        .join("");
    } else if (reportType === "payments") {
      dados = this.relatorioDividas?.dividas || this.dadosDividas;
      tbody.innerHTML = dados
        .slice(0, 10)
        .map((divida) => this.criarLinhaPagamento(divida))
        .join("");
    } else if (reportType === "customers") {
      tbody.innerHTML = (this.clientes || [])
        .slice(0, 10)
        .map((cliente) => this.criarLinhaCliente(cliente))
        .join("");
    }
  }

  criarLinhaVenda(venda) {
    const cliente = this.clientes.find((c) => c.id === venda.clienteId);
    const statusClass = this.getStatusClass(venda.status);
    const statusText = this.getStatusText(venda.status);

    return `
      <tr>
        <td class="px-4 py-2">${this.formatarData(venda.dataHora)}</td>
        <td class="px-4 py-2">${cliente ? cliente.nome : "N/A"}</td>
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
    const cliente = this.clientes.find((c) => c.id === divida.clienteId);
    const totalPago = divida.pagamentos
      ? divida.pagamentos.reduce(
          (sum, p) => sum + (parseFloat(p.valorPago) || 0),
          0
        )
      : 0;

    return `
      <tr>
        <td class="px-4 py-2">${this.formatarData(divida.dataVencimento)}</td>
        <td class="px-4 py-2">${cliente ? cliente.nome : "N/A"}</td>
        <td class="px-4 py-2">R$ ${this.formatarMoeda(totalPago)}</td>
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
    const statusClass =
      saldoDevedor > 0
        ? "bg-red-100 text-red-800"
        : "bg-green-100 text-green-800";
    const statusText = saldoDevedor > 0 ? "Devendo" : "Quitado";

    return `
      <tr>
        <td class="px-4 py-2">${this.formatarData(
          cliente.dataCadastro || new Date()
        )}</td>
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

  updateCharts() {
    this.updateSalesChart();
    this.updatePaymentsChart();
    this.updateWeeklyCharts();
  }

  updateSalesChart() {
    const canvas = document.getElementById("chartSales");
    if (!canvas || typeof Chart === "undefined") {
      console.warn("Gráfico de vendas: canvas ou Chart.js não disponível");
      return;
    }

    const vendas = this.relatorioVendas?.vendas || this.dadosVendas;
    const map = {};

    vendas.forEach((v) => {
      const d = new Date(v.dataHora).toLocaleDateString("pt-BR");
      map[d] = (map[d] || 0) + (parseFloat(v.valorTotal) || 0);
    });

    const labels = Object.keys(map).sort(
      (a, b) =>
        new Date(a.split("/").reverse().join("-")) -
        new Date(b.split("/").reverse().join("-"))
    );
    const data = labels.map((l) => map[l]);

    try {
      if (this.charts.sales) {
        this.charts.sales.data.labels = labels;
        this.charts.sales.data.datasets[0].data = data;
        this.charts.sales.update();
      } else {
        const ctx = canvas.getContext("2d");
        this.charts.sales = new Chart(ctx, {
          type: "line",
          data: {
            labels: labels,
            datasets: [
              {
                label: "Vendas",
                data: data,
                borderColor: "#0A2463",
                backgroundColor: "rgba(10,36,99,0.08)",
                tension: 0.4,
                fill: true,
              },
            ],
          },
          options: { responsive: true, maintainAspectRatio: false },
        });
      }
    } catch (e) {
      console.error("Erro ao criar gráfico de vendas:", e);
    }
  }

  updatePaymentsChart() {
    const canvas = document.getElementById("chartPayments");
    if (!canvas || typeof Chart === "undefined") {
      console.warn("Gráfico de pagamentos: canvas ou Chart.js não disponível");
      return;
    }

    const dividas = this.relatorioDividas?.dividas || this.dadosDividas;
    const metodoMap = {
      DINHEIRO: 0,
      PIX: 0,
      CARTAO_CREDITO: 0,
      CARTAO_DEBITO: 0,
      TRANSFERENCIA_BANCARIA: 0,
      BOLETO_BANCARIO: 0,
    };

    dividas.forEach((d) => {
      if (d.pagamentos && Array.isArray(d.pagamentos)) {
        d.pagamentos.forEach((p) => {
          const metodo = p.metodoPagamento || "DINHEIRO";
          const valor = parseFloat(p.valorPago) || 0;
          if (metodoMap.hasOwnProperty(metodo)) {
            metodoMap[metodo] += valor;
          } else {
            metodoMap[metodo] = valor;
          }
        });
      }
    });

    const labels = Object.keys(metodoMap).filter((k) => metodoMap[k] > 0);
    const data = labels.map((l) => metodoMap[l]);
    const colors = [
      "rgba(10,36,99,0.7)",
      "rgba(62,146,204,0.7)",
      "rgba(216,49,91,0.7)",
      "rgba(255,193,7,0.7)",
      "rgba(40,167,69,0.7)",
      "rgba(108,117,125,0.7)",
    ];
    const bg = labels.map((_, i) => colors[i % colors.length]);

    try {
      if (this.charts.payments) {
        this.charts.payments.data.labels = labels;
        this.charts.payments.data.datasets[0].data = data;
        this.charts.payments.data.datasets[0].backgroundColor = bg;
        this.charts.payments.update();
      } else {
        const ctx = canvas.getContext("2d");
        this.charts.payments = new Chart(ctx, {
          type: "bar",
          data: {
            labels: labels,
            datasets: [
              {
                label: "Pagamentos",
                data: data,
                backgroundColor: bg,
              },
            ],
          },
          options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
              tooltip: {
                callbacks: {
                  label: function (context) {
                    return `R$ ${context.raw.toLocaleString("pt-BR")}`;
                  },
                },
              },
            },
            scales: {
              y: {
                beginAtZero: true,
                ticks: {
                  callback: function (value) {
                    return `R$ ${value.toLocaleString("pt-BR")}`;
                  },
                },
              },
            },
          },
        });
      }
    } catch (e) {
      console.error("Erro ao criar gráfico de pagamentos:", e);
    }
  }

  updateWeeklyCharts() {
    this.updateSalesWeeklyChart();
    this.updatePaymentsWeeklyChart();
    this.atualizarTabelaSemanal();
  }

  atualizarCardsSemanal() {
    const vendas = this.relatorioVendas?.vendas || this.dadosVendas;
    const dividas = this.relatorioDividas?.dividas || this.dadosDividas;

    const totalVendas = vendas.reduce(
      (sum, v) => sum + (parseFloat(v.valorTotal) || 0),
      0
    );

    const totalPagamentos = dividas.reduce(
      (sum, d) => sum + (parseFloat(d.valorPago) || 0),
      0
    );

    const clientesAtivos = new Set(vendas.map((v) => v.clienteId)).size;

    const totalPendente = dividas.reduce((sum, d) => {
      return sum + (parseFloat(d.valorPendente) || 0);
    }, 0);

    const inadimplencia =
      totalVendas > 0 ? ((totalPendente / totalVendas) * 100).toFixed(1) : 0;

    const allCards = document.querySelectorAll(
      ".bg-white.p-4.rounded-lg.shadow.border-l-4"
    );
    if (allCards.length >= 8) {
      allCards[4].querySelector(
        ".text-2xl"
      ).textContent = `R$ ${this.formatarMoeda(totalVendas)}`;
      allCards[5].querySelector(
        ".text-2xl"
      ).textContent = `R$ ${this.formatarMoeda(totalPagamentos)}`;
      allCards[6].querySelector(".text-2xl").textContent = clientesAtivos;
      allCards[7].querySelector(".text-2xl").textContent = `${inadimplencia}%`;
    }
  }

  atualizarTabelaSemanal() {
    try {
      const vendas = this.relatorioVendas?.vendas || this.dadosVendas;
      const dividas = this.relatorioDividas?.dividas || this.dadosDividas;

      const weekVendas = {
        "Semana 1": 0,
        "Semana 2": 0,
        "Semana 3": 0,
        "Semana 4": 0,
      };

      const weekPagamentos = {
        "Semana 1": 0,
        "Semana 2": 0,
        "Semana 3": 0,
        "Semana 4": 0,
      };

      vendas.forEach((v) => {
        const date = new Date(v.dataHora);
        const day = date.getDate();
        const week =
          day <= 7
            ? "Semana 1"
            : day <= 14
            ? "Semana 2"
            : day <= 21
            ? "Semana 3"
            : "Semana 4";
        weekVendas[week] += parseFloat(v.valorTotal) || 0;
      });

      dividas.forEach((d) => {
        const date = new Date(d.dataVencimento);
        const day = date.getDate();
        const week =
          day <= 7
            ? "Semana 1"
            : day <= 14
            ? "Semana 2"
            : day <= 21
            ? "Semana 3"
            : "Semana 4";
        weekPagamentos[week] += parseFloat(d.valorPendente) || 0;
      });

      const tbody = document.getElementById("weeklyDetailsBody");
      if (!tbody) return;

      const rows = Object.keys(weekVendas).map((week) => {
        const vendasVal = weekVendas[week] || 0;
        const pagosVal = weekPagamentos[week] || 0;
        const inad =
          vendasVal > 0 ? ((vendasVal - pagosVal) / vendasVal) * 100 : 0;

        return `
          <tr>
            <td class="px-4 py-2">${week}</td>
            <td class="px-4 py-2">${this.formatarMoeda(vendasVal)}</td>
            <td class="px-4 py-2">${this.formatarMoeda(pagosVal)}</td>
            <td class="px-4 py-2">${inad.toFixed(1)}</td>
          </tr>
        `;
      });

      tbody.innerHTML = rows.join("");
    } catch (e) {
      console.error("Erro ao atualizar tabela semanal:", e);
    }
  }

  updateSalesWeeklyChart() {
    const canvas = document.getElementById("salesChartWeekly");
    if (!canvas || typeof Chart === "undefined") {
      console.warn(
        "Gráfico semanal de vendas: canvas ou Chart.js não disponível"
      );
      return;
    }

    const vendas = this.relatorioVendas?.vendas || this.dadosVendas;
    const weekMap = {
      "Semana 1": 0,
      "Semana 2": 0,
      "Semana 3": 0,
      "Semana 4": 0,
    };

    vendas.forEach((v) => {
      const date = new Date(v.dataHora);
      const day = date.getDate();
      const week =
        day <= 7
          ? "Semana 1"
          : day <= 14
          ? "Semana 2"
          : day <= 21
          ? "Semana 3"
          : "Semana 4";
      weekMap[week] += parseFloat(v.valorTotal) || 0;
    });

    const labels = Object.keys(weekMap);
    const data = labels.map((l) => weekMap[l]);

    try {
      if (this.charts.salesWeekly) {
        this.charts.salesWeekly.data.labels = labels;
        this.charts.salesWeekly.data.datasets[0].data = data;
        this.charts.salesWeekly.update();
      } else {
        const ctx = canvas.getContext("2d");
        this.charts.salesWeekly = new Chart(ctx, {
          type: "line",
          data: {
            labels: labels,
            datasets: [
              {
                label: "Vendas Semanais",
                data: data,
                borderColor: "#0A2463",
                tension: 0.4,
              },
            ],
          },
          options: { responsive: true },
        });
      }
    } catch (e) {
      console.error("Erro ao criar gráfico semanal de vendas:", e);
    }
  }

  updatePaymentsWeeklyChart() {
    const canvas = document.getElementById("paymentsChartWeekly");
    if (!canvas || typeof Chart === "undefined") {
      console.warn(
        "Gráfico semanal de pagamentos: canvas ou Chart.js não disponível"
      );
      return;
    }

    const dividas = this.relatorioDividas?.dividas || this.dadosDividas;
    const weekMap = {
      "Semana 1": 0,
      "Semana 2": 0,
      "Semana 3": 0,
      "Semana 4": 0,
    };

    dividas.forEach((d) => {
      const date = new Date(d.dataVencimento);
      const day = date.getDate();
      const week =
        day <= 7
          ? "Semana 1"
          : day <= 14
          ? "Semana 2"
          : day <= 21
          ? "Semana 3"
          : "Semana 4";
      weekMap[week] += parseFloat(d.valorPendente) || 0;
    });

    const labels = Object.keys(weekMap);
    const data = labels.map((l) => weekMap[l]);

    try {
      if (this.charts.paymentsWeekly) {
        this.charts.paymentsWeekly.data.labels = labels;
        this.charts.paymentsWeekly.data.datasets[0].data = data;
        this.charts.paymentsWeekly.update();
      } else {
        const ctx = canvas.getContext("2d");
        this.charts.paymentsWeekly = new Chart(ctx, {
          type: "bar",
          data: {
            labels: labels,
            datasets: [
              {
                label: "Pagamentos Semanais",
                data: data,
                backgroundColor: "rgba(62,146,204,0.7)",
              },
            ],
          },
          options: { responsive: true },
        });
      }
    } catch (e) {
      console.error("Erro ao criar gráfico semanal de pagamentos:", e);
    }
  }

  exportarCSV() {
    const reportType = document.getElementById("reportType").value;

    if (reportType === "sales") {
      this.exportarVendasCSV();
    } else if (reportType === "payments") {
      this.exportarDividasCSV();
    } else if (reportType === "customers") {
      this.exportarClientesCSV();
    }
  }

  exportarVendasCSV() {
    const vendas = this.relatorioVendas?.vendas || this.dadosVendas;
    const headers = ["Data", "Cliente", "Valor", "Status"];
    const rows = vendas.map((venda) => {
      const cliente = this.clientes.find((c) => c.id === venda.clienteId);
      return [
        this.formatarData(venda.dataHora),
        cliente ? cliente.nome : "N/A",
        venda.valorTotal,
        this.getStatusText(venda.status),
      ];
    });
    this.downloadCSV(headers, rows, "relatorio-vendas.csv");
  }

  exportarDividasCSV() {
    const dividas = this.relatorioDividas?.dividas || this.dadosDividas;
    const headers = ["Data", "Cliente", "Valor Pago", "Status"];
    const rows = dividas.map((divida) => {
      const cliente = this.clientes.find((c) => c.id === divida.clienteId);
      const totalPago = divida.pagamentos
        ? divida.pagamentos.reduce(
            (sum, p) => sum + (parseFloat(p.valorPago) || 0),
            0
          )
        : 0;
      return [
        this.formatarData(divida.dataVencimento),
        cliente ? cliente.nome : "N/A",
        totalPago,
        "Pago",
      ];
    });
    this.downloadCSV(headers, rows, "relatorio-dividas.csv");
  }

  exportarClientesCSV() {
    const headers = ["Nome", "Telefone", "Email", "Saldo Devedor"];
    const rows = (this.clientes || []).map((cliente) => [
      cliente.nome,
      cliente.telefone || "N/A",
      cliente.email || "N/A",
      cliente.saldoDevedor || 0,
    ]);
    this.downloadCSV(headers, rows, "relatorio-clientes.csv");
  }

  downloadCSV(headers, rows, filename) {
    const csvContent = [
      headers.join(","),
      ...rows.map((row) => row.join(",")),
    ].join("\n");

    const blob = new Blob([csvContent], { type: "text/csv;charset=utf-8;" });
    const link = document.createElement("a");
    link.href = URL.createObjectURL(blob);
    link.download = filename;
    link.click();
    showToast("CSV exportado com sucesso!", "success");
  }

  getStatusClass(status) {
    switch (status) {
      case "PAGO":
        return "bg-green-100 text-green-800";
      case "PENDENTE":
        return "bg-red-100 text-red-800";
      case "CANCELADO":
        return "bg-gray-100 text-gray-800";
      default:
        return "bg-yellow-100 text-yellow-800";
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
        return "Parcial";
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
}

document.addEventListener("DOMContentLoaded", function () {
  const initManager = () => {
    if (typeof Chart !== "undefined") {
      new RelatoriosManager();
    } else {
      setTimeout(initManager, 200);
    }
  };

  setTimeout(initManager, 300);
});
