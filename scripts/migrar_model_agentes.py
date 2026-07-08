"""
migrar_model_agentes.py
Adiciona a coluna 'model' na tabela 'agents' do banco SQLite existente,
sem apagar dados. Idempotente: pode rodar quantas vezes quiser.

Uso:
    python scripts/migrar_model_agentes.py
    python scripts/migrar_model_agentes.py --db-path data/hctech.db
"""

import argparse
import os
import sqlite3
import sys


def migrar(db_path: str) -> int:
    if not os.path.exists(db_path):
        print(f"ERRO: banco nao encontrado em {db_path}")
        print("Suba o backend pelo menos uma vez antes (ele cria o banco/tabelas).")
        return 1

    conn = sqlite3.connect(db_path)
    try:
        cursor = conn.cursor()
        cursor.execute("PRAGMA table_info(agents)")
        colunas = [row[1] for row in cursor.fetchall()]

        if "model" in colunas:
            print("Coluna 'model' ja existe na tabela 'agents'. Nada a fazer.")
            return 0

        print("Adicionando coluna 'model' na tabela 'agents'...")
        cursor.execute("ALTER TABLE agents ADD COLUMN model VARCHAR(100)")
        conn.commit()
        print("Coluna 'model' adicionada com sucesso.")

        cursor.execute("SELECT id, name FROM agents")
        agentes = cursor.fetchall()
        print(f"\nAgentes existentes ({len(agentes)}), todos com model=NULL (usarao o OLLAMA_MODEL global ate serem configurados):")
        for agent_id, name in agentes:
            print(f"  - {agent_id} ({name})")

        return 0
    except sqlite3.Error as e:
        print(f"ERRO ao migrar: {e}")
        return 1
    finally:
        conn.close()


def main():
    parser = argparse.ArgumentParser(description="Migra o banco para suportar modelo por agente")
    parser.add_argument("--db-path", default="data/hctech.db", help="Caminho do banco SQLite")
    args = parser.parse_args()

    print("=== Migracao: campo 'model' por agente ===\n")
    resultado = migrar(args.db_path)

    print("")
    if resultado == 0:
        print("Migracao concluida. Proximo passo: rode o treinar_agentes_hctech.py")
        print("atualizado para definir o modelo especifico de cada agente.")
    sys.exit(resultado)


if __name__ == "__main__":
    main()
