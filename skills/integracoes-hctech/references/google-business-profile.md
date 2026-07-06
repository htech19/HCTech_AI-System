# Google Meu Negócio — Business Profile API (atualizado 2026)

**Atenção:** diferente de Facebook/Instagram/ML/Maps, a Business Profile API **não é liberada automaticamente**. Todo projeto novo começa com cota **zero** e precisa de aprovação manual do Google. Planeje prazo — não é instantâneo.

## Pré-requisitos exigidos pelo Google
- Perfil da empresa (Google Business Profile) **verificado e ativo há 60+ dias**.
- Site comercial válido e publicamente acessível.
- Caso de uso legítimo (gerenciar o próprio perfil ou perfis de clientes).
- E-mail usado no pedido deve ser o mesmo listado como proprietário/gerente do perfil no GBP.

## Passo a passo

### 1. Criar projeto no Google Cloud Console
1. https://console.cloud.google.com → criar novo projeto.
2. Anotar o **Número do Projeto** (Project Number), exibido no card "Informações do projeto" do Dashboard — será pedido no formulário de solicitação de acesso.

### 2. Habilitar as APIs (mesmo antes da aprovação)
Em "APIs e Serviços" → "Biblioteca", habilitar as relevantes ao uso:
- **My Business Account Management API**
- **My Business Business Information API**
- **Business Profile Performance API** (métricas)
- **Reviews API** (`mybusiness.googleapis.com/v4`) — gerenciar avaliações

> A API de Perguntas e Respostas (Q&A) foi **descontinuada em novembro de 2025** — não depender mais dela para automação.

### 3. Solicitar acesso (obrigatório)
1. Preencher o formulário oficial de contato: https://developers.google.com/my-business/content/prereqs (link "GBP API contact form" na documentação oficial).
2. Selecionar **"Application for Basic API Access"**.
3. Informar: número do projeto, e-mail (deve ser owner/manager do GBP), caso de uso, site da empresa.
4. Aguardar retorno por e-mail. Para checar status sem esperar resposta: ver a cota das APIs em "APIs e Serviços" → "Cotas" — se estiver em **0 QPM**, ainda não aprovado; se **300 QPM**, aprovado.

### 4. OAuth 2.0 (após aprovação)
1. Em "Credenciais", criar um **ID do cliente OAuth 2.0** (tipo "Aplicativo da Web").
2. Configurar URI de redirecionamento autorizado.
3. Fluxo padrão OAuth 2.0 do Google:
   ```
   https://accounts.google.com/o/oauth2/v2/auth?
     client_id=CLIENT_ID&
     redirect_uri=REDIRECT_URI&
     response_type=code&
     scope=https://www.googleapis.com/auth/business.manage&
     access_type=offline&
     prompt=consent
   ```
4. Trocar `code` por tokens:
   ```bash
   curl -X POST https://oauth2.googleapis.com/token \
     -d client_id=CLIENT_ID \
     -d client_secret=CLIENT_SECRET \
     -d code=CODE \
     -d grant_type=authorization_code \
     -d redirect_uri=REDIRECT_URI
   ```
   `access_type=offline` garante o `refresh_token` para renovação sem novo login do usuário.

### 5. Usos mais relevantes para a HC Tech
| Ação | API |
|---|---|
| Listar localizações da conta | My Business Account Management API |
| Atualizar horário, endereço, telefone | My Business Business Information API |
| Responder avaliações de clientes | Reviews API (`mybusiness.googleapis.com/v4/accounts/{a}/locations/{l}/reviews/{r}/reply`) |
| Métricas de buscas/cliques/ligações | Business Profile Performance API |
| Publicar posts na ficha (promoções, novidades) | My Business Business Information API (recurso `localPosts`, sujeito a mudanças — checar changelog) |

### 6. Automação sem código próprio (alternativa mais rápida)
Se a aprovação demorar ou o volume não justificar manutenção própria, ferramentas como **n8n** ou **Make** já têm nós prontos para Google Business Profile — mais rápido para colocar em produção enquanto o acesso oficial é aprovado.

## Erros e pontos de atenção
- Cota 0 QPM mesmo após "aprovação" → geralmente falta habilitar a API específica no projeto correto (confirmar que o pedido foi feito com o Project Number do projeto certo).
- Regras de conteúdo dos posts/avaliações seguem as mesmas políticas da interface web — respostas falsas/incentivadas a avaliações violam os termos e podem suspender o acesso.
- Sempre checar o changelog oficial (developers.google.com/my-business, atualizado mensalmente) antes de assumir que um endpoint ainda está ativo — o Google tem descontinuado partes da API (ex: Q&A em nov/2025).
