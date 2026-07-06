---
name: treinamento-modelos-ollama
description: Customizar, especializar e "treinar" modelos locais no Ollama para o sistema HC-TECH-AI — via Modelfile (system prompt, parâmetros, personalidade fixa por agente), RAG com base de conhecimento própria da HC Tech, e fine-tuning real (LoRA) para quem precisa de comportamento realmente novo. Use sempre que o usuário mencionar treinar, ensinar, especializar, ajustar personalidade, dar conhecimento próprio, ou fazer o modelo "aprender" sobre a HC Tech, mesmo sem usar o termo técnico correto (fine-tuning, RAG, Modelfile).
---

# Treinamento e Customização de Modelos — HC-TECH-AI

O Ollama **não faz fine-tuning nativo**. Existem 3 níveis de "treinar" o sistema, do mais simples/rápido ao mais custoso — escolha o nível certo antes de partir para fine-tuning real, que raramente é necessário.

## Nível 1 — Modelfile (personalidade e comportamento fixos) ⭐ mais comum

Fixa system prompt, parâmetros e nome do modelo customizado, sem re-treinar pesos. Resolve 80% dos casos de "quero que o agente sempre responda assim".

### Passo a passo
1. Criar um arquivo `Modelfile` (sem extensão) por agente:

```dockerfile
# Modelfile.hc-content
FROM qwen2.5:14b

PARAMETER temperature 0.7
PARAMETER num_ctx 8192

SYSTEM """
Você é o HC-CONTENT, agente de geração de conteúdo da HC Tech InfoCell.
Responda sempre em português do Brasil, de forma objetiva.
Use emojis em textos promocionais para redes sociais e marketplaces.
Nunca invente especificações técnicas de produtos que não foram informadas.
Siga a identidade visual da marca: tom direto, sem enrolação, foco em conversão.
"""
```

2. Criar o modelo customizado a partir do Modelfile:
```powershell
ollama create hc-content -f Modelfile.hc-content
```

3. Usar normalmente, referenciando o novo nome:
```powershell
ollama run hc-content
```
Ou via API, trocando `"model": "qwen2.5:14b"` por `"model": "hc-content"` no payload.

4. Repetir para cada agente (`hc-seo`, `hc-leads`, `hc-code`, `hc-ceo`), cada um com seu próprio `Modelfile` e `SYSTEM` específico.

### Vantagens
- Leva minutos, não requer dataset nem GPU dedicada.
- Versione os `Modelfile`s no Git — fazem parte do código do sistema.

## Nível 2 — RAG (Retrieval-Augmented Generation): dar conhecimento próprio da HC Tech

Quando o objetivo é o agente "saber" catálogo de produtos, tabela de preços, base de compatibilidade de películas etc. — isso **não é treinamento de pesos**, é busca + contexto injetado no prompt. É a abordagem certa para dados que mudam com frequência (preços, estoque).

### Arquitetura recomendada
1. **Gerar embeddings** dos documentos (catálogo, FAQ, base de compatibilidade) com modelo de embedding local do Ollama:
```powershell
ollama pull nomic-embed-text
```
2. **Armazenar vetores** em um banco vetorial simples (ex: tabela MySQL com coluna JSON, ou SQLite com extensão `sqlite-vss`, ou Chroma/Qdrant se o volume justificar).
3. **No momento da pergunta**: gerar embedding da pergunta → buscar os N documentos mais similares → injetar como contexto no `system`/primeira mensagem antes de chamar o modelo de chat.

### Exemplo — gerar embedding (Python)
```python
import httpx

def gerar_embedding(texto: str) -> list[float]:
    resp = httpx.post(
        "http://localhost:11434/api/embeddings",
        json={"model": "nomic-embed-text", "prompt": texto},
        timeout=30,
    )
    resp.raise_for_status()
    return resp.json()["embedding"]
```

### Vantagens sobre fine-tuning
- Atualizar conhecimento = atualizar o banco de dados, sem re-treinar nada.
- Zero custo de GPU para "treinar".
- Elimina alucinação de preço/estoque desatualizado — o modelo só responde com o que está no banco.

## Nível 3 — Fine-tuning real (LoRA) — só quando os níveis 1 e 2 não resolvem

Necessário apenas se o objetivo for mudar **estilo de escrita muito específico** ou **formato de saída estruturado difícil de obter só com prompt**. É mais caro e trabalhoso — avalie bem antes de ir por esse caminho.

### Fluxo geral
1. **Preparar dataset** em formato instrução/resposta (JSONL):
```json
{"instruction": "Escreva um anúncio para tela iPhone 11", "output": "📱 Tela iPhone 11 Original..."}
```
Mínimo recomendado: 200–500 exemplos de qualidade para resultado perceptível; ideal 1000+.

2. **Treinar LoRA** com uma ferramenta externa ao Ollama (o Ollama não treina, só serve o modelo depois). Opções:
   - **Unsloth** (mais rápido, roda até em GPU única de consumo)
   - **Axolotl**
   - **Hugging Face PEFT + transformers**

3. **Converter o resultado para GGUF** (formato que o Ollama consome), usando `llama.cpp`'s `convert-lora-to-gguf.py` ou mesclando o LoRA ao modelo base antes da conversão.

4. **Importar no Ollama** via Modelfile:
```dockerfile
FROM ./modelo-finetunado.gguf
```
```powershell
ollama create hc-content-custom -f Modelfile
```

### Quando NÃO vale a pena
- Se o problema é "o modelo não sabe o preço X" → é problema de RAG (Nível 2), não de fine-tuning.
- Se o problema é "o modelo não segue o tom que eu quero" → normalmente resolve com Modelfile (Nível 1) bem escrito, ajustando o `SYSTEM` e `temperature`.
- Fine-tuning exige hardware com GPU decente (mínimo 12-16GB VRAM para modelos 7-8B com LoRA) e manutenção contínua a cada atualização de modelo base.

## Recomendação prática para o HC-TECH-AI
Ordem de implementação sugerida: **Modelfile em todos os agentes primeiro (Nível 1)** → **RAG para catálogo/preços/compatibilidade (Nível 2)** → só considerar Nível 3 se, depois disso, ainda houver uma lacuna clara de estilo que prompt engineering não resolve.
