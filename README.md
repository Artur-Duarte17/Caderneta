# Caderneta — Front-end (Flutter Web + Android)

Interface do sistema de vendas a prazo, escrita em Flutter. O mesmo código roda no
navegador e como app Android; abaixo de 900 px de largura o layout muda para o de
celular (barra de navegação inferior e formulários em tela cheia).

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

## Android (celular físico)

1. No celular, ative **Opções do desenvolvedor → Depuração USB** e conecte no PC.
   `flutter devices` deve listar o aparelho.
2. Deixe o backend rodando no PC (`docker compose up`).
3. Faça o `localhost` do celular apontar para o PC pelo cabo USB, usando a mesma
   porta do `API_URL` padrão de `lib/core/api.dart`:

   ```bash
   adb reverse tcp:8082 tcp:8082
   ```

   (o redirecionamento some ao desconectar o cabo; rode de novo quando reconectar).
4. Rode o app:

   ```bash
   flutter run -d <id-do-aparelho>
   ```

Sem cabo (mesma rede Wi-Fi), aponte direto para o IP do PC:
`flutter run --dart-define=API_URL=http://192.168.0.10:8082`.

APK para instalar manualmente: `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`
(assinado com a chave de debug — serve para testes, não para a Play Store).

No Android, "Exportar CSV" em Relatórios abre o menu de compartilhamento (Drive, Arquivos, WhatsApp…).

## Estrutura

```
lib/
├── main.dart                     # Rotas (go_router) e tema
├── core/
│   ├── api.dart                  # Cliente HTTP + Snapshot (clientes/vendas/dívidas)
│   ├── models.dart               # Entidades, Status e MetodoPagamento
│   ├── notificacoes_service.dart # Notificações + atualização automática (polling 30s)
│   ├── format.dart               # Moeda, datas, parsing de valores
│   ├── salvar_arquivo*.dart      # Exportação: download no web / compartilhar no Android
│   └── theme.dart                # Paleta, espaçamentos, breakpoint mobile e tema Material 3
├── widgets/
│   ├── app_shell.dart            # Menu lateral (desktop) / AppBar + barra inferior (celular)
│   └── common.dart               # Componentes compartilhados (cards, badges, tabelas, diálogos…)
└── pages/                        # Visão Geral, Clientes, Vendas, Pagamentos, Relatórios, Notificações
```

## Padrões de design

- **Status de dívida** têm um único rótulo/cor em todo o app (`Status` em `models.dart`):
  Pendente, Parcial, Pago, Vencida, Cancelada. Dívida em aberto com vencimento passado aparece como **Vencida**.
- **Formulários e detalhes** usam `AppFormDialog`: diálogo central no desktop, tela cheia no celular,
  com validação nos campos e botão com indicador de carregamento.
- **Carregamento / vazio / erro** padronizados (`AsyncView`, `EmptyState`, `ErrorState`).
- Cores, espaçamentos e raios vêm de `theme.dart` — evite valores soltos nas telas.
