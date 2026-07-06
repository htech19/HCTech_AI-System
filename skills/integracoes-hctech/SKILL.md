---
name: integracoes-hctech
description: >-
  Guia passo a passo para habilitar e configurar integracoes de API com Facebook, Instagram, Mercado Livre, Google Maps e Google Meu Negocio (Google Business Profile) para o ecossistema HC Tech. Use sempre que o usuario pedir para conectar, integrar, configurar, criar app ou aplicacao, obter token, autenticar ou publicar via API nessas plataformas, mesmo sem usar a palavra integracao explicitamente. Tambem aciona para duvidas sobre OAuth, App Review da Meta, DevCenter do Mercado Livre, ou aprovacao de acesso a Business Profile API.
---

# Integrações de API — Ecossistema HC Tech

Guia de referência para conectar o HC-TECH-AI (agentes HC-SEO, HC-CONTENT, HC-LEADS) às plataformas externas usadas pela HC Tech InfoCell: Facebook, Instagram, Mercado Livre, Google Maps e Google Meu Negócio (Google Business Profile).

## Como usar este guia

Cada plataforma tem um arquivo de referência dedicado em `references/`. Leia apenas o arquivo relevante à tarefa pedida — não carregue todos de uma vez.

| Plataforma | Arquivo | Quando usar |
|---|---|---|
| Facebook + Instagram (Meta Graph API) | `references/facebook-instagram.md` | Publicar posts, ler insights, gerenciar comentários/DMs em Página do Facebook ou conta Instagram Business |
| Mercado Livre | `references/mercado-livre.md` | Publicar anúncios, gerenciar pedidos/perguntas, sincronizar catálogo |
| Google Maps Platform | `references/google-maps.md` | Geocodificação, exibição de mapas, cálculo de distância/rotas, autocomplete de endereço |
| Google Meu Negócio (Business Profile API) | `references/google-business-profile.md` | Gerenciar ficha da empresa, responder avaliações, publicar posts na ficha, métricas de performance local |

## Princípios comuns a todas as integrações

1. **Nunca hardcode credenciais.** Client ID/Secret, App Secret e tokens sempre em variáveis de ambiente (`.env`), nunca commitados no Git.
2. **Tokens de longa duração sempre que disponível.** Curto prazo é só para teste manual.
3. **Todo fluxo de autenticação é OAuth 2.0** nas 4 plataformas — o padrão é: usuário autoriza → você recebe um `code` → troca o `code` por `access_token` (+ `refresh_token` quando aplicável).
4. **Sempre implemente refresh automático de token** antes de expirar (rotina agendada ou lazy-refresh na primeira falha 401).
5. **Rate limits existem em todas.** Implemente retry com backoff exponencial e cache local quando possível.
6. **Contas de teste primeiro.** Nunca testar fluxo de autorização direto na conta de produção da HC Tech.

## Fluxo recomendado ao pedir uma integração nova

1. Identificar a plataforma e o objetivo (ex: "publicar produto no ML" vs "responder avaliação no Google").
2. Ler o `references/*.md` correspondente.
3. Levantar com o usuário: já existe app/projeto criado nessa plataforma? Já tem credenciais? Está em produção ou teste?
4. Gerar o código de integração (Node.js/Python conforme stack do HC-TECH-AI) já com tratamento de erro, refresh de token e logging — seguindo os padrões do projeto (arquivos completos, prontos para produção, logging persistente).
5. Nunca prometer que a aprovação de acesso (App Review da Meta, aprovação da Business Profile API) é imediata — avisar prazos reais quando relevante.

## Próximos passos após configurar credenciais

Depois que o usuário tiver `client_id`/`client_secret`/tokens de qualquer plataforma, o próximo passo natural é gerar o código de integração real (endpoint de autenticação, wrapper de chamadas, webhook receiver) — ofereça isso proativamente em vez de só explicar o conceito.
