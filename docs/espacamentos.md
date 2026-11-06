# Revisão de espaçamentos e responsividade

Verificação de 05/11/2026. Mantidas paleta e tipografia do projeto.

| Origem | Ajuste |
|---|---|
| `Gap.md - 4` em cards e conteúdo | `Gap.ms` (12) |
| `Gap.lg - 4` e `Gap.md + 4` | `Gap.ml` (20) |
| `Gap.xl * 1.5` em estado vazio | `Gap.xxl` (48) |
| Padding 10/4 em `Pill` | `Gap.ms`/`Gap.xs` |
| Espaçamento de 2 em cards/recebimentos | `Gap.xs` |
| Padding vertical 6 em informações | `Gap.sm` |
| Padding de campos 12/14 | `Gap.ms`/`Gap.md` |
| Botões secundários de 40 px | Altura mínima 44 px |
| Snackbar com largura fixa de 420 | Largura adaptada à tela |

Não restam expressões aritméticas de espaçamento. Dimensões de avatar/ícones, larguras de campos/diálogos/tabelas e altura do gráfico não são espaçamentos; a altura do gráfico recebeu a constante `_alturaGrafico`. Zero em padding continua permitido para bordas sem espaço.

Correções funcionais de layout: menu com `Material` próprio; título da lateral ajustável; listas do menu com rolagem; painel sem cálculo intrínseco incompatível com a tabela; seletor de relatórios com rolagem horizontal; filtros limitados pela largura disponível; quantidade/valor de item com distribuição flexível; aviso de pagamento com texto que pode quebrar linha; método de pagamento expansível; diálogos de edição e recebimento com rolagem. Controladores dos formulários são descartados ao fechar.

Os testes percorrem 14 telas nas larguras 360, 390, 768, 1024 e 1280 px, além dos diálogos de cadastro, venda, edição, recebimento e funcionário em 360 px. O teste de edição também verifica que um conflito conserva o formulário e a mensagem.

As imagens em `../test/goldens/login-*.png` são referências da VM com fonte Ahem. Chrome/Chromium não estavam disponíveis: não há captura anterior nem validação visual com fontes de produção. Essa conferência segue pendente no navegador.
