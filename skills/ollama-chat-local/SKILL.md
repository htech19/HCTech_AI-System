---
name: ollama-chat-local
description: Configurar, executar e integrar chat local com LLMs via Ollama para o sistema HC-TECH-AI (agentes HC-CEO, HC-SEO, HC-CONTENT, HC-LEADS, HC-CODE). Use sempre que o usuário pedir para instalar Ollama, rodar modelo local, configurar chat/API local, integrar Ollama com Next.js/Python/PowerShell, resolver erro de conexão com Ollama, escolher modelo, ou expor um endpoint de chat sem depender de API paga. Também aciona para dúvidas sobre performance, contexto, streaming de resposta e escolha de modelo (Llama, Mistral, Qwen, DeepSeek, Phi) rodando localmente.
---

# Chat Local com Ollama — HC-TECH-AI

Guia para colocar e manter o Ollama rodando localmente como motor de inferência dos agentes do sistema HC-TECH-AI, sem dependência de API paga externa.

## 1. Instalação

**Windows (ambiente padrão do Harry):**
```powershell
winget install Ollama.Ollama
```
Ou baixar o instalador em https://ollama.com/download. Após instalar, o serviço sobe automaticamente em `http://localhost:11434`.

Verificar se está no ar:
```powershell
curl http://localhost:11434
# Resposta esperada: "Ollama is running"
```

## 2. Baixar modelos

```powershell
ollama pull llama3.1:8b        # bom equilíbrio custo/qualidade para uso geral
ollama pull qwen2.5:14b        # forte em PT-BR e tarefas estruturadas
ollama pull deepseek-coder-v2  # especializado em código (bom para HC-CODE)
ollama pull phi4               # leve, roda bem com hardware modesto
```

Escolha por agente:
| Agente | Modelo sugerido | Motivo |
|---|---|---|
| HC-SEO / HC-CONTENT | `qwen2.5:14b` ou `llama3.1:8b` | boa fluência em PT-BR |
| HC-CODE | `deepseek-coder-v2` | especializado em geração/revisão de código |
| HC-LEADS | `llama3.1:8b` | resposta rápida, custo de inferência baixo |
| HC-CEO (orquestrador) | `qwen2.5:14b` | melhor raciocínio para roteamento de tarefas |

## 3. Testar chat via CLI
```powershell
ollama run llama3.1:8b
```

## 4. API local (REST) — base para integração com os agentes

Endpoint padrão: `http://localhost:11434/api/chat`

### Exemplo — Node.js (Next.js API route)
```javascript
// app/api/agent/chat/route.js
export async function POST(req) {
  const { agent, messages } = await req.json();

  const modelPorAgente = {
    "hc-seo": "qwen2.5:14b",
    "hc-content": "qwen2.5:14b",
    "hc-code": "deepseek-coder-v2",
    "hc-leads": "llama3.1:8b",
    "hc-ceo": "qwen2.5:14b",
  };

  const model = modelPorAgente[agent] || "llama3.1:8b";

  try {
    const response = await fetch("http://localhost:11434/api/chat", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ model, messages, stream: false }),
    });

    if (!response.ok) {
      throw new Error(`Ollama respondeu status ${response.status}`);
    }

    const data = await response.json();
    return Response.json({ ok: true, agent, content: data.message.content });
  } catch (err) {
    return Response.json({ ok: false, error: err.message }, { status: 500 });
  }
}
```

### Exemplo — Python (FastAPI, para scripts de automação)
```python
import httpx
import logging

logging.basicConfig(
    filename="logs/ollama_chat.log",
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)

OLLAMA_URL = "http://localhost:11434/api/chat"

MODELO_POR_AGENTE = {
    "hc-seo": "qwen2.5:14b",
    "hc-content": "qwen2.5:14b",
    "hc-code": "deepseek-coder-v2",
    "hc-leads": "llama3.1:8b",
    "hc-ceo": "qwen2.5:14b",
}

def chat_agente(agente: str, mensagens: list[dict], timeout: float = 60.0) -> str:
    modelo = MODELO_POR_AGENTE.get(agente, "llama3.1:8b")
    payload = {"model": modelo, "messages": mensagens, "stream": False}

    try:
        with httpx.Client(timeout=timeout) as client:
            resp = client.post(OLLAMA_URL, json=payload)
            resp.raise_for_status()
            data = resp.json()
            logging.info(f"Agente={agente} modelo={modelo} ok")
            return data["message"]["content"]
    except httpx.HTTPStatusError as e:
        logging.error(f"Agente={agente} erro HTTP: {e}")
        raise
    except httpx.RequestError as e:
        logging.error(f"Agente={agente} falha de conexao com Ollama: {e}")
        raise
```

## 5. Streaming de resposta (recomendado para UI de chat)
Definir `"stream": true` no payload e ler a resposta como NDJSON (uma linha JSON por token/chunk). No Next.js, repassar via `ReadableStream` para o front-end consumir com `EventSource` ou `fetch` + reader.

## 6. Contexto e memória entre agentes
- Ollama não mantém histórico entre chamadas — cada request precisa enviar o array `messages` completo (system + histórico + nova mensagem).
- Persistir o histórico de conversa por agente no MySQL/MariaDB (tabela `agent_conversations`), montando o array `messages` a partir do banco antes de cada chamada.
- Definir um `system prompt` fixo por agente (personalidade, escopo, restrições) — ver skill `treinamento-modelos-ollama` para como fixar isso via Modelfile.

## 7. Resolução de problemas comuns
| Sintoma | Causa provável | Solução |
|---|---|---|
| `ECONNREFUSED localhost:11434` | Serviço Ollama não está rodando | `ollama serve` (ou reiniciar o serviço do Windows) |
| Resposta muito lenta | Modelo grande demais para a GPU/CPU disponível | Trocar para modelo menor (`phi4`, `llama3.1:8b`) ou usar quantização menor (`:q4_0`) |
| Resposta em inglês mesmo pedindo PT-BR | Falta de `system prompt` reforçando idioma | Adicionar instrução explícita de idioma no `system` message ou no Modelfile |
| Erro de memória (`out of memory`) | Modelo excede VRAM/RAM disponível | Usar versão quantizada (`:q4_K_M`) ou modelo menor |

## 8. Próximo passo natural
Se o usuário quiser fixar comportamento/personalidade por agente de forma permanente (sem repetir o `system prompt` em toda chamada), ou "treinar" o sistema com dados próprios da HC Tech, use a skill `treinamento-modelos-ollama`.
