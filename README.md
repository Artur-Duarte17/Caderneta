# Caderneta — Front-end (Flutter Web)

Interface web do sistema de vendas a prazo, escrita em Flutter (apenas web).


## Executar em desenvolvimento

```bash
flutter pub get
flutter run -d chrome
```

O backend deve estar em `http://localhost:8080`. Para outro endereço:

```bash
flutter run -d chrome --dart-define=API_URL=http://meu-servidor:8080
```

## Build de produção

```bash
flutter build web --release --dart-define=API_URL=http://localhost:8080
```

Os arquivos ficam em `build/web/`. Com Docker, o `Dockerfile` faz o build e serve com NGINX (porta 80, mapeada para 3000 no `docker-compose.yml`).

## Estrutura

```
lib/
├── main.dart                     # Rotas (go_router) e tema
├── core/
│   ├── api.dart                  # Cliente HTTP + Snapshot (clientes/vendas/dívidas)
│   ├── models.dart               # Entidades, Status e MetodoPagamento
│   ├── notificacoes_service.dart # Notificações + atualização automática (polling 30s)
│   ├── format.dart               # Moeda, datas, parsing de valores
│   └── theme.dart                # Paleta, espaçamentos e tema Material 3
├── widgets/
│   ├── app_shell.dart            # Menu lateral (desktop) / gaveta (mobile)
│   └── common.dart               # Componentes compartilhados (cards, badges, tabelas, diálogos…)
└── pages/                        # Visão Geral, Clientes, Vendas, Pagamentos, Relatórios, Notificações
```

## Padrões de design

- **Status de dívida** têm um único rótulo/cor em todo o app (`Status` em `models.dart`):
  Pendente, Parcial, Pago, Vencida, Cancelada. Dívida em aberto com vencimento passado aparece como **Vencida**.
- **Formulários e detalhes** sempre em diálogo central, com validação nos campos e botão com indicador de carregamento.
- **Carregamento / vazio / erro** padronizados (`AsyncView`, `EmptyState`, `ErrorState`).
- Cores, espaçamentos e raios vêm de `theme.dart` — evite valores soltos nas telas.
