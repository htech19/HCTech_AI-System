<div align="center">

# 🤖 HC TECH AI SYSTEM
### `v2.1` — Plataforma Híbrida de Inteligência Artificial para Assistência Técnica

[![Python](https://img.shields.io/badge/Python-3.12-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://python.org)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.115-009688?style=for-the-badge&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![Next.js](https://img.shields.io/badge/Next.js-14.2-000000?style=for-the-badge&logo=next.js&logoColor=white)](https://nextjs.org)
[![Ollama](https://img.shields.io/badge/Ollama-IA_Local-FF6B00?style=for-the-badge&logo=ollama&logoColor=white)](https://ollama.ai)
[![License](https://img.shields.io/badge/Licença-Proprietária-red?style=for-the-badge)](LICENSE)

**5 agentes de IA autônomos. IA local ou em nuvem. Zero dependência obrigatória de API paga.**

[🚀 Instalação Rápida](#-instalação-rápida) · [🧠 Os Agentes](#-os-5-agentes) · [🏗️ Arquitetura](#️-arquitetura) · [📡 API](#-módulos-da-api) · [🔧 Manutenção](#-scripts-do-projeto)

</div>

---

## ⚡ O que é isso

Sistema de gestão com **inteligência artificial embarcada** rodando para a **HC Tech InfoCell** — assistência técnica de smartphones e notebooks no Grande ABC, São Bernardo do Campo/SP, desde 2011.

Backend em **FastAPI**, frontend em **Next.js 14**, e 5 agentes especializados que pensam com **Ollama local**, **OpenAI** ou **Anthropic** — trocando de provedor por agente, em tempo real, sem redeploy.

> 🔗 Site real do negócio: [www.hctechinfocell.com.br](https://www.hctechinfocell.com.br)
> 📦 Repositório: [github.com/htech19/HCTech_AI-System](https://github.com/htech19/HCTech_AI-System)

---

## 🧠 Os 5 Agentes

Cada agente é um "funcionário digital" com personalidade, escopo e conhecimento próprios — armazenados no banco de dados, editáveis em tempo real, sem precisar treinar nenhum modelo.

| | Agente | Missão |
|---|---|---|
| 🧭 | **HC-CEO** | Coordenador estratégico — decide qual agente entra em ação |
| 🔍 | **HC-SEO** | SEO local, palavras-chave, Google Maps, Schema.org |
| 📱 | **HC-SOCIAL** | Facebook & Instagram — posts, legendas, calendário editorial |
| ✍️ | **HC-CONTENT** | Copywriting, blog, descrições de serviço |
| 💻 | **HC-CODE** | Desenvolvimento e automação do próprio sistema |

**Trocar a personalidade de um agente é uma chamada de API, não um retreinamento:**
```bash
curl -X PATCH http://localhost:8000/api/agents/hc-seo \
  -H "Content-Type: application/json" \
  -d '{"system_prompt": "novo comportamento aqui..."}'
```

---

## 🏗️ Arquitetura

```
+---------------------+      +----------------------+
|   Next.js 14         |<---->|   FastAPI (Python)   |
|   Frontend (:3000)   |      |   Backend (:8000)    |
+---------------------+      +----------+-----------+
                                          |
                          +---------------+---------------+
                          v               v               v
                    +----------+   +----------+   +--------------+
                    |  Ollama   |   |  OpenAI  |   |  Anthropic    |
                    |  (local)  |   |  (nuvem) |   |  (nuvem)      |
                    +----------+   +----------+   +--------------+
                          |
                          v
                 +------------------+
                 |  SQLite (agentes, |
                 |  conversas, dados) |
                 +------------------+
```

<details>
<summary><b>📁 Ver estrutura completa de pastas</b></summary>

```
backend/app/
  main.py, config.py, database.py
  api/        - um router por dominio (agents, seo, social, maps...)
  services/   - ai_service.py (roteamento hibrido de IA)

frontend/src/
  app/            - App Router (layout, page, globals.css)
  components/     - layout (Sidebar, Header) + pages (Dashboard, Agents, SEO...)
  lib/api.ts      - cliente HTTP
  store/          - estado global (Zustand)

data/hctech.db    - banco SQLite (runtime)
scripts/          - automacoes (instalador, treinamento, validacao)
docs/             - documentacao tecnica completa
```
</details>

**Stack:** FastAPI 0.115 · SQLAlchemy 2.0 (async) · aiosqlite · Next.js 14.2 · React 18.3 · TypeScript · Tailwind · Zustand · TanStack Query · APScheduler · Loguru

---

## 🚀 Instalação Rápida

### Máquina zerada (Windows 10/11 25H2)
```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\Instalar-HCTechAI.ps1"
```
Ou clique duas vezes em **`scripts\Instalar-HCTechAI.bat`** — instala Git, Python, Node.js, Ollama (via `winget`), clona o projeto, instala tudo e configura o `.env` sozinho.

### Ligar o sistema
```powershell
.\iniciar_completo.bat
```
Sobe Ollama → Backend (`:8000`) → Frontend (`:3000`) → abre o navegador automaticamente.

| 🌐 Serviço | URL |
|---|---|
| Interface | http://localhost:3000 |
| API | http://localhost:8000 |
| Docs interativos | http://localhost:8000/docs |
| Ollama | http://localhost:11434 |

---

## 📡 Módulos da API

`auth` `ai` `agents` `tasks` `seo` `social` `maps` `knowledge` `reports` `metrics` `automation` `integrations`

Todos expostos sob `/api/*`, documentação interativa completa em `/docs` (Swagger UI gerado automaticamente pelo FastAPI).

---

## 🔧 Scripts do Projeto

| Script | O que faz |
|---|---|
| `Instalar-HCTechAI.ps1` / `.bat` | Instalação completa em máquina limpa |
| `Validar-Sync.ps1` | Compara local × GitHub (commits pendentes, arquivos não versionados) |
| `Limpar-Repo.ps1` | Remove do Git o que nunca deveria estar versionado |
| `treinar_agentes_hctech.py` | Aplica conhecimento real do negócio nos 5 agentes via API |
| `iniciar.ps1` / `iniciar_completo.bat` | Sobe o sistema inteiro |
| `setup.ps1` | Instala dependências (assume pré-requisitos já presentes) |

📖 **Documentação técnica completa:** [`docs/DOCUMENTACAO-TECNICA.md`](docs/DOCUMENTACAO-TECNICA.md)

---

<div align="center">

**HC Tech InfoCell** · São Bernardo do Campo/SP · Grande ABC · MEI desde 2011
Feito para rodar 100% local, sem depender de ninguém.

</div>
