# HC Tech AI System v2.1

> Plataforma Híbrida Local/Online de IA para Assistências Técnicas

Sistema de gestão com 5 agentes de IA para a HC Tech (assistência técnica de smartphones), com backend em **FastAPI/Python** e frontend em **Next.js**, suportando IA local (Ollama) ou em nuvem (OpenAI/Anthropic) por agente.

**Repositório:** https://github.com/htech19/HCTech_AI-System

---

## Arquitetura real

```
HC Tech AI System v2.1/
├── backend/                   # API FastAPI (Python 3.12)
│   ├── app/
│   │   ├── main.py            # Entry point, registra todas as rotas
│   │   ├── config.py          # Settings (pydantic-settings, le .env)
│   │   ├── database.py        # Modelos SQLAlchemy async + seed inicial
│   │   ├── api/                # Um router por dominio (agents, seo, social, maps...)
│   │   └── services/
│   │       └── ai_service.py  # Servico hibrido Ollama / OpenAI / Anthropic
│   └── requirements.txt
├── frontend/                   # Next.js 14 (App Router) + TypeScript
│   ├── src/
│   │   ├── app/                # layout.tsx, page.tsx, globals.css
│   │   ├── components/
│   │   │   ├── layout/         # Sidebar, Header
│   │   │   └── pages/          # DashboardPage, AgentsPage, SEOPage, SocialPage,
│   │   │                       # MapsPage, KnowledgePage, ReportsPage, KanbanPage,
│   │   │                       # AutomationPage, SettingsPage, IntegrationsPage
│   │   ├── lib/api.ts           # Cliente HTTP para o backend
│   │   └── store/useAppStore.ts # Estado global (Zustand)
│   └── package.json
├── data/hctech.db              # Banco SQLite (nao versionar - runtime)
├── scripts/                    # Automacoes PowerShell auxiliares
├── skills/                     # Skills de documentacao (integracoes, Ollama)
├── docs/                       # Documentacao tecnica
├── iniciar.ps1                 # Sobe Ollama + Backend + Frontend (auto-resolve path)
├── iniciar_completo.bat        # Equivalente em .bat
├── setup.ps1                   # Instala dependencias Python + Node + Ollama
└── bootstrap.ps1               # Recria a estrutura do projeto do zero (uso raro)
```

> A pasta `bkp/` contém uma cópia antiga e desatualizada da estrutura do backend/frontend — não é usada em runtime e não deveria estar versionada (ver seção Manutenção).

## Stack real

| Camada | Tecnologia |
|---|---|
| Backend | FastAPI 0.115, Uvicorn, SQLAlchemy 2.0 (async), aiosqlite |
| Frontend | Next.js 14.2.5 (App Router), React 18.3, TypeScript, Tailwind CSS |
| Estado (frontend) | Zustand |
| Dados remotos (frontend) | @tanstack/react-query, axios |
| Banco de dados | SQLite (`data/hctech.db`) |
| IA | Híbrida: Ollama (local, padrão) **ou** OpenAI **ou** Anthropic — por agente, via campo `ai_provider` |
| Agendamento | APScheduler |
| Logging | Loguru |

## Os 5 agentes (dados reais, semeados em `database.py`)

| ID | Nome | Papel | Provedor padrão |
|---|---|---|---|
| `hc-ceo` | HC-CEO | Coordenador Estratégico | ollama |
| `hc-seo` | HC-SEO | Especialista em SEO local / Google Maps | ollama |
| `hc-social` | HC-SOCIAL | Gestor de Redes Sociais (Facebook/Instagram) | ollama |
| `hc-content` | HC-CONTENT | Criador de Conteúdo / Copywriting | ollama |
| `hc-code` | HC-CODE | Desenvolvedor & Automação | ollama |

Cada agente é uma **linha no banco de dados**, não um modelo customizado do Ollama. O `system_prompt` e o `ai_provider` de cada um podem ser editados via `PATCH /api/agents/{agent_id}`, direto na tela de configurações do frontend. **Não é necessário `ollama create`** para nenhum agente — o backend chama a API do Ollama (ou OpenAI/Anthropic) em runtime, injetando o `system_prompt` armazenado.

## Como rodar (caminho real, testado no código)

### Pré-requisitos
- Python 3.12
- Node.js + npm
- Ollama instalado e com pelo menos um modelo baixado (padrão: `llama3.2:3b`)

### Setup inicial
```powershell
cd "HC Tech AI System v2.1"
.\setup.ps1
```
Isso instala dependências Python (`backend/requirements.txt`), dependências npm (`frontend/`), e baixa o modelo Ollama padrão.

### Subir tudo de uma vez
```powershell
.\iniciar.ps1
```
ou
```cmd
iniciar_completo.bat
```
Isso sobe, nesta ordem: Ollama (`ollama serve`, se não estiver rodando) → Backend FastAPI na porta 8000 → Frontend Next.js na porta 3000 → abre o navegador automaticamente.

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
| Serviço | URL |
|---|---|
| Frontend | http://localhost:3000 |
| API | http://localhost:8000 |
| Docs interativos (Swagger) | http://localhost:8000/docs |
| Health check | http://localhost:8000/api/health |
| Ollama | http://localhost:11434 |

## Configuração (.env na raiz)

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

## Módulos da API (`backend/app/api/`)

| Router | Prefixo | Função |
|---|---|---|
| `auth` | `/api/auth` | Autenticação |
| `ai` | `/api/ai` | Chamadas diretas de IA |
| `agents` | `/api/agents` | CRUD dos agentes e histórico de conversas |
| `tasks` | `/api/tasks` | Kanban de tarefas |
| `seo` | `/api/seo` | Keywords e rankings |
| `social` | `/api/social` | Posts de redes sociais |
| `maps` | `/api/maps` | Google Maps / Business Profile |
| `knowledge` | `/api/knowledge` | Base de conhecimento |
| `reports` | `/api/reports` | Relatórios gerados |
| `metrics` | `/api/metrics` | Métricas gerais |
| `automation` | `/api/automation` | Jobs agendados (APScheduler) |
| `integrations` | `/api/integrations` | Integrações externas (Facebook, ML, Maps) |

## Manutenção pendente (encontrada na auditoria do repositório)

1. **`.git` está com 64MB** por versionar `frontend/.next/` (85MB de build cache), `__pycache__/*.pyc` e `data/hctech.db`. Rode `Limpar-Repo.ps1` (script auxiliar) para desrastrear sem apagar do disco.
2. **Pasta `bkp/`** contém uma cópia antiga e divergente do backend/frontend — não é usada em runtime; avaliar se ainda serve de referência ou pode ser removida do Git.
3. **`.gitignore` desatualizado** — não cobria `__pycache__/`, `.next/`, `*.db`, `bkp/`. Substituído.
4. Arquivos `.bak_20260704_*` espalhados (`main.py`, `page.tsx`, `Header.tsx`, `Sidebar.tsx`) sugerem edições manuais recentes sem Git — considerar commitar direto em vez de manter cópias `.bak` soltas.

## Convenções do projeto

- Scripts `.ps1`/`.bat`: preferencialmente com resolução de path dinâmica (`$PSScriptRoot` / `%~dp0`), nunca caminho absoluto fixo.
- Entrega de arquivos completos e prontos para uso, sem instruções de edição manual.
- Tema escuro como padrão (frontend usa `bg-slate-950` como base).
- Agentes: alterações de comportamento (`system_prompt`) via API/tela de configurações, não via Modelfile do Ollama.
