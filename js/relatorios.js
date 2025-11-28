class RelatoriosManager {
  constructor() {
    this.charts = {};
    this.init();
  }

  init() {
    this.configurarDatas();
    document.getElementById('applyFilterBtn').addEventListener('click', () => this.carregarRelatorio());
    this.carregarRelatorio();
  }

  configurarDatas() {
    const hoje = new Date();
    const inicioMes = new Date(hoje.getFullYear(), hoje.getMonth(), 1);
    document.getElementById('startDate').value = inicioMes.toISOString().split('T')[0];
    document.getElementById('endDate').value = hoje.toISOString().split('T')[0];
  }

  async carregarRelatorio() {
    const inicio = document.getElementById('startDate').value;
    const fim = document.getElementById('endDate').value;

    try {
      // 1. BUSCA DADOS REAIS
      const [vendas, pagamentos, dividas] = await Promise.all([
        apiService.getRelatorioVendas(inicio, fim),
        apiService.getRelatorioPagamentos(inicio, fim),
        apiService.getRelatorioDividas(inicio, fim)
      ]);

      // 2. RENDERIZA MENSAL
      this.atualizarCards(vendas, pagamentos, dividas);
      this.renderizarGraficoVendas(vendas.vendas);
      this.renderizarGraficoPagamentos(pagamentos);
      this.renderizarTabela(vendas.vendas);

      // 3. RENDERIZA SEMANAL (Agrupa os dados por semana)
      this.renderizarSemanal(vendas.vendas, pagamentos, dividas.dividas, inicio);

    } catch (error) {
      console.error("Erro:", error);
    }
  }

  // === LÓGICA MENSAL ===
  atualizarCards(vendas, pagamentos, dividas) {
    // Total Vendas
    this.setText('card1Value', this.formatarMoeda(vendas.faturamentoTotal));

    // Total Pagamentos
    const totalPago = pagamentos.reduce((acc, p) => acc + p.valorPago, 0);
    this.setText('card2Value', this.formatarMoeda(totalPago));

    // Clientes Ativos
    const unicos = new Set(vendas.vendas.map(v => v.clienteId)).size;
    this.setText('card3Value', unicos);

    // Fiados Pendentes
    this.setText('card4Value', this.formatarMoeda(dividas.valorTotalPendente));
  }

  renderizarGraficoVendas(lista) {
    const ctx = document.getElementById('chartSales').getContext('2d');
    const dados = {};

    lista.forEach(v => {
      const d = v.dataHora.split('T')[0];
      dados[d] = (dados[d] || 0) + v.valorTotal;
    });

    const labels = Object.keys(dados).sort();
    const values = labels.map(d => dados[d]);
    const labelsFmt = labels.map(d => new Date(d).toLocaleDateString('pt-BR', {day:'2-digit', month:'2-digit'}));

    this.criarGrafico('chartSales', 'line', labelsFmt, values, 'Vendas', '#0A2463');
  }

  renderizarGraficoPagamentos(lista) {
    const ctx = document.getElementById('chartPayments').getContext('2d');
    const totais = { 'DINHEIRO': 0, 'CARTAO': 0, 'PIX': 0, 'OUTROS': 0 };

    lista.forEach(p => {
      let m = 'OUTROS';
      if (p.metodoPagamento === 'DINHEIRO') m = 'DINHEIRO';
      else if (p.metodoPagamento?.includes('CARTAO')) m = 'CARTAO';
      else if (p.metodoPagamento === 'PIX') m = 'PIX';
      totais[m] += p.valorPago;
    });

    this.criarGraficoBarras('chartPayments', Object.values(totais));
  }

  // === LÓGICA SEMANAL ===
  renderizarSemanal(vendas, pagamentos, dividas, inicio) {
    const semanas = { 1: {v:0, p:0, d:0}, 2: {v:0, p:0, d:0}, 3: {v:0, p:0, d:0}, 4: {v:0, p:0, d:0} };
    const inicioDate = new Date(inicio);

    const getSemana = (d) => {
      const diff = Math.floor((new Date(d) - inicioDate) / (86400000));
      const s = Math.floor(diff / 7) + 1;
      return s > 4 ? 4 : (s < 1 ? 1 : s);
    };

    vendas.forEach(v => semanas[getSemana(v.dataHora)].v += v.valorTotal);
    pagamentos.forEach(p => semanas[getSemana(p.dataPagamento)].p += p.valorPago);
    dividas.forEach(d => semanas[getSemana(d.dataEmissao)].d += d.valorPendente);

    // Cards Semanais
    const totalV = Object.values(semanas).reduce((a,b)=>a+b.v,0);
    const totalP = Object.values(semanas).reduce((a,b)=>a+b.p,0);

    this.setText('weeklySalesTotal', this.formatarMoeda(totalV));
    this.setText('weeklyPaymentsTotal', this.formatarMoeda(totalP));
    this.setText('weeklyClientsActive', vendas.length);

    const inad = totalV > 0 ? (dividas.reduce((a,b)=>a+b.valorPendente,0) / totalV) * 100 : 0;
    this.setText('weeklyInadimplencia', inad.toFixed(1) + '%');

    // Gráficos Semanais
    const labels = ['Semana 1', 'Semana 2', 'Semana 3', 'Semana 4'];
    const dataV = [semanas[1].v, semanas[2].v, semanas[3].v, semanas[4].v];
    const dataP = [semanas[1].p, semanas[2].p, semanas[3].p, semanas[4].p];

    this.criarGrafico('salesChartWeekly', 'line', labels, dataV, 'Vendas', '#0A2463');
    this.criarGrafico('paymentsChartWeekly', 'bar', labels, dataP, 'Pagamentos', '#3E92CC');

    // Tabela Semanal
    this.renderizarTabelaSemanal(semanas);
  }

  renderizarTabelaSemanal(semanas) {
    const tbody = document.getElementById('weeklyDetailsBody');
    if(tbody) {
      let html = '';
      for(let i=1; i<=4; i++) {
        html += `<tr>
                    <td class="px-4 py-2">Semana ${i}</td>
                    <td class="px-4 py-2">${this.formatarMoeda(semanas[i].v)}</td>
                    <td class="px-4 py-2">${this.formatarMoeda(semanas[i].p)}</td>
                    <td class="px-4 py-2 text-danger">${semanas[i].v > 0 ? ((semanas[i].d/semanas[i].v)*100).toFixed(1) : 0}%</td>
                </tr>`;
      }
      tbody.innerHTML = html;
    }
  }

  // === HELPERS ===
  criarGrafico(id, type, labels, data, label, color) {
    const ctx = document.getElementById(id);
    if(!ctx) return;
    if(this.charts[id]) this.charts[id].destroy();

    this.charts[id] = new Chart(ctx, {
      type: type,
      data: {
        labels: labels,
        datasets: [{
          label: label,
          data: data,
          backgroundColor: type === 'line' ? color + '20' : color,
          borderColor: color,
          borderWidth: 2,
          fill: true,
          tension: 0.4
        }]
      },
      options: { responsive: true, maintainAspectRatio: false, plugins:{legend:{display:false}} }
    });
  }

  criarGraficoBarras(id, data) {
    const ctx = document.getElementById(id);
    if(!ctx) return;
    if(this.charts[id]) this.charts[id].destroy();

    this.charts[id] = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: ['Dinheiro', 'Cartão', 'PIX', 'Outros'],
        datasets: [{
          data: data,
          backgroundColor: ['#0A2463', '#3E92CC', '#D8315B', '#FFC107'],
          borderRadius: 4
        }]
      },
      options: { responsive: true, maintainAspectRatio: false, plugins:{legend:{display:false}} }
    });
  }

  renderizarTabela(lista) {
    const tbody = document.getElementById('tabelaVendasBody');
    if(!tbody) return;
    tbody.innerHTML = lista.slice(0,5).map(v => `
            <tr>
                <td class="px-4 py-2">${new Date(v.dataHora).toLocaleDateString('pt-BR')}</td>
                <td class="px-4 py-2">Cliente #${v.clienteId}</td>
                <td class="px-4 py-2 fw-bold text-primary">${this.formatarMoeda(v.valorTotal)}</td>
                <td class="px-4 py-2"><span class="badge ${v.status==='PAGO'?'bg-success':'bg-warning text-dark'}">${v.status||'Pendente'}</span></td>
                <td class="px-4 py-2"><i class="material-icons text-primary fs-6">visibility</i></td>
            </tr>`).join('');
  }

  setText(id, val) { const el = document.getElementById(id); if(el) el.textContent = val; }
  formatarMoeda(v) { return new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(v); }
}

document.addEventListener('DOMContentLoaded', () => new RelatoriosManager());