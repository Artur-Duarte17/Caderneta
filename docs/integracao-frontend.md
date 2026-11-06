# Integração do frontend — 05/11/2026

> Registro histórico. Para regras atuais, enquadramento, testes visuais e resultados, consulte [contratos](../../docs/contratos-e-permissoes.md) e [entrega homologada](../../docs/entrega-homologacao-2026-11-05.md).

A implementação inicial usou o plano detalhado do frontend. O plano compartilhado foi recebido posteriormente como anexo do usuário e agora está em [plano-execucao-caderneta-atualizado.md](../../docs/plano-execucao-caderneta-atualizado.md), que prevalece sobre os rascunhos. Os contratos novos foram conferidos diretamente no código do backend e no relatório publicado por seu responsável em `../../docs/backend-integracao.md`.

## Ambiente e autoria

Antes de editar: `whoami` → `luish`; `hostname` → `fedora`; `pwd` → `/home/luish/Documentos/vsCode/Projeto_Final_Caderneta`. `/etc/os-release` confirmou Fedora Linux 44. A leitura dos arquivos funcionou.

Minhas alterações de código estão em `frontend-repo/`, incluindo `nginx.conf`, Dockerfile e testes. Na retomada também consolidei a documentação de integração em `../../docs/`, conforme o plano compartilhado. Não editei o backend, o Compose, `.env.example`, branches nem ponteiros de submódulos. O backend e `docker-compose.yml` mudaram por outra sessão durante o trabalho; essas contribuições foram preservadas. O `pubspec.lock`, modificado antes do início, manteve o mesmo SHA-256 nesta execução. Sem commit, push ou publicação.

O frontend estava em `master`, commit `21ea9d6`; o integrador, em `feat/frontend-flutter-web`. Não houve troca de branch. O SDK precisou de acesso ao próprio cache fora do workspace para executar os comandos Flutter. Chrome/Chromium não estavam disponíveis.

Linha de base: `flutter pub get --offline`, `flutter analyze` e `flutter build web --release` passaram. O build já emitia aviso de fonte Cupertino ausente; ele continua igual, sem dependência nova adicionada.

## Implementação

| Área | Responsabilidade e arquivos |
|---|---|
| Requisições | `core/http_gateway.dart`, fábrica condicional de cliente e `csrf.dart`: credenciais no navegador, URL relativa, CSRF deduplicado, timeout, erros JSON e descarte de respostas por época. Nenhuma mutação é repetida automaticamente. |
| Sessão e navegação | `session.dart`, `auth_repository.dart`, `permissoes.dart`, `app_router.dart` e `main.dart`: validação inicial antes de construir páginas protegidas, login, restauração, expiração, logout e `next` interno permitido ao perfil. |
| Interface por perfil | Shell com usuário, perfil, menus e saída na lateral e na gaveta. Funcionário sem edição de venda ou indicadores gerenciais. Perfil desconhecido não recebe permissões. |
| Histórico | `historico_page.dart`, repositório, serviço e controlador paginado: tipos, período local convertido para UTC, fim exclusivo, tamanho 10/20/50, paginação remota, retry, sequência de pedidos e banner fora da primeira página. `/notificacoes` é um redirecionamento. |
| Atualização | Polling de 30 segundos apenas autenticado e com aba visível; sem consultas sobrepostas; uma consulta ao voltar à aba. Revisão após operações confirmadas atualiza as telas existentes. |
| Cliente | `pages/minha/caderneta_page.dart`: resumo, compras/itens, dívidas/vencimentos, pagamentos e Histórico próprio. Dados de negócio vêm somente de `/api/me/*`, sem `Snapshot`. |
| Convites e contas | Ativação pública sem login automático, convite com geração explícita, código exibido uma vez, gestão paginada, confirmação de ativação/desativação e criação de funcionário com DTO publicado. |
| Auditoria | Página exclusiva do gerente, filtros e paginação remotos, ator/recurso do DTO real e alterações JSON decodificadas. Campos de segredo são removidos recursivamente antes da exibição. |
| Layout | Escala `Gap` estendida; larguras pequenas, tabelas horizontais, diálogos com rolagem, método de pagamento expansível e mensagens de conflito na edição preservando o formulário. Controladores de formulários são descartados ao fechar. |
| Produção | `API_URL` vazio por padrão. nginx separa `/api/` do fallback SPA, preserva URI/cookies/status e não aplica cache da SPA à API. Dockerfile define `MOCK_API=false`. |

O funcionário fixo e o envio de `funcionarioId` foram removidos **após** constatar que `VendaService.createVenda` passou a obter o responsável de `UsuarioAtual`. O formato legado da edição de data permanece `AAAA-MM-DDT00:00:00`.

## Contratos conferidos no código publicado

