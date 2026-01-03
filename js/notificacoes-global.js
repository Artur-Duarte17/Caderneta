// ===== NOTIFICACOES-GLOBAL.JS - Agora com WebSockets REAIS =====

class NotificacoesGlobal {
  constructor() {
    this.notificacoes = [];
    this.stompClient = null;
    this.init();
  }

  init() {
    this.conectarWebSocket();
    // Mantém a atualização do badge ao carregar
    this.carregarNotificacoesIniciais();
  }

  carregarNotificacoesIniciais() {
    // Carrega as notificações existentes do banco via API REST
    if (window.apiService) {
      window.apiService
        .getNotificacoes()
        .then((data) => {
          if (data) {
            this.notificacoes = data;
            this.atualizarBadge();
          }
        })
        .catch((err) =>
          console.error("Erro ao carregar notificações iniciais:", err)
        );
    }
  }

  conectarWebSocket() {
    // Conecta no endpoint definido no Java: /ws
    const socket = new SockJS("http://localhost:8080/ws");
    this.stompClient = Stomp.over(socket);

    // Desabilitar logs de debug do stomp no console se quiser limpar a tela
    // this.stompClient.debug = null;

    this.stompClient.connect(
      {},
      (frame) => {
        console.log("Conectado ao WebSocket: " + frame);

        // Se inscreve no tópico onde o Java publica as mensagens
        this.stompClient.subscribe("/topic/notificacoes", (message) => {
          const notificacao = JSON.parse(message.body);
          this.receberNotificacao(notificacao);
        });
      },
      (error) => {
        console.error("Erro na conexão WebSocket:", error);
        // Tenta reconectar em 5 segundos se cair
        setTimeout(() => this.conectarWebSocket(), 5000);
      }
    );
  }

  receberNotificacao(notificacao) {
    console.log("Nova notificação recebida via WebSocket:", notificacao);

    // Adiciona ao início da lista
    this.notificacoes.unshift(notificacao);
    this.atualizarBadge();
    this.mostrarToastNotificacao(notificacao);

    // Dispara evento para a página de Notificações (se estiver aberta) atualizar a lista
    window.dispatchEvent(
      new CustomEvent("novaNotificacao", {
        detail: notificacao,
      })
    );

    // Dispara eventos específicos para outras telas atualizarem (Ex: Dashboard)
    // Isso substitui o "polling" de 30s. Agora é instantâneo.
    if (notificacao.tipoNotificacao === "COMPRA_REALIZADA") {
      window.dispatchEvent(new Event("vendaCriada")); // Dashboard ouve isso
    } else if (notificacao.tipoNotificacao === "PAGAMENTO_RECEBIDO") {
      window.dispatchEvent(new Event("pagamentoDividaRealizado")); // Dashboard ouve isso
    }
  }

  mostrarToastNotificacao(n) {
    // Usa o sistema de Toast existente no app.js, se disponível
    if (window.showToast) {
      // Formata uma mensagem bonitinha
      const titulo = this.getTituloPorTipo(n.tipoNotificacao);
      window.showToast(`<strong>${titulo}</strong>: ${n.mensagem}`, "info");
    }
  }

  getTituloPorTipo(tipo) {
    const mapa = {
      COMPRA_REALIZADA: "Nova Venda",
      CADASTRO_CLIENTE: "Novo Cliente",
      PAGAMENTO_RECEBIDO: "Pagamento",
      LEMBRETE_VENCIMENTO: "Vencimento",
    };
    return mapa[tipo] || "Notificação";
  }

  atualizarBadge() {
    const badge = document.getElementById("notificationBadge");
    if (badge) {
      const count = this.notificacoes.filter((n) => !n.lida).length;
      badge.textContent = count > 99 ? "99+" : count;
      badge.style.display = count > 0 ? "inline-block" : "none";
    }
  }
}

// Inicializa globalmente
window.notificacoesGlobal = new NotificacoesGlobal();
