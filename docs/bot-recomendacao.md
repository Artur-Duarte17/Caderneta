# Lembretes fora da aplicação — avaliação preliminar

Pesquisa de 05/11/2026, limitada ao escopo F12. Nenhum bot foi implementado ou conectado.

| Canal | Custo e dependências | Limites e risco operacional |
|---|---|---|
| WhatsApp Business Platform | Cobrança por mensagem entregue, conforme mercado e categoria; cotar a tabela brasileira e eventuais taxas do provedor. Requer conta empresarial, número habilitado, credencial da API e configuração de mensagens. | Aprovação e classificação de mensagens, alterações de preço e dependência da plataforma. Não usar automação de WhatsApp pessoal. [Meta](https://whatsappbusiness.com/products/platform-pricing/) |
| Telegram Bot API | Mensagens comuns gratuitas dentro dos limites; infraestrutura própria a dimensionar. Requer bot criado no BotFather, token no servidor e vínculo entre conta e chat. | O cliente precisa iniciar a conversa com o bot. Escalonar envios e tratar limites/429; não enviar em grupos. [Introdução](https://core.telegram.org/bots), [limites](https://core.telegram.org/bots/faq#how-do-i-avoid-hitting-limits) |
| E-mail transacional | Exemplo de referência: SES Essentials, US$ 0,16 por 1.000 e-mails no primeiro patamar; verificar plano, região e extras antes de contratar. Requer domínio verificado, DNS de autenticação e credencial de envio no servidor. | Endereço confirmado, devoluções, spam e reputação do domínio; entrega não garante leitura. [Preço oficial](https://aws.amazon.com/ses/pricing/) |
| Web Push | Dimensionar servidor e eventual provedor; requer HTTPS, service worker, chaves de envio e inscrição do navegador. | Permissão por dispositivo, compatibilidade e inscrições revogadas; entrega varia conforme navegador. [Push API](https://developer.mozilla.org/en-US/docs/Web/API/Push_API) |

Recomendação técnica: testar Telegram com um grupo pequeno de clientes que aceitem o canal. Se a adoção for baixa, avaliar e-mail com endereços confirmados e, depois, WhatsApp com orçamento aprovado. O Histórico e a área do cliente seguem independentes dessas decisões.

No futuro piloto, vincular o canal à conta autenticada por código de uso único; telefone ou CPF sozinhos não comprovam identidade. Enviar aviso genérico com link para entrar na Caderneta, sem valores, CPF, senha ou código de convite na mensagem. Tokens e credenciais ficam somente no servidor. Deduplicar por dívida, tipo e data; conferir o saldo antes do envio e respeitar preferências de horário e cancelamento.

Registrar a escolha do canal, finalidade e possibilidade de cancelamento. O responsável pelo tratamento deve definir a base legal, retenção e acesso aos registros antes do piloto; consentimento é uma das hipóteses da LGPD, não a única. Referência: [perguntas frequentes da ANPD](https://www.gov.br/anpd/pt-br/acesso-a-informacao/perguntas-frequentes/perguntas-frequentes).
