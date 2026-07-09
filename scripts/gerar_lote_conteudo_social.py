"""
gerar_lote_conteudo_social.py
Usa os agentes HC-CONTENT e HC-SOCIAL (ja treinados com o contexto real do
negocio) via API de producao (POST /api/ai/chat) para gerar um lote de posts
prontos para revisar e publicar manualmente no Instagram/Facebook.

Nao publica nada sozinho - so gera o conteudo e salva em Markdown para revisao.

Pre-requisito: backend rodando, agentes treinados (treinar_agentes_hctech.py).

Uso:
    python scripts/gerar_lote_conteudo_social.py
    python scripts/gerar_lote_conteudo_social.py --saida posts_semana.md
"""

import argparse
import sys
from datetime import datetime

import httpx


# Servicos reais da HC Tech - um post por servico a cada execucao.
# Edite esta lista conforme a pauta da semana.
SERVICOS = [
    "troca de tela rapida de iPhone",
    "reparo de placa de iPhone (micro-soldagem e reballing)",
    "troca de bateria de celular",
    "conserto de notebook",
]

CANAIS = ["instagram", "facebook"]


def gerar_post(client: httpx.Client, api_url: str, servico: str, canal: str) -> str:
    pergunta = (
        f"Crie uma legenda para {canal} sobre o serviço: {servico}. "
        f"Formato adequado ao canal."
    )
    resp = client.post(
        f"{api_url}/api/ai/chat",
        json={
            "messages": [{"role": "user", "content": pergunta}],
            "agent_id": "hc-social",
            "provider": "ollama",
        },
        timeout=120.0,
    )
    resp.raise_for_status()
    return resp.json().get("response", "[sem resposta]")


def main():
    parser = argparse.ArgumentParser(description="Gera lote de posts prontos usando os agentes reais")
    parser.add_argument("--api-url", default="http://localhost:8000")
    parser.add_argument("--saida", default=None, help="Arquivo Markdown de saida (default: posts_AAAAMMDD.md)")
    args = parser.parse_args()

    saida = args.saida or f"posts_{datetime.now().strftime('%Y%m%d')}.md"

    linhas = [
        f"# Lote de posts gerados - {datetime.now().strftime('%d/%m/%Y %H:%M')}",
        "",
        "> Gerado automaticamente pelo HC-SOCIAL. Revise antes de publicar.",
        "",
    ]

    print(f"=== Gerando lote de conteudo social ===")
    print(f"API: {args.api_url}")
    print(f"Servicos: {len(SERVICOS)} | Canais: {len(CANAIS)}\n")

    total_falhas = 0

    with httpx.Client() as client:
        try:
            client.get(f"{args.api_url}/api/ai/status", timeout=5.0)
        except httpx.RequestError:
            print(f"ERRO: backend nao respondeu em {args.api_url}")
            sys.exit(1)

        for servico in SERVICOS:
            linhas.append(f"## {servico}")
            linhas.append("")
            for canal in CANAIS:
                print(f"Gerando: {servico} / {canal}...")
                try:
                    post = gerar_post(client, args.api_url, servico, canal)
                    linhas.append(f"### {canal.capitalize()}")
                    linhas.append("")
                    linhas.append(post.strip())
                    linhas.append("")
                    print(f"  OK")
                except httpx.HTTPStatusError as e:
                    print(f"  ERRO HTTP: {e}")
                    total_falhas += 1
                except httpx.RequestError as e:
                    print(f"  ERRO de conexao: {e}")
                    total_falhas += 1
            linhas.append("---")
            linhas.append("")

    with open(saida, "w", encoding="utf-8") as f:
        f.write("\n".join(linhas))

    print(f"\nLote salvo em: {saida}")
    if total_falhas == 0:
        print("Todos os posts gerados com sucesso. Revise o arquivo antes de publicar.")
        sys.exit(0)
    else:
        print(f"{total_falhas} post(s) falharam - veja o log acima.")
        sys.exit(1)


if __name__ == "__main__":
    main()