| Endpoint | Consumo no frontend |
|---|---|
| `GET /api/auth/csrf` | `{token,headerName}`; memória apenas. Query de descarte de cache evita cabeçalho extra no CORS de desenvolvimento. |
| `POST /api/auth/login`, `GET /api/auth/me` | `{usuario:{id,pessoaId,nome,perfil}}`. O parser também aceita usuário direto, para compatibilidade. O cookie `SESSION` é administrado pelo navegador; Dart não o lê. |
| `POST /api/auth/logout` | `204` ou `401` encerram localmente; falha de rede também limpa a tela, com aviso de que a revogação não foi confirmada. CSRF é renovado em seguida. |
| `POST /api/auth/registro-cliente` | CPF, código, login e senha; sucesso `201`, seguido de login manual. Login com 3–50 caracteres permitidos e senha com 8–72, conforme `auth/Dtos.java`. |
| `POST /api/clientes/{id}/convite` | `{codigo,expiraEm}`; instante convertido para hora local. Sem código em URL, persistência ou logs. |
| `GET /api/usuarios`, `PATCH /api/usuarios/{id}/ativo` | Envelope paginado e `{ativo}`. A própria conta não oferece botão de desativação na interface. |
| `POST /api/auth/funcionarios` | Obrigatórios: nome, CPF, cargo, login e senha. Opcionais: email, telefone, endereço e matrícula. Sem seletor de perfil. |
| `GET /api/historico`, `/api/me/historico` | `{content,number,size,totalElements,totalPages,first,last}`; itens `{id,tipo,mensagem,dataEnvio,destinatario}`. Sem campo `lida` ou operações de leitura. |
| `GET /api/me/vendas`, `/dividas`, `/pagamentos` | DTOs existentes em envelope paginado. Sem parâmetro de cliente. |
| `GET /api/auditoria` | Ator `{usuarioId,login,perfil}`, recurso `{tipo,id}` e `alteracoes` como string JSON. Filtros `inicio,fim,acao,recursoTipo,page,size`. |

Não existe `/api/me/resumo`: o resumo percorre páginas de 100 dívidas, limitado a 1.000 registros, com aviso se parcial. Datas de vencimento/emissão/pagamento preservam o dia; instantes de Histórico, Auditoria e convite são exibidos no horário local.

O endpoint real de contas ainda não aceita busca. A busca remota aparece apenas na simulação, onde é implementada; na API real a lista usa paginação. Para disponibilizá-la, o backend precisa documentar e implementar o parâmetro de busca e aplicar o filtro antes da contagem.

`SecurityConfig` já permite fiadores e operação de clientes para gerente/funcionário. A criação de funcionário foi habilitada após o DTO aparecer. O frontend não usa mais `/api/notificacoes` nem os antigos PATCH de leitura. Nenhum WebSocket foi adicionado.

