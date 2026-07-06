# Facebook + Instagram — Meta Graph API (atualizado 2026)

Meta unificou o acesso: **um único app no Meta for Developers** cobre Facebook Pages e Instagram Business/Creator, ambos via **Graph API** (`graph.facebook.com`). Versão estável atual: v22.0 (Meta libera uma nova a cada trimestre, ~2 anos de suporte por versão).

## Pré-requisitos obrigatórios

- Conta pessoal do Facebook vinculada a uma **Página do Facebook** (não perfil pessoal).
- Conta do Instagram convertida para **Business ou Creator** (Configurações → Conta → Mudar para conta profissional). Contas pessoais **não têm acesso à API** desde o fim da Basic Display API (dez/2024).
- A conta Instagram Business precisa estar **conectada à Página do Facebook**.

## Passo a passo

### 1. Criar conta de desenvolvedor e app
1. Acesse https://developers.facebook.com e faça login com a conta vinculada à Página.
2. Complete o cadastro de desenvolvedor (verificação por SMS/e-mail).
3. Clique em **"Criar App"** → selecione o tipo **"Negócios"** (Business).
4. Preencha nome do app, e-mail de contato e associe à **Meta Business Portfolio** da HC Tech (crie uma em business.facebook.com se ainda não existir).

### 2. Adicionar produtos ao app
No painel do app, adicione:
- **Facebook Login** (gera o fluxo OAuth)
- **Instagram Graph API** (produto específico, não confundir com "Instagram Basic Display", que está descontinuado)

Anote o **App ID** e **App Secret** (Configurações → Básico).

### 3. Configurar permissões (scopes)
As permissões mais usadas para automação de conteúdo/leads:

| Permissão | Uso |
|---|---|
| `pages_show_list` | Listar Páginas administradas |
| `pages_read_engagement` | Ler métricas/engajamento da Página |
| `pages_manage_posts` | Publicar na Página |
| `instagram_basic` | Ler perfil/mídia do Instagram |
| `instagram_content_publish` | Publicar fotos/Reels/Stories/carrosséis |
| `instagram_manage_comments` | Ler/responder/moderar comentários |
| `instagram_manage_messages` | Ler/enviar DMs (regra das 24h após contato do usuário) |
| `instagram_manage_insights` | Métricas de performance |

### 4. Fluxo OAuth (Facebook Login)
1. Redirecionar o usuário para:
   `https://www.facebook.com/v22.0/dialog/oauth?client_id=APP_ID&redirect_uri=REDIRECT_URI&scope=pages_show_list,instagram_content_publish,...`
2. Usuário autoriza → Meta redireciona para `REDIRECT_URI?code=CODE`.
3. Trocar o `code` por `access_token`:
   ```
   GET https://graph.facebook.com/v22.0/oauth/access_token
     ?client_id=APP_ID
     &redirect_uri=REDIRECT_URI
     &client_secret=APP_SECRET
     &code=CODE
   ```
4. Trocar o token de curta duração por um de **longa duração** (60 dias):
   ```
   GET https://graph.facebook.com/v22.0/oauth/access_token
     ?grant_type=fb_exchange_token
     &client_id=APP_ID
     &client_secret=APP_SECRET
     &fb_exchange_token=SHORT_LIVED_TOKEN
   ```
5. Obter o **Page Access Token** (não expira, desde que o token de usuário longo esteja válido):
   ```
   GET https://graph.facebook.com/v22.0/me/accounts?access_token=LONG_LIVED_USER_TOKEN
   ```
6. Obter o **Instagram Business Account ID** vinculado à Página:
   ```
   GET https://graph.facebook.com/v22.0/{page-id}?fields=instagram_business_account&access_token=PAGE_ACCESS_TOKEN
   ```

### 5. Publicar conteúdo no Instagram (exemplo: foto única)
Publicação é em 2 etapas — criar container de mídia, depois publicar:
```
POST https://graph.facebook.com/v22.0/{ig-user-id}/media
  image_url=URL_DA_IMAGEM
  caption=TEXTO
  access_token=PAGE_ACCESS_TOKEN

POST https://graph.facebook.com/v22.0/{ig-user-id}/media_publish
  creation_id=ID_RETORNADO_ACIMA
  access_token=PAGE_ACCESS_TOKEN
```

### 6. Publicar na Página do Facebook
```
POST https://graph.facebook.com/v22.0/{page-id}/feed
  message=TEXTO
  access_token=PAGE_ACCESS_TOKEN
```

### 7. App Review (obrigatório para produção)
Qualquer permissão além de `public_profile`/`email` exige revisão da Meta:
- Justificativa detalhada de uso para cada permissão.
- Screencast mostrando o fluxo real usando a permissão.
- Política de privacidade pública.
- Prazo típico: 1 a 4 semanas por submissão. Rejeições mais comuns: justificativa vaga, vídeo que não mostra o uso real, permissão não condizente com o app.
- Até a aprovação, o app funciona só com até 25 usuários de teste (adicionados manualmente em Funções → Testadores).

## Limites e boas práticas
- Rate limit padrão: ~200 chamadas/hora por app (varia por endpoint).
- Sempre tratar erro `190` (token inválido/expirado) e `429` (rate limit) com retry exponencial.
- Nunca versionar tokens/App Secret no Git — usar `.env`.
- Webhooks (Configurações → Webhooks) são a forma correta de receber comentários/mensagens em tempo real, evitando polling.

## Erros comuns
- `(#10) Application does not have permission for this action` → permissão não aprovada no App Review ou conta de teste não adicionada.
- Instagram sem `instagram_business_account` no retorno → conta não está conectada à Página ou não é Business/Creator.
