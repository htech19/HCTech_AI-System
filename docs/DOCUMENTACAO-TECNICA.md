# Documentação Técnica — HC Tech AI System v2.1

## 1. Visão Geral

Sistema de gestão com IA para a **HC Tech InfoCell** (assistência técnica de smartphones e notebooks, São Bernardo do Campo / Grande ABC, MEI desde 2011, site: [hctechinfocell.com.br](https://www.hctechinfocell.com.br)).

Arquitetura: **backend FastAPI (Python 3.12)** + **frontend Next.js 14** + **5 agentes de IA** armazenados no banco de dados, com suporte híbrido a Ollama (local), OpenAI e Anthropic.

## 2. Arquitetura de pastas

```
backend/app/
  main.py              - registra todos os routers, CORS, startup (seed do banco)
  config.py            - Settings via pydantic-settings, le .env na raiz
  database.py          - modelos SQLAlchemy async (Agent, Conversation, ...) + seed inicial
  api/
    auth.py            - /api/auth
    ai.py              - /api/ai (chamada direta de IA, sem agente associado)
    agents.py          - /api/agents (CRUD, historico, PATCH de comportamento)
    tasks.py           - /api/tasks (Kanban)
    seo.py             - /api/seo
    social.py          - /api/social
    maps.py            - /api/maps
    knowledge.py        - /api/knowledge
    reports.py         - /api/reports
    metrics.py         - /api/metrics
    automation.py      - /api/automation (APScheduler)
    integrations.py    - /api/integrations
  services/
    ai_service.py      - roteia a chamada para Ollama/OpenAI/Anthropic conforme ai_provider

frontend/src/
  app/                 - layout.tsx, page.tsx, globals.css (App Router)
  components/layout/   - Sidebar, Header
  components/pages/    - DashboardPage, AgentsPage, SEOPage, SocialPage, MapsPage,
                         KnowledgePage, ReportsPage, KanbanPage, AutomationPage,
                         SettingsPage, IntegrationsPage
  lib/api.ts           - cliente HTTP (axios) para o backend
  store/useAppStore.ts - estado global (Zustand)
```

## 3. Modelo de dados dos agentes (`database.py`)

Cada agente é uma linha na tabela `Agent`, com os campos:

| Campo | Tipo | Descrição |
|---|---|---|
| `id` | str | Identificador único (ex: `hc-seo`) |
| `name` | str | Nome de exibição (ex: `HC-SEO`) |
| `role` | str | Papel/título curto |
| `description` | str | Descrição exibida na UI |
| `system_prompt` | text | Instrução de sistema enviada à IA a cada chamada |
| `avatar` | str | Ícone/emoji exibido |
| `color` | str | Cor de destaque na UI |
| `is_active` | bool | Se o agente aparece habilitado |
| `ai_provider` | str | `ollama` \| `openai` \| `anthropic` |

**Importante:** não existe `ollama create` nem Modelfile custom no fluxo real do sistema. O comportamento do agente é 100% definido pelo campo `system_prompt`, injetado em runtime pelo `ai_service.py` a cada chamada — trocar a "personalidade" de um agente é uma atualização de banco de dados, não de modelo.

## 4. Fluxo de uma chamada de agente

1. Frontend (`AgentsPage`) envia mensagem do usuário para `POST /api/ai` (ou endpoint equivalente) informando `agent_id`.
2. Backend busca o agente no banco (`system_prompt`, `ai_provider`).
3. `ai_service.py` monta o payload (system + histórico + mensagem nova) e chama:
   - Ollama: `POST {OLLAMA_API_URL}/api/chat`
   - OpenAI: SDK oficial (`openai>=1.50.0`)
   - Anthropic: SDK oficial (`anthropic>=0.40.0`)
4. Resposta é salva em `Conversation` e devolvida ao frontend.

## 5. Como alterar o comportamento de um agente

**Via API (recomendado, sem código):**
```bash
curl -X PATCH http://localhost:8000/api/agents/hc-seo \
  -H "Content-Type: application/json" \
  -d '{"system_prompt": "Novo system prompt aqui...", "ai_provider": "ollama"}'
```

**Via tela de configurações** no frontend (`SettingsPage` / `AgentsPage`), que chama o mesmo endpoint.

**Via script** (para aplicar treinamento em lote): ver `scripts/treinar_agentes_hctech.py`.

## 6. Variáveis de ambiente (`.env` na raiz)

| Variável | Padrão | Descrição |
|---|---|---|
| `OLLAMA_API_URL` | `http://localhost:11434` | Endpoint do Ollama local |
| `OLLAMA_MODEL` | `llama3.2:3b` | Modelo padrão quando `ai_provider=ollama` |
| `OLLAMA_TIMEOUT` | `120` | Timeout em segundos |
| `OPENAI_API_KEY` | (vazio) | Necessária se algum agente usar `ai_provider=openai` |
| `OPENAI_MODEL` | `gpt-4o-mini` | |
| `ANTHROPIC_API_KEY` | (vazio) | Necessária se algum agente usar `ai_provider=anthropic` |
| `ANTHROPIC_MODEL` | `claude-3-haiku-20240307` | |
| `DEFAULT_AI_PROVIDER` | `ollama` | Provedor usado quando não especificado |
| `DATABASE_URL` | `sqlite+aiosqlite:///./data/hctech.db` | |
| `SECRET_KEY` | `change-me-in-production` | **Trocar em produção** |
| `BACKEND_PORT` | `8000` | |
| `FRONTEND_PORT` | `3000` | |

## 7. Deploy / produção (pendente de decisão)

O sistema hoje roda 100% local (SQLite, sem autenticação real habilitada por padrão, `SECRET_KEY` de exemplo). Antes de expor publicamente:
1. Trocar `SECRET_KEY` por um valor forte e único.
2. Avaliar migração de SQLite para PostgreSQL se houver acesso concorrente.
3. Configurar HTTPS (reverse proxy — Nginx/Caddy) na frente do backend/frontend.
4. Revisar CORS em `main.py` para restringir origens em produção.

## 8. Scripts auxiliares (raiz do projeto)

| Script | Função |
|---|---|
| `Instalar-HCTechAI.ps1` | Instalação completa em máquina Windows limpa (winget + clone + deps + .env + modelo) |
| `Validar-Sync.ps1` | Compara estado local do Git com o GitHub (commits pendentes, arquivos não commitados) |
| `Limpar-Repo.ps1` | Remove do rastreamento do Git arquivos que não deveriam estar versionados |
| `setup.ps1` | Instala dependências assumindo pré-requisitos (Python/Node/Ollama) já presentes |
| `iniciar.ps1` / `iniciar_completo.bat` | Sobe Ollama + Backend + Frontend, path auto-resolvido |
| `bootstrap.ps1` | Recria a estrutura do projeto do zero (uso raro, manutenção) |
| `scripts/treinar_agentes_hctech.py` | Aplica os system prompts especializados no negócio real via API |
