# Documentação Técnica — HCTech_AI-System

## 1. Objetivo do Sistema

Automatizar, com IA local (sem custo recorrente de API paga), três frentes operacionais da HC Tech InfoCell:

1. **SEO** — pesquisa e otimização contínua de conteúdo do site e canais digitais.
2. **Conteúdo** — geração de copy para blog, redes sociais e marketplaces.
3. **Leads** — captação, qualificação e enriquecimento de contatos comerciais.

Um quarto pilar, **HC-CODE**, dá suporte à manutenção e evolução do próprio sistema.

## 2. Visão de Arquitetura

```
                ┌────────────┐
                │   HC-CEO   │  ← orquestrador central
                └─────┬──────┘
        ┌─────────────┼─────────────┬─────────────┐
        ▼             ▼             ▼             ▼
   ┌─────────┐  ┌───────────┐  ┌──────────┐  ┌──────────┐
   │ HC-SEO  │  │HC-CONTENT │  │ HC-LEADS │  │ HC-CODE  │
   └────┬────┘  └─────┬─────┘  └────┬─────┘  └────┬─────┘
        └─────────────┴──────────────┴─────────────┘
                          │
                 ┌────────▼────────┐
                 │  Ollama (LLM     │
                 │  local runtime)  │
                 └────────┬────────┘
                          │
                 ┌────────▼────────┐
                 │ MySQL/MariaDB    │
                 │ (Drizzle ORM)    │
                 └─────────────────┘
```

O **HC-CEO** recebe a demanda (manual ou agendada), decide qual agente deve atuar e consolida o resultado. Todos os agentes leem/escrevem estado através da camada de persistência, permitindo histórico, retomada de tarefas e auditoria.

## 3. Detalhamento dos Agentes

### 3.1 HC-CEO
- Ponto de entrada único do sistema.
- Interpreta a solicitação, define prioridade e roteia para o(s) agente(s) responsável(is).
- Consolida respostas de múltiplos agentes quando a tarefa exige mais de um domínio.

### 3.2 HC-SEO
- Pesquisa de palavras-chave e análise de concorrência.
- Geração de metadados (title, description), dados estruturados (Schema.org) e sugestões de otimização on-page.
- Integração com o histórico de conteúdo já publicado para evitar canibalização de palavras-chave.

### 3.3 HC-CONTENT
- Geração de textos para blog, descrições de produto, posts para redes sociais e anúncios.
- Segue convenções de marca: uso de emojis em copy promocional, tom alinhado à identidade da HC Tech.
- Pode consumir output do HC-SEO como insumo (palavras-chave, estrutura recomendada).

### 3.4 HC-LEADS
- Captação e qualificação de leads a partir de canais configurados.
- Enriquecimento de dados de contato.
- Handoff de leads qualificados para atendimento humano ou automação (ex.: bot de WhatsApp/Telegram).

### 3.5 HC-CODE
- Suporte à manutenção do próprio sistema: revisão de scripts, geração de automações PowerShell/Python, correção de bugs.
- Segue rigorosamente os padrões de encoding e error handling definidos no projeto.

## 4. Persistência de Dados

- **Banco:** MySQL/MariaDB.
- **ORM:** Drizzle ORM, com schemas versionados em `db/schema/` e migrações em `db/migrations/`.
- Cada agente possui suas próprias tabelas de domínio, além de tabelas compartilhadas de log e histórico de execução usadas pelo HC-CEO para orquestração.

## 5. Camada de IA (Ollama)

- Inferência 100% local via Ollama, eliminando dependência de provedores externos pagos.
- Modelo(s) configurável(is) via variável de ambiente `OLLAMA_MODEL`.
- Cada agente monta seu próprio prompt de sistema, especializado por domínio (SEO, conteúdo, leads, código).

## 6. Scripts de Automação

Localizados em `scripts/`, cobrindo setup de ambiente, rotinas agendadas e integrações pontuais.

**Padrões obrigatórios:**
- `.bat` / `.ps1`: encoding ANSI/CP1252, quebras de linha CRLF, conteúdo somente ASCII (sem acentos/caracteres especiais).
- Tratamento de erro completo: validação de pré-condições, blocos `try/catch`, códigos de saída explícitos.
- Logging persistente por execução, com timestamp e níveis `INFO` / `WARN` / `ERROR`.
- Scripts de automação/bots preferencialmente em arquivo único (single-file).

## 7. Fluxo de Execução Típico

1. Usuário (ou agendador) dispara uma tarefa via HC-CEO.
2. HC-CEO identifica o(s) agente(s) necessário(s) e prepara o contexto.
3. Agente(s) executa(m) a tarefa via Ollama, consultando/gravando dados no MySQL/MariaDB.
4. Resultado é registrado em log e retornado ao solicitante (dashboard, script ou integração externa).

## 8. Ambiente e Variáveis

| Variável | Descrição |
|---|---|
| `DATABASE_URL` | String de conexão MySQL/MariaDB |
| `OLLAMA_HOST` | Endpoint local do Ollama (ex.: `http://localhost:11434`) |
| `OLLAMA_MODEL` | Modelo utilizado pelos agentes |
| `NODE_ENV` | Ambiente de execução (`development` / `production`) |

## 9. Próximos Passos Técnicos

- Formalizar contrato de mensagens entre HC-CEO e agentes (schema de request/response).
- Adicionar testes automatizados para cada agente.
- Expor endpoints REST/RPC para integração externa (bot Telegram/WhatsApp, dashboard).
- Documentar schema completo do banco (`db/schema/`) neste arquivo à medida que for estabilizado.

---

**Nota:** esta documentação foi estruturada a partir do contexto de arquitetura do projeto. Ajuste as seções de estrutura de pastas, variáveis de ambiente e schema de banco conforme o estado real do código no repositório, se houver divergência.
