# HC Tech AI System v2.1

> Plataforma Hibrida Local/Online de IA para Assistencias Tecnicas

Sistema de gestao com 5 agentes de IA para a HC Tech (assistencia tecnica de smartphones), com backend em FastAPI/Python e frontend em Next.js, suportando IA local (Ollama) ou em nuvem (OpenAI/Anthropic) por agente.

**Repositorio:** https://github.com/htech19/HCTech_AI-System

---

## Arquitetura real



## Stack real

| Camada | Tecnologia |
|---|---|
| Backend | FastAPI 0.115, Uvicorn, SQLAlchemy 2.0 (async), aiosqlite |
| Frontend | Next.js 14.2.5 (App Router), React 18.3, TypeScript, Tailwind CSS |
| Estado (frontend) | Zustand |
| Dados remotos (frontend) | @tanstack/react-query, axios |
| Banco de dados | SQLite (data/hctech.db) |
| IA | Hibrida: Ollama (local, padrao) ou OpenAI ou Anthropic - por agente, via campo ai_provider |
| Agendamento | APScheduler |
| Logging | Loguru |

## Os 5 agentes (dados reais, semeados em database.py)

| ID | Nome | Papel | Provedor padrao |
|---|---|---|---|
| hc-ceo | HC-CEO | Coordenador Estrategico | ollama |
| hc-seo | HC-SEO | Especialista em SEO local / Google Maps | ollama |
| hc-social | HC-SOCIAL | Gestor de Redes Sociais (Facebook/Instagram) | ollama |
| hc-content | HC-CONTENT | Criador de Conteudo / Copywriting | ollama |
| hc-code | HC-CODE | Desenvolvedor & Automacao | ollama |

Cada agente e uma linha no banco de dados, nao um modelo customizado do Ollama. O system_prompt e o ai_provider de cada um podem ser editados via PATCH /api/agents/{agent_id}, direto na tela de configuracoes do frontend. Nao e necessario `ollama create` para nenhum agente - o backend chama a API do Ollama (ou OpenAI/Anthropic) em runtime, injetando o system_prompt armazenado.

## Como rodar

### Pre-requisitos
- Python 3.12
- Node.js + npm
- Ollama instalado e com pelo menos um modelo baixado (padrao: llama3.2:3b)

### Subir tudo de uma vez
```powershell
.\iniciar_completo.bat
```
Sobe, nesta ordem: Ollama -> Backend FastAPI (porta 8000) -> Frontend Next.js (porta 3000) -> abre o navegador.

### Rodar manualmente (debug)
```powershell
# Terminal 1 - Backend
cd backend
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

# Terminal 2 - Frontend
cd frontend
npm install
npm run dev
```

### URLs
| Servico | URL |
|---|---|
| Frontend | http://localhost:3000 |
| API | http://localhost:8000 |
| Docs (Swagger) | http://localhost:8000/docs |
| Health check | http://localhost:8000/api/health |
| Ollama | http://localhost:11434 |

## Configuracao (.env na raiz)

```env
OLLAMA_API_URL=http://localhost:11434
OLLAMA_MODEL=llama3.2:3b
OLLAMA_TIMEOUT=120

OPENAI_API_KEY=
OPENAI_MODEL=gpt-4o-mini

ANTHROPIC_API_KEY=
ANTHROPIC_MODEL=claude-3-haiku-20240307

DEFAULT_AI_PROVIDER=ollama

DATABASE_URL=sqlite+aiosqlite:///./data/hctech.db
SECRET_KEY=troque-em-producao

BACKEND_PORT=8000
FRONTEND_PORT=3000
```

## Modulos da API (backend/app/api/)

| Router | Prefixo | Funcao |
|---|---|---|
| auth | /api/auth | Autenticacao |
| ai | /api/ai | Chamadas diretas de IA |
| agents | /api/agents | CRUD dos agentes e historico de conversas |
| tasks | /api/tasks | Kanban de tarefas |
| seo | /api/seo | Keywords e rankings |
| social | /api/social | Posts de redes sociais |
| maps | /api/maps | Google Maps / Business Profile |
| knowledge | /api/knowledge | Base de conhecimento |
| reports | /api/reports | Relatorios gerados |
| metrics | /api/metrics | Metricas gerais |
| automation | /api/automation | Jobs agendados (APScheduler) |
| integrations | /api/integrations | Integracoes externas (Facebook, ML, Maps) |

## Convencoes do projeto

- Scripts .ps1/.bat: resolucao de path dinamica ($PSScriptRoot / %~dp0), nunca caminho absoluto fixo.
- Entrega de arquivos completos e prontos para uso.
- Tema escuro como padrao (frontend usa bg-slate-950 como base).
- Agentes: alteracoes de comportamento (system_prompt) via API/tela de configuracoes, nao via Modelfile do Ollama.