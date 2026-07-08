"""
validar_agentes_hctech.py
Valida de verdade o funcionamento dos 5 agentes apos o treinamento:
1. Confirma que o system_prompt salvo no banco contem o contexto real do negocio.
2. Envia uma pergunta de teste real para cada agente via POST /api/ai/chat
   e mostra a resposta, alem de checar heuristicamente se ela reflete o treinamento.

Pre-requisito: backend rodando (python -m uvicorn app.main:app --port 8000)
e Ollama rodando com o modelo configurado no .env.

Uso:
    python scripts/validar_agentes_hctech.py
    python scripts/validar_agentes_hctech.py --api-url http://localhost:8000
    python scripts/validar_agentes_hctech.py --somente-prompt
"""

import argparse
import sys
import textwrap

import httpx


# Palavra-chave minima esperada no system_prompt salvo, por agente.
# HC-CODE nao recebe o contexto de negocio (nao e agente voltado ao cliente final),
# entao seu marcador de validacao e diferente dos demais.
MARCADOR_POR_AGENTE = {
    "hc-ceo": "HC Tech InfoCell",
    "hc-seo": "HC Tech InfoCell",
    "hc-social": "HC Tech InfoCell",
    "hc-content": "HC Tech InfoCell",
    "hc-code": "HC-CODE",
}

# Modelo esperado por agente apos o treinamento (None = deve usar o global do .env)
MODELO_ESPERADO_POR_AGENTE = {
    "hc-ceo": None,
    "hc-seo": None,
    "hc-social": None,
    "hc-content": None,
    "hc-code": "qwen2.5-coder:7b",
}

# Uma pergunta de teste real por agente + palavras que a resposta deveria
# provavelmente conter se o agente estiver usando o contexto de negocio real.
TESTES = {
    "hc-ceo": {
        "pergunta": "Preciso de um post para o Instagram sobre troca de tela de iPhone. Quem deve cuidar disso?",
        "esperado": ["hc-content", "hc-social"],
    },
    "hc-seo": {
        "pergunta": "Me de um title tag e meta description para a pagina de troca de tela rapida.",
        "esperado": ["são bernardo", "tela"],
    },
    "hc-social": {
        "pergunta": "Crie uma legenda curta para Instagram sobre reparo de placa de iPhone.",
        "esperado": ["whatsapp", "garantia"],
    },
    "hc-content": {
        "pergunta": "Escreva uma descricao de servico para troca de bateria de celular.",
        "esperado": ["garantia", "orçamento"],
    },
    "hc-code": {
        "pergunta": "Como eu mudo o comportamento de um agente neste sistema?",
        "esperado": ["api", "system_prompt", "patch"],
    },
}


def validar_prompt_salvo(client: httpx.Client, api_url: str, agent_id: str) -> tuple[bool, str]:
    marcador = MARCADOR_POR_AGENTE.get(agent_id, "HC Tech InfoCell")
    modelo_esperado = MODELO_ESPERADO_POR_AGENTE.get(agent_id)

    try:
        resp = client.get(f"{api_url}/api/agents/{agent_id}")
        if resp.status_code != 200:
            return False, f"GET /api/agents/{agent_id} retornou {resp.status_code}"
        dados = resp.json()
        prompt = dados.get("system_prompt", "") or ""
        model_salvo = dados.get("model")

        partes = []
        ok = True

        if marcador in prompt:
            partes.append(f"system_prompt contem '{marcador}' ({len(prompt)} chars)")
        else:
            ok = False
            partes.append(f"system_prompt NAO contem '{marcador}' - treinamento pode nao ter sido aplicado")

        if modelo_esperado:
            if model_salvo == modelo_esperado:
                partes.append(f"model = '{model_salvo}' (correto)")
            else:
                ok = False
                partes.append(f"model = '{model_salvo}' (esperado: '{modelo_esperado}') - rode migrar_model_agentes.py + treinar_agentes_hctech.py")
        else:
            partes.append(f"model = '{model_salvo or 'null (usa OLLAMA_MODEL global)'}'")

        return ok, " | ".join(partes)
    except httpx.RequestError as e:
        return False, f"falha de conexao: {e}"


def validar_resposta_real(client: httpx.Client, api_url: str, agent_id: str, pergunta: str, esperado: list[str]) -> tuple[bool, str]:
    try:
        resp = client.post(
            f"{api_url}/api/ai/chat",
            json={
                "messages": [{"role": "user", "content": pergunta}],
                "agent_id": agent_id,
                "provider": "ollama",
            },
            timeout=120.0,
        )
        if resp.status_code != 200:
            return False, f"POST /api/ai/chat retornou {resp.status_code}: {resp.text[:200]}"

        resposta = resp.json().get("response", "")
        resposta_lower = resposta.lower()
        bateu = [p for p in esperado if p.lower() in resposta_lower]

        status_ok = len(bateu) > 0
        detalhe = f"palavras esperadas encontradas: {bateu or 'NENHUMA'}"
        return status_ok, f"{detalhe}\n{'-'*60}\n{textwrap.shorten(resposta, width=500, placeholder=' [...]')}\n{'-'*60}"

    except httpx.TimeoutException:
        return False, "timeout aguardando resposta da IA (modelo local pode estar lento)"
    except httpx.RequestError as e:
        return False, f"falha de conexao: {e}"


def main():
    parser = argparse.ArgumentParser(description="Valida funcionamento real dos agentes treinados")
    parser.add_argument("--api-url", default="http://localhost:8000", help="URL base do backend")
    parser.add_argument("--somente-prompt", action="store_true",
                         help="Valida so o system_prompt salvo, sem chamar a IA (mais rapido)")
    args = parser.parse_args()

    print("=== Validacao funcional dos agentes HC Tech ===")
    print(f"API: {args.api_url}\n")

    total_falhas = 0

    with httpx.Client() as client:
        # 1. Backend esta no ar?
        try:
            client.get(f"{args.api_url}/api/ai/status", timeout=5.0)
        except httpx.RequestError:
            print(f"ERRO: backend nao respondeu em {args.api_url}")
            print("Suba o backend antes: python -m uvicorn app.main:app --port 8000")
            sys.exit(1)

        for agent_id, teste in TESTES.items():
            print(f"### Agente: {agent_id} ###")

            ok_prompt, msg_prompt = validar_prompt_salvo(client, args.api_url, agent_id)
            simbolo = "OK " if ok_prompt else "FALHA"
            print(f"[{simbolo}] system_prompt: {msg_prompt}")
            if not ok_prompt:
                total_falhas += 1

            if not args.somente_prompt:
                print(f"  Pergunta de teste: {teste['pergunta']}")
                ok_resposta, msg_resposta = validar_resposta_real(
                    client, args.api_url, agent_id, teste["pergunta"], teste["esperado"]
                )
                simbolo = "OK " if ok_resposta else "AVISO"
                print(f"[{simbolo}] resposta da IA:\n{msg_resposta}")
                if not ok_resposta:
                    total_falhas += 1

            print("")

    print("=== Resumo ===")
    if total_falhas == 0:
        print("Todos os agentes validados com sucesso - treinamento funcionando.")
        sys.exit(0)
    else:
        print(f"{total_falhas} verificacao(oes) precisam de atencao (veja detalhes acima).")
        print("Nota: falha na 'resposta da IA' pode ser so o modelo tendo respondido")
        print("de forma diferente do esperado - leia o texto completo antes de concluir")
        print("que o treinamento nao funcionou.")
        sys.exit(1)


if __name__ == "__main__":
    main()
