# Caderneta — Front-end (Flutter Web)

Interface web do sistema de vendas a prazo, escrita em Flutter (apenas web).

Use Flutter **3.47.6**, conforme .fvmrc, e pubspec.lock. As regras atuais estão em [contratos e permissões do integrador](../docs/contratos-e-permissoes.md); os resultados finais, em [entrega](../docs/entrega-homologacao-2026-11-05.md).


## Como o frontend fala com a API

No build padrão, o navegador chama `/api/...` na **mesma origem** da página. Em produção (Docker) o nginx
encaminha `/api/` ao serviço `backend:8080`; o navegador nunca acessa `backend:8080` direto.
O cookie de sessão `SESSION` é `HttpOnly` e administrado pelo navegador.

`API_URL` (`--dart-define`) é vazio por padrão = caminho relativo. Só defina para desenvolvimento
fora do Docker.

## Executar

**Pelo Docker (validação oficial, mesma origem):**

```bash
docker compose up --build   # a partir da raiz do projeto; abre em http://localhost:3000
```

**Desenvolvimento rápido com a API real** (exige CORS com credenciais para a origem fixa no backend):

```bash
flutter pub get
flutter run -d chrome --web-port=5000 --dart-define=API_URL=http://localhost:8082
```

**Desenvolvimento sem backend** (dados simulados; nunca usar em produção):

```bash
flutter run -d chrome --dart-define=MOCK_API=true
```

## Build de produção

```bash
flutter build web --release --dart-define=MOCK_API=false
```

Os arquivos ficam em `build/web/`. O `Dockerfile` consome o build já testado e serve com nginx (porta 80, mapeada para 3000 no Compose local). Execute `scripts/Preparar-Entrega.ps1` na raiz do integrador para validar lockfile, análise, testes e build antes de empacotar. Para uma base alternativa da API, use `--dart-define=API_URL=...` na compilação Flutter.

## Testes

```bash
flutter analyze
flutter test --concurrency=1
```

## Estrutura

```
lib/
├── main.dart                  # Composição e bloqueio de MOCK_API em release
├── app_router.dart            # Rotas, sessão e permissões
├── core/                      # HTTP/CSRF, sessão, modelos e repositórios
├── dev/fakes.dart             # Transporte simulado, removido do build de produção
├── widgets/                   # Shell, formulários, tabelas e paginação
└── pages/                     # Operação, Histórico, Auditoria, Acessos e minha caderneta
test/                          # Testes na VM e referências visuais em cinco larguras
scripts/verify_nginx.sh         # Validação isolada de proxy e fallback SPA
```

## Padrões de design

- **Status de dívida** têm um único rótulo/cor em todo o app (`Status` em `models.dart`):
  Pendente, Parcial, Pago, Vencida, Cancelada. Dívida em aberto com vencimento passado aparece como **Vencida**.
- **Formulários e detalhes** sempre em diálogo central, com validação nos campos e botão com indicador de carregamento.
- **Carregamento / vazio / erro** padronizados (`AsyncView`, `EmptyState`, `ErrorState`).
- Cores, espaçamentos e raios vêm de `theme.dart` — evite valores soltos nas telas.

## Simulação e perfis

Use `MOCK_API=true` somente em desenvolvimento. Logins de exemplo: `gerente`, `funcionario`,
`cliente.a` e `cliente.b`; qualquer senha não vazia é aceita pelo transporte simulado.
A simulação fica em memória e volta ao estado inicial ao recarregar. A restauração pelo cookie
é responsabilidade da API real. Builds release com `MOCK_API=true` são recusados na inicialização.

O usuário entra pela tela de login; o primeiro acesso de um cliente exige CPF e convite gerado
por gerente ou funcionário. Clientes acessam apenas `/api/me/*`. Relatórios, Auditoria, Acessos
ficam disponíveis ao gerente. Funcionário também edita suas próprias vendas, sem acesso às vendas de outro vendedor. Itens são opcionais e não alteram automaticamente o total financeiro. `/notificacoes` redireciona para Histórico.

Para validar o proxy depois de gerar `build/web`:

```bash
bash scripts/verify_nginx.sh
```

O script cria e remove contêineres e uma rede exclusivos, sem usar o Compose nem a API real.
Confere SPA, caminho da API, JSON, cookie, cache e preservação de erros do upstream simulado.

Resultados, contratos e limites: [integração](docs/integracao-frontend.md).
Avaliação do bot, sem implementação: [recomendação](docs/bot-recomendacao.md).

O [contrato atual](../docs/contratos-e-permissoes.md) substitui decisões divergentes dos planos anteriores.
Para validar com menor concorrência, execute análise, testes e build um de cada vez. O build JavaScript pode usar
`flutter build web --release --no-wasm-dry-run --dart-define=MOCK_API=false`; a opção pula a compilação adicional de verificação Wasm.