A assinatura de `GoRouter`, incluindo `redirect` e `refreshListenable`, foi conferida na [documentação do pacote](https://pub.dev/documentation/go_router/latest/go_router/GoRouter-class.html) e validada pelos testes com a versão instalada.

## Simulação e testes

`dev/fakes.dart` implementa um transporte HTTP de desenvolvimento: três perfis, dois clientes com dados diferentes, envelopes, erros controlados, latência, vendas, recebimentos e convites. As telas continuam usando os mesmos repositórios HTTP; não há caminho de produção que selecione a simulação sem `MOCK_API=true`. O app recusa essa opção em release. O estado simulado é volátil; recarregar restaura a sessão somente quando existe cookie na API real.

Os testes na VM cobrem CSRF, headers, URLs, timeout sem repetição de mutação, status/HTML, época de sessão, permissões, `next`, datas e limites, paginação, respostas fora de ordem, filtros/retry, logout com falha de rede, polling/visibilidade, menus, isolamento A/B, convites, ativação e gestão de acesso. A suíte também percorre 14 telas em 360, 390, 768, 1024 e 1280 px e abre os diálogos de operação em 360 px.

Referências visuais de login estão em `../test/goldens/`. Foram geradas pela VM com fonte de teste Ahem; não substituem revisão no navegador com fontes reais. Não houve captura anterior do app nem instalação de Chrome. A revisão dos espaçamentos está em [espacamentos.md](espacamentos.md).

Comandos reproduzíveis:

```bash
flutter pub get --offline
flutter analyze
flutter test --concurrency=1
flutter build web --release --dart-define=MOCK_API=false
bash scripts/verify_nginx.sh
```

Resultados da execução anterior à retomada:

| Verificação | Resultado |
|---|---|
| `flutter pub get --offline` | Aprovado; lock local preservado |
| `flutter analyze` | Aprovado, sem avisos |
| `flutter test` | Aprovado: 54 testes, incluindo cinco referências visuais |
| `flutter build web --release --dart-define=MOCK_API=false` | Aprovado; permanece somente o aviso de fonte já existente na linha de base |
| Marcadores de simulação no `main.dart.js` | Ausentes: marcador do ambiente e três identificadores de fixture conferidos |
| `bash scripts/verify_nginx.sh` | Aprovado com upstream simulado; recursos temporários removidos |
| `git diff --check` do frontend | Aprovado |
| Validação integrada completa com API real | Pendente, conforme a seção seguinte |

Na rodada final, um limite externo de 55 segundos interrompeu a compilação dos testes enquanto havia um build concorrente. Após terminar o build, a suíte sem esse limite passou integralmente; não há falha de teste pendente.

`verify_nginx.sh` cria e remove recursos Docker próprios. Usa upstream simulado e confere sintaxe, fallback SPA, URI intacta, JSON, `Set-Cookie`, cache do upstream e erro 401. Ele não sobe o Compose nem altera a API real. O teste foi adaptado para Docker Desktop: o arquivo temporário do upstream é copiado para o contêiner com `docker cp`, pois `/tmp` não estava compartilhado com a VM.

## Limite da integração real

Foi observado `GET http://localhost:18080/api/auth/csrf` da API real de testes: JSON, `Cache-Control: no-store`, cookie com `HttpOnly` e `SameSite=Lax`. O contêiner `cadtest-api` foi removido pela outra sessão antes da sequência de login/consultas/logout. A tentativa seguinte terminou com `no such object: cadtest-api`. A porta padrão 8080 também estava indisponível.

Por isso, **não está aprovada a validação integrada da seção 12 do plano compartilhado**. A conclusão exige ambiente estável com backend + MySQL e quatro contas de desenvolvimento, nginx na mesma origem e navegador disponível para confirmar sessão/cookie, CSRF, operações financeiras, autorização direta, isolamento, convites, Auditoria e responsividade com fontes reais. Os resultados relatados pelo documento do backend pertencem à outra sessão; não foram apresentados aqui como execução do frontend.

Pesquisa do bot concluída como documento: [bot-recomendacao.md](bot-recomendacao.md). Nenhuma mensagem foi enviada nem integração externa configurada.

## Retomada após a interrupção

A conferência dos anexos e arquivos confirmou que a implementação principal e os registros anteriores de 54 testes, análise e build já estavam salvos. O plano recebido na retomada é idêntico ao anexo anterior; foi publicado no projeto para servir como referência única.

Ajustes concluídos nesta retomada:

- O Histórico na primeira página agora se atualiza também com filtros ativos, preservando tipo, período e tamanho. Páginas posteriores continuam na posição atual e oferecem o banner de novos eventos. Um teste de comportamento verifica que uma nova compra aparece sem perder o filtro selecionado.
- O rascunho `../../docs/contrato-auth-e-estimativas.md` passou a ser um registro histórico das estimativas, com referência ao contrato vigente; propostas incompatíveis de JWT e CSRF por cookie não são mais instruções de implementação.
- A linha de base de `../../docs/integracao-frontend.md` foi preservada e aponta para este relatório consolidado. O plano detalhado do frontend também foi alinhado à regra de atualização da primeira página.

O usuário relatou travamento da máquina e suspeita de relação com Docker. A causa não foi diagnosticada. Não foi feita nova execução do Docker nesta retomada. As verificações do Flutter são sequenciais, com testes usando `--concurrency=1`; o build usa `--no-wasm-dry-run` para evitar uma compilação de verificação Wasm que não faz parte da entrega JavaScript.

A Biblioteca de Software citada no caminho Windows do plano não foi encontrada neste ambiente Fedora. Não atribuí decisões aos livros nem declarei consulta aos materiais ausentes. Foi identificado Edge via Flatpak, mas não foi iniciada nova sessão de navegador nesta retomada. A validação com navegador e API real permanece pendente.

Verificações já concluídas na retomada:

| Comando/verificação | Resultado |
|---|---|
| `flutter test --concurrency=1` | Aprovado: 55 testes, incluindo o novo caso de Histórico com filtro ativo |
| `flutter analyze` | Aprovado, sem avisos |
| `flutter build web --release --no-wasm-dry-run --dart-define=MOCK_API=false` | Aprovado em 27,9 s; permaneceu somente o aviso de fonte da linha de base |
| Marcadores de simulação no JavaScript | Quatro marcadores conferidos, todos ausentes |
| Comparação SHA-256 dos arquivos protegidos | Backend, `docker-compose.yml` e `pubspec.lock` inalterados desde o início desta retomada |

Arquivos alterados na retomada: `lib/pages/historico_page.dart`, `test/app_test.dart`, `README.md`, este relatório, `../../docs/plano-execucao-frontend.md`, `../../docs/contrato-auth-e-estimativas.md` e `../../docs/integracao-frontend.md`. Novo arquivo: `../../docs/plano-execucao-caderneta-atualizado.md`, copiado do anexo do usuário. Os demais arquivos de implementação foram preservados da execução anterior.

Nenhum comando Docker foi executado nesta retomada. Não houve commit, push, troca de branch nem atualização de submódulos. O trabalho de implementação do frontend está concluído; a validação integrada com API real e navegador continua explicitamente pendente.
