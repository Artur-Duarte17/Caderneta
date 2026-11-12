# Caderneta — Frontend (Flutter Web)

Interface web do **Caderneta**, sistema para comércios registrarem **vendas a prazo** ("fiado").
Escrita em **Flutter** (só web), funciona no computador e no celular, e conversa com a API
[`api-caderneta`](https://github.com/EduardoBR2003/api-caderneta) pela **mesma origem** (`/api`).

| | |
|---|---|
| **Framework** | Flutter **3.47.9** (fixado no `Dockerfile`, no CI e no `subir.sh`; conferido por SHA-256) |
| **Linguagem** | Dart 3 |
| **Principais pacotes** | `go_router` (rotas), `http` (com `withCredentials`), `intl` (pt-BR), `fl_chart` (gráficos), `web` (APIs do navegador) |
| **Produção** | Firebase Hosting — https://caderneta01.web.app (`/api/**` reencaminhado ao Cloud Run) |
| **Local** | NGINX em container (porta 3000 no Docker Compose do integrador) |
| **Navegadores suportados** | Chrome e Edge (Chromium), no computador e no celular |

Este repositório é submódulo do integrador
[`Projeto_Final_Caderneta`](https://github.com/LuisHRodrigues/Projeto_Final_Caderneta), onde ficam o
Docker Compose, os testes de navegador (Playwright) e a documentação de operação.

> O `.fvmrc`, o Dockerfile e o CI usam Flutter **3.47.9**, também usado nos testes visuais.

---

## Sumário

1. [Telas e funcionalidades](#1-telas-e-funcionalidades)
2. [Perfis e permissões na interface](#2-perfis-e-permissões-na-interface)
3. [Segurança](#3-segurança)
4. [Padronização e validação dos formulários](#4-padronização-e-validação-dos-formulários)
5. [Experiência de uso](#5-experiência-de-uso)
6. [Arquitetura e código](#6-arquitetura-e-código)
7. [Como executar](#7-como-executar)
8. [Build e publicação](#8-build-e-publicação)
9. [Testes](#9-testes)
10. [Limitações conhecidas](#10-limitações-conhecidas)

---

## 1. Telas e funcionalidades

**Telas públicas**

| Rota | Tela | O que faz |
|---|---|---|
| `/login` | Entrar | Login e senha; links "Primeiro acesso" e **"Criar minha loja"** |
| `/criar-loja` | Criar minha loja | Cadastro público: nome da loja, dados do dono, login e senha; o dono vira gerente |
| `/ativar` | Primeiro acesso | O cliente ativa o acesso com CPF + código do convite e escolhe login e senha |

**Telas da loja (gerente e funcionário)** — o nome da loja aparece no menu

| Rota | Tela | O que faz |
|---|---|---|
| `/` | Visão Geral | Indicadores (saldo a receber, vendas do mês, recebido), vendas recentes, clientes com débito |
| `/clientes` | Clientes | Lista com busca (nome ou telefone), situação (em dia, devendo, em atraso), cadastro e edição, limite de crédito e prazo (gerente), fiador, detalhes financeiros, **gerar convite** |
| `/vendas` | Vendas | Nova venda (total + itens opcionais), busca de cliente no servidor, filtros por status e período, detalhes, edição, exclusão (gerente) e **comprovante** |
| `/pagamentos` | Pagamentos | Dívidas em aberto, registrar pagamento (parcial/total, 6 métodos), **renegociar vencimento** (gerente), comprovantes |
| `/historico` | Histórico | Linha do tempo de eventos (cadastros, compras, pagamentos, lembretes), com filtros e atualização automática |
| `/relatorios` | Relatórios (gerente) | Vendas, dívidas e clientes por período, gráficos e **exportação CSV** |
| `/auditoria` | Auditoria (gerente) | Quem fez o quê e quando, com antes/depois; filtros por ação e recurso |
| `/acessos` | Acessos (gerente) | Contas da loja: criar funcionário, ativar/desativar, **tornar gerente / funcionário**, **excluir** (lixeira) e, com "Mostrar excluídos", **restaurar** |

**Área do cliente** — `/minha` (resumo), `/minha/compras`, `/minha/dividas`, `/minha/pagamentos`,
`/minha/historico`: o cliente vê só os próprios dados naquela loja.

**Comportamentos importantes**
- Após o login, todo usuário abre **a tela inicial do perfil** (Visão Geral; cliente: Minha
  caderneta), nunca a tela de quem estava antes. Recarregar (F5) mantém a tela atual.
- Recadastrar o CPF de um funcionário excluído **reativa a conta antiga** e avisa o login mantido.
- Menu lateral fixo no computador; em telas com menos de 900 px vira gaveta (ícone de três linhas).

---

## 2. Perfis e permissões na interface

| Área | Gerente | Funcionário | Cliente |
|---|:-:|:-:|:-:|
| Visão Geral, Clientes, Vendas, Pagamentos, Histórico | ✅ | ✅ | — |
| Editar venda | ✅ | ✅ (o servidor só permite as próprias) | — |
| Limite de crédito e prazo do cliente | ✅ | — | — |
| Relatórios, Auditoria, Acessos | ✅ | — | — |
| Minha caderneta | — | — | ✅ |

O menu só mostra o que o perfil pode usar e o roteador redireciona rotas não permitidas para
"Acesso negado". **Isso é só conveniência**: quem decide é a API, que verifica perfil e loja em toda
requisição.

---

## 3. Segurança

### 3.1 Comunicação com a API

- **Mesma origem:** o navegador chama `/api/...` no próprio domínio do site; o Firebase Hosting
  (produção) ou o NGINX (local) encaminham à API. Não há URL de servidor no código publicado e o
  CORS fica desligado na API.
- **HTTPS em produção:** Firebase Hosting com certificado gerenciado, **TLS 1.2/1.3** (TLS 1.0 e 1.1
  recusados), HTTP redirecionado e **HSTS** de 1 ano com `includeSubDomains` e `preload`.
- `withCredentials` no cliente HTTP: o navegador envia o cookie de sessão; tempo limite de **20 s** por
  requisição.

### 3.2 Sessão e credenciais

- **Nada sensível é guardado pelo frontend.** A sessão vive num cookie **`HttpOnly`** (o código da
  página não consegue ler), **`Secure`** e **`SameSite=Lax`**, criado e controlado pela API.
- A senha só trafega no corpo do `POST /api/auth/login` (via HTTPS) e nunca é armazenada.
- **Token CSRF** obtido em `GET /api/auth/csrf`, mantido **só em memória** e enviado no cabeçalho
  `X-CSRF-TOKEN` em toda alteração. Se a API responder `CSRF_INVALID`, o token é renovado e a sessão
  conferida — **a operação nunca é repetida automaticamente**.
- `401` em rota autenticada encerra a sessão local e leva ao login; o login **não guarda a tela
  anterior** (evita que um usuário caia na tela de outro).
- `localStorage` não é usado. O `sessionStorage` guarda só **chaves de idempotência aleatórias**
  (geradas com `Random.secure()`), identificadas por um hash da operação — nunca o corpo da
  requisição, senhas ou dados de clientes. Elas evitam duplicar uma venda ou um pagamento se a rede
  falhar e o usuário tentar de novo.

### 3.3 Cabeçalhos de segurança (Firebase Hosting e NGINX local)

| Cabeçalho | Valor e efeito |
|---|---|
| `Content-Security-Policy` | `default-src 'self'`; scripts só do próprio site (+ `wasm-unsafe-eval` para o Flutter); `connect-src 'self'` (só fala com a própria API); `object-src 'none'`; `base-uri 'self'`; `form-action 'self'`; `frame-ancestors 'none'` |
| `Strict-Transport-Security` | `max-age=31536000` (Firebase acrescenta `includeSubDomains; preload`) |
| `X-Frame-Options: DENY` | impede abrir o site dentro de outro (clickjacking) |
| `X-Content-Type-Options: nosniff` | o navegador não "adivinha" tipos de arquivo |
| `Referrer-Policy: strict-origin-when-cross-origin` | não vaza caminhos para outros sites |
| `Permissions-Policy` | câmera, microfone, localização, pagamento e USB desligados |
| `Cache-Control` | `no-cache` no site (sempre a versão nova); as respostas de `/api` mantêm o **`no-store`** da API |

O CanvasKit do Flutter é empacotado com o site (`--no-web-resources-cdn`): nenhum script vem de CDN
de terceiros. O NGINX local também limita `login` e `registro-cliente` a 10 requisições/min por IP.

### 3.4 Código publicado

- **Sem segredos no build:** toda configuração do Flutter Web é pública por natureza; não há chaves,
  senhas nem URLs internas. O CI roda **gitleaks** sobre o `build/web`, e cada publicação é conferida
  (sem host do banco, sem usuários, sem `localhost`).
- **Modo simulado bloqueado em produção:** `MOCK_API=true` (dados falsos para desenvolvimento) faz o
  app **recusar a inicialização** num build release.
- Comprovantes abrem em nova aba com `noopener`.
- Build reproduzível: Flutter oficial baixado do Google e conferido por **SHA-256**;
  dependências exatamente as do `pubspec.lock` (`--enforce-lockfile`).

### 3.5 Validação de entrada

A interface valida e padroniza tudo antes de enviar (detalhes na seção 4), mas **a API valida de
novo**: o frontend nunca é a única barreira.

---

## 4. Padronização e validação dos formulários

Módulos: [`lib/core/documentos.dart`](lib/core/documentos.dart) (CPF/telefone),
[`lib/core/entrada_numerica.dart`](lib/core/entrada_numerica.dart) (números) e
[`lib/core/validacoes.dart`](lib/core/validacoes.dart) (demais campos). Cada campo tem **filtro de
digitação** (caracteres inválidos não entram, nem colando) e **validação ao salvar** (regex completa).

| Campo | Ao digitar | Ao salvar |
|---|---|---|
| CPF | máscara `000.000.000-00`, só dígitos | formato + dígitos verificadores; enviado **só com dígitos** |
| Telefone | máscara `(00) 00000-0000` / `(00) 0000-0000` | DDD + celular (9 + 8 dígitos) ou fixo; enviado só com dígitos |
| Valores em R$ | dígitos, ponto de milhar, uma vírgula, 2 casas | positivo, dentro dos limites |
| Quantidade, prazo | só dígitos | faixas (quantidade ≥ 1; prazo 0–3650 dias) |
| Nome | letras (com acento), espaço, `'`, `-`, `.` | 3–150 caracteres |
| E-mail | sem espaços, até 100 | `usuario@dominio.ext` |
| Endereço, descrição do item | sem caracteres invisíveis, até 200 | conteúdo mínimo |
| Cargo, matrícula | caracteres permitidos, até 50 | formato |
| Login | só `A–Z a–z 0–9 . _ -` (na criação) | `^[A-Za-z0-9._-]{3,50}$` |
| Senha | até 72 | mínimo de 8 caracteres, máximo de 72 bytes UTF-8; confirmação igual |
| Código do convite | maiúsculas, alfabeto do servidor | 20 caracteres (sem 0, O, 1, I) |
| Filtros da Auditoria | "venda criada" vira `VENDA_CRIADA` | — |

Também: o fiador não pode ter o mesmo CPF do cliente; teclado numérico/e-mail no celular; inicial
maiúscula em nomes; sem correção automática em login, senha e e-mail.

---

## 5. Experiência de uso

- **Indicadores de carregamento** em todo o sistema ([`lib/widgets/carregando.dart`](lib/widgets/carregando.dart)):
  círculo + "Carregando clientes..." (com reticências animadas) na primeira carga; barra +
  "Buscando..." ao recarregar com dados na tela; botões com "Entrando...", "Salvando...",
  "Registrando pagamento..."; janela de espera em ações rápidas (excluir venda, renegociar, sair).
- Estados padronizados de vazio e erro, com "tentar de novo".
- Cores, espaçamentos e raios de [`lib/core/theme.dart`](lib/core/theme.dart); status de dívida com
  um rótulo e uma cor únicos (Pendente, Parcial, Pago, Vencida, Cancelada); excluído em vermelho,
  restaurar em verde.
- Favicon e ícones do app (SVG + PNG; versões para iPhone e Android "maskable").
- Acessibilidade: textos com escala do sistema testada, anúncios de carregamento para leitores de tela.

---

## 6. Arquitetura e código

```
lib/
├── main.dart                 # composição; bloqueia MOCK_API em release; "Verificando sua sessão..."
├── app_router.dart           # rotas (go_router), redirecionamentos por sessão e perfil
├── core/
│   ├── http_gateway.dart     # HTTP: CSRF, idempotência, tempo limite, tratamento de 401/403
│   ├── csrf.dart             # token CSRF em memória
│   ├── idempotencia*.dart    # chaves de idempotência (sessionStorage)
│   ├── session.dart          # estado da sessão (verificando, autenticado, expirado)
│   ├── api.dart  *_repository.dart   # chamadas por recurso
│   ├── models.dart  permissoes.dart  # modelos, perfis e matriz de permissões
│   ├── documentos.dart  entrada_numerica.dart  validacoes.dart   # entrada de dados
│   └── theme.dart  format.dart  dates.dart
├── widgets/                  # app_shell (menu), common (tabelas, botões, AsyncView), carregando, paginacao
├── pages/                    # uma tela por arquivo; pages/minha/ = área do cliente
└── dev/fakes.dart            # servidor simulado (só desenvolvimento e testes)
web/                          # index.html, manifest, favicon e ícones
firebase.json                 # Hosting: rewrite /api/** → Cloud Run, SPA, cabeçalhos
nginx.conf                    # servidor local (mesmos cabeçalhos; proxy /api → backend)
Dockerfile                    # compila com Flutter 3.47.9 e serve com NGINX
Dockerfile.local              # só empacota um build/web já gerado (usado pelo subir.sh)
scripts/verify_nginx.sh       # valida o nginx.conf em containers isolados
```

---

## 7. Como executar

**Pela pilha completa (recomendado):** no integrador, `docker compose up -d --build` →
http://localhost:3000 (o NGINX encaminha `/api` à API).

**Desenvolvimento com a API real** (exige `caderneta.cors.allowed-origins` na API, pois muda a origem):

```bash
flutter pub get --enforce-lockfile
flutter run -d chrome --web-port=5000 --dart-define=API_URL=http://localhost:8082
```

**Sem backend (dados simulados, nunca em produção):**

```bash
flutter run -d chrome --dart-define=MOCK_API=true
```

Logins do simulador: `gerente`, `funcionario`, `cliente.a`, `cliente.b` (qualquer senha não vazia).
Os dados ficam em memória e voltam ao início ao recarregar.

| `--dart-define` | Padrão | Uso |
|---|---|---|
| `API_URL` | vazio (= `/api` na mesma origem) | só para `flutter run` fora do Docker |
| `MOCK_API` | `false` | `true` só em desenvolvimento e testes |

---

## 8. Build e publicação

```bash
flutter build web --release --no-web-resources-cdn --dart-define=MOCK_API=false
```

Saída em `build/web/`. Em produção, o build é feito no container (`docker build --target build .`),
extraído e publicado com `firebase deploy --only hosting --project caderneta01`. O
[`firebase.json`](firebase.json) define o rewrite `/api/**` → serviço Cloud Run `caderneta-api`
(`southamerica-east1`), o fallback da SPA e os cabeçalhos de segurança.

**Deploy automático:** o workflow [`.github/workflows/ci.yml`](.github/workflows/ci.yml) roda
análise, testes, build e gitleaks em todo push e pull request; **a cada push na `main`**, se tudo
passar, publica sozinho no Firebase Hosting e verifica o site. Autenticação por **Workload Identity
Federation** (sem chave JSON; o provedor só aceita este repositório na `main`; a conta
`github-hosting` só pode publicar no Hosting). Pushes na `master` e pull requests só testam.

---

## 9. Testes

```bash
flutter analyze
flutter test --concurrency=1
bash scripts/verify_nginx.sh     # depois de gerar build/web
```

**116 testes** (unitários e de tela), entre eles: permissões e rotas; CSRF e idempotência no
gateway HTTP; sessão e expiração; tela inicial após o login; formulários (máscaras, filtros e
validações, com conferência de que a API recebe só dígitos); indicadores de carregamento com
servidor lento; promoção a gerente; exclusão, restauração e reativação; cadastro de loja;
responsividade e acessibilidade (escala de texto); imagens de referência do login em 5 larguras
(geradas no Flutter 3.47.9). Os testes de navegador de ponta a ponta (Playwright) ficam no integrador.

---

## 10. Limitações conhecidas

- Não há tela de notificações com "marcar como lida" (o Histórico mostra os eventos).
- Não há tela para renomear a loja; o cliente precisa de uma conta por loja.
- Sem envio de avisos por WhatsApp, SMS ou e-mail.
- Navegadores testados: Chrome e Edge.
