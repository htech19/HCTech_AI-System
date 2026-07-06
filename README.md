# HCTech_AI-System

Sistema multiagente de IA local para automação de SEO, criação de conteúdo e geração de leads da HC Tech InfoCell, orquestrado sobre **Ollama** com inferência 100% local.

**Versão atual:** v2.1
**Repositório:** https://github.com/htech19/HCTech_AI-System
**Status:** Em desenvolvimento ativo

---

## Sumário

- [Visão Geral](#visão-geral)
- [Arquitetura de Agentes](#arquitetura-de-agentes)
- [Stack Tecnológica](#stack-tecnológica)
- [Estrutura do Projeto](#estrutura-do-projeto)
- [Pré-requisitos](#pré-requisitos)
- [Instalação](#instalação)
- [Configuração](#configuração)
- [Uso](#uso)
- [Scripts de Automação](#scripts-de-automação)
- [Logs e Monitoramento](#logs-e-monitoramento)
- [Convenções do Projeto](#convenções-do-projeto)
- [Roadmap](#roadmap)
- [Licença](#licença)

---

## Visão Geral

O **HCTech_AI-System** é uma plataforma multiagente que executa localmente (sem dependência de APIs externas pagas) para:

- Gerar e otimizar conteúdo com foco em SEO para o site e canais da HC Tech InfoCell.
- Produzir conteúdo para redes sociais e marketplaces (Mercado Livre, Shopee).
- Captar e qualificar leads automaticamente.
- Orquestrar tarefas de desenvolvimento e manutenção de código via agente dedicado.

O sistema é construído sobre modelos rodando localmente via **Ollama**, eliminando custos recorrentes de API e garantindo controle total sobre os dados.

## Arquitetura de Agentes

O sistema é dividido em 5 agentes especializados, cada um com responsabilidade única:

| Agente | Responsabilidade |
|---|---|
| **HC-CEO** | Orquestração geral, priorização de tarefas e coordenação entre os demais agentes |
| **HC-SEO** | Pesquisa de palavras-chave, otimização on-page, geração de metadados e schema markup |
| **HC-CONTENT** | Criação de conteúdo (posts, descrições de produto, artigos de blog, copy para redes sociais) |
| **HC-LEADS** | Captação, qualificação e enriquecimento de leads |
| **HC-CODE** | Automação de tarefas de desenvolvimento, revisão e manutenção de scripts/código |

Cada agente opera de forma independente, mas compartilha estado e contexto através da camada de persistência (MySQL/MariaDB) e pode ser invocado isoladamente ou como parte de um fluxo orquestrado pelo HC-CEO.

## Stack Tecnológica

- **Inferência de IA:** Ollama (modelos locais, sem custo de API)
- **Frontend/Dashboard:** Next.js
- **Gerenciador de pacotes:** pnpm
- **Banco de dados:** MySQL / MariaDB
- **ORM:** Drizzle ORM
- **Automação de infraestrutura:** PowerShell (Windows) e Python
- **Controle de versão:** Git / GitHub

## Estrutura do Projeto

> Estrutura de referência baseada na arquitetura do sistema. Ajuste conforme a organização real de pastas do repositório.

```
HCTech_AI-System/
├── agents/
│   ├── hc-ceo/
│   ├── hc-seo/
│   ├── hc-content/
│   ├── hc-leads/
│   └── hc-code/
├── app/                    # Aplicação Next.js (dashboard)
├── db/
│   ├── schema/             # Definições Drizzle ORM
│   └── migrations/
├── scripts/
│   ├── *.ps1               # Scripts de setup e automação (Windows)
│   └── *.py                # Scripts de processamento e integração
├── logs/                   # Logs persistentes de execução
├── docs/                   # Documentação técnica detalhada
├── .env.example
├── package.json
├── pnpm-lock.yaml
└── README.md
```

## Pré-requisitos

- Node.js LTS + [pnpm](https://pnpm.io)
- [Ollama](https://ollama.com) instalado e com os modelos necessários baixados
- MySQL ou MariaDB (local ou em container)
- Python 3.10+ (para scripts de automação)
- Git e GitHub CLI (`gh`) configurados

## Instalação

```powershell
# Clonar o repositório
git clone https://github.com/htech19/HCTech_AI-System.git
cd HCTech_AI-System

# Instalar dependências
pnpm install

# Configurar variáveis de ambiente
copy .env.example .env

# Rodar migrações do banco (Drizzle)
pnpm drizzle-kit push
```

## Configuração

Preencher o arquivo `.env` com:

```
DATABASE_URL=mysql://usuario:senha@localhost:3306/hctech_ai
OLLAMA_HOST=http://localhost:11434
OLLAMA_MODEL=<modelo-utilizado>
NODE_ENV=development
```

## Uso

```powershell
# Subir o dashboard (Next.js)
pnpm dev

# Executar um agente específico
pnpm run agent:hc-seo
pnpm run agent:hc-content
pnpm run agent:hc-leads
```

## Scripts de Automação

Os scripts `.ps1` e `.py` da pasta `scripts/` seguem os padrões:

- Arquivos `.bat`/`.ps1`: encoding **ANSI/CP1252**, quebras de linha **CRLF**, conteúdo **somente ASCII**.
- Tratamento de erro robusto (`try/catch`, códigos de saída, validação de pré-condições).
- Logging persistente em arquivo com timestamp para cada execução.

## Logs e Monitoramento

Cada execução de agente ou script gera log individual em `logs/`, com timestamp, nível (`INFO`/`WARN`/`ERROR`) e rastreio completo de falhas para auditoria.

## Convenções do Projeto

- Implementações preferencialmente single-file para bots e automações.
- Tema escuro como padrão em qualquer dashboard/UI gerada.
- Entrega de arquivos completos e prontos para produção (sem instruções de edição manual).
- Commits e documentação técnica podem ser mantidos em português; código e nomes de variáveis em inglês.

## Roadmap

- [ ] Orquestração completa entre agentes via HC-CEO
- [ ] Dashboard de monitoramento em tempo real (Next.js)
- [ ] Integração com catálogo de produtos HC Tech
- [ ] Expansão do HC-LEADS para múltiplos canais (WhatsApp, Telegram, formulário web)
- [ ] Pipeline de deploy automatizado

## Licença

Uso interno — HC Tech InfoCell. Todos os direitos reservados.
