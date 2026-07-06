# Mercado Livre — API oficial (DevCenter)

Base da API: `https://api.mercadolibre.com` | Autorização: `https://auth.mercadolivre.com.br` (Brasil)

## Passo a passo

### 1. Criar a aplicação
1. Acesse https://developers.mercadolivre.com.br/devcenter e faça login com a conta **da mesma pessoa jurídica** que será usada na integração (recomendado: conta PJ, não PF — evita problemas de transferência futura).
2. Clique em **"Criar nova aplicação"**.
3. Preencha:
   - **Nome**: único na plataforma.
   - **Descrição**: até 150 caracteres, exibida na tela de autorização.
   - **Logo**: obrigatório.
   - **URI de redirect**: URL HTTPS do seu backend que vai receber o `code` (ex: `https://hctechinfocell.com.br/ml/callback`). Não pode conter query string variável.
   - **Escopos**: marcar todos os necessários (leitura/escrita de itens, pedidos, perguntas). Para automação completa (catálogo + vendas), marcar tudo.
   - **Tópicos** (webhooks): marcar pelo menos `orders_v2` (novos pedidos) e `questions` (novas perguntas). Informar a **URL de callback de notificações** — endpoint HTTPS que vai receber POSTs do ML.
4. Ao salvar, você recebe **Client ID (App ID)** e **Client Secret**. Guarde com segurança — nunca em texto plano no repositório.

> Em Brasil, Argentina, México e Chile, só é permitido criar 1 aplicação por conta após validação dos dados do titular.

### 2. Fluxo OAuth 2.0 (Authorization Code)
1. Redirecionar o usuário (a própria conta vendedora HC Tech) para:
   ```
   https://auth.mercadolivre.com.br/authorization?response_type=code&client_id=CLIENT_ID&redirect_uri=REDIRECT_URI&state=RANDOM_ID
   ```
   O parâmetro `state` é opcional mas recomendado (proteção contra CSRF) — o Mercado Livre não valida esse campo, então valide você mesmo ao receber o retorno.
2. Usuário autoriza → redirecionado para:
   ```
   REDIRECT_URI?code=CODE&state=RANDOM_ID
   ```
3. Trocar `code` por `access_token`:
   ```bash
   curl -X POST 'https://api.mercadolibre.com/oauth/token' \
     -H 'accept: application/json' \
     -H 'content-type: application/x-www-form-urlencoded' \
     -d 'grant_type=authorization_code' \
     -d 'client_id=CLIENT_ID' \
     -d 'client_secret=CLIENT_SECRET' \
     -d 'code=CODE' \
     -d 'redirect_uri=REDIRECT_URI'
   ```
   Resposta:
   ```json
   {
     "access_token": "APP_USR-...",
     "token_type": "bearer",
     "expires_in": 21600,
     "scope": "offline_access read write",
     "user_id": 123456,
     "refresh_token": "TG-..."
   }
   ```
4. **`access_token` expira em 6 horas (21600s).** Renovar com o `refresh_token`:
   ```bash
   curl -X POST 'https://api.mercadolibre.com/oauth/token' \
     -H 'accept: application/json' \
     -H 'content-type: application/x-www-form-urlencoded' \
     -d 'grant_type=refresh_token' \
     -d 'client_id=CLIENT_ID' \
     -d 'client_secret=CLIENT_SECRET' \
     -d 'refresh_token=REFRESH_TOKEN'
   ```
   O `refresh_token` em si expira em **6 meses** — se isso ocorrer, é necessário refazer o fluxo de autorização completo.

### 3. Chamadas autenticadas
```bash
curl -H 'Authorization: Bearer APP_USR-...' https://api.mercadolibre.com/users/me
```

### 4. Endpoints mais usados na operação HC Tech
| Ação | Endpoint |
|---|---|
| Publicar/editar item | `POST /items` / `PUT /items/{id}` |
| Listar pedidos | `GET /orders/search?seller=USER_ID` |
| Responder pergunta | `POST /answers` |
| Atualizar estoque | `PUT /items/{id}` (campo `available_quantity`) |
| Upload de imagem | `POST /pictures/items/upload` |

### 5. Webhooks (notificações)
- O ML faz `POST` no endpoint configurado sempre que houver evento nos tópicos marcados (ex: novo pedido).
- **Validar a origem** da notificação e responder `200 OK` rapidamente (o ML reenvia se não receber resposta em tempo hábil).
- Ao receber a notificação, buscar o recurso completo via `GET` no `resource` informado no payload — a notificação em si só avisa, não traz o dado completo.

## Boas práticas de segurança (recomendação oficial do ML)
- Enviar `client_secret` sempre no **body**, nunca na query string.
- Renovar o Client Secret periodicamente via DevCenter (Configurações da app → "renovar agora" ou agendar renovação).
- Nunca compartilhar o Client Secret — nem em logs.

## Erros comuns
- `invalid_operator_user_id` → tentou autorizar com usuário colaborador/operador em vez da conta principal.
- `redirect_uri_mismatch` → a `redirect_uri` enviada não é idêntica, caractere por caractere, à cadastrada na aplicação.
- Token expirado no meio de uma rotina → implementar refresh automático antes de cada lote de chamadas, não apenas reativo ao erro 401.
