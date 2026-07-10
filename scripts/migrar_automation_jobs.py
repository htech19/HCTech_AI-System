"""
migrar_automation_jobs.py
Garante que os jobs de automacao (incluindo o novo "Gerar Posts Sociais Semanal")
existam no banco, sem duplicar. Idempotente - pode rodar quantas vezes quiser.

Motivo: o seed automatico do banco (seed_initial_data) so roda se a tabela
'agents' estiver vazia - como seu banco ja tem agentes de sessoes anteriores,
os automation_jobs (incluindo qualquer um novo) nunca sao inseridos sozinhos.

Uso:
    python scripts/migrar_automation_jobs.py
    python scripts/migrar_automation_jobs.py --db-path data/hctech.db
"""

import argparse
import json
import os
import sqlite3
import sys
from datetime import datetime


JOBS_ESPERADOS = [
    {
        "name": "Verificar Reviews Diário",
        "description": "Checar novas avaliações no Google",
        "job_type": "review_check",
        "schedule": "0 9 * * *",
        "is_active": True,
        "config": {"auto_respond": False},
    },
    {
        "name": "Relatório SEO Semanal",
        "description": "Gerar relatório de keywords todo domingo",
        "job_type": "seo_report",
        "schedule": "0 8 * * 0",
        "is_active": True,
        "config": {"send_email": False},
    },
    {
        "name": "Backup Banco Diário",
        "description": "Backup automático do banco de dados",
        "job_type": "backup",
        "schedule": "0 2 * * *",
        "is_active": True,
        "config": {"keep_days": 7},
    },
    {
        "name": "Gerar Posts Sociais Semanal",
        "description": "Gera posts para Instagram/Facebook via HC-SOCIAL, salva na Knowledge Base para revisao",
        "job_type": "social_content",
        "schedule": "0 8 * * 1",
        "is_active": True,
        "config": {
            "services": [
                "troca de tela rapida de iPhone",
                "reparo de placa de iPhone (micro-soldagem e reballing)",
                "troca de bateria de celular",
                "conserto de notebook",
            ],
            "channels": ["instagram", "facebook"],
        },
    },
]


def migrar(db_path: str) -> int:
    if not os.path.exists(db_path):
        print(f"ERRO: banco nao encontrado em {db_path}")
        print("Suba o backend pelo menos uma vez antes (ele cria o banco/tabelas).")
        return 1

    conn = sqlite3.connect(db_path)
    try:
        cursor = conn.cursor()
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='automation_jobs'")
        if not cursor.fetchone():
            print("ERRO: tabela 'automation_jobs' nao existe. Suba o backend uma vez para criar o schema.")
            return 1

        cursor.execute("SELECT name FROM automation_jobs")
        existentes = {row[0] for row in cursor.fetchall()}

        inseridos = 0
        for job in JOBS_ESPERADOS:
            if job["name"] in existentes:
                print(f"OK - ja existe: {job['name']}")
                continue

            cursor.execute(
                """INSERT INTO automation_jobs
                   (name, description, job_type, schedule, is_active, run_count,
                    success_count, error_count, config, created_at)
                   VALUES (?, ?, ?, ?, ?, 0, 0, 0, ?, ?)""",
                (
                    job["name"],
                    job["description"],
                    job["job_type"],
                    job["schedule"],
                    1 if job["is_active"] else 0,
                    json.dumps(job["config"]),
                    datetime.utcnow().isoformat(),
                ),
            )
            print(f"CRIADO - {job['name']}")
            inseridos += 1

        conn.commit()
        print(f"\n{inseridos} job(s) novo(s) inserido(s), {len(existentes)} ja existiam.")
        return 0
    except sqlite3.Error as e:
        print(f"ERRO ao migrar: {e}")
        return 1
    finally:
        conn.close()


def main():
    parser = argparse.ArgumentParser(description="Garante os automation_jobs no banco existente")
    parser.add_argument("--db-path", default="data/hctech.db")
    args = parser.parse_args()

    print("=== Migracao: automation_jobs ===\n")
    resultado = migrar(args.db_path)

    print("")
    if resultado == 0:
        print("Migracao concluida. Reinicie o backend para o scheduler carregar os jobs ativos.")
    sys.exit(resultado)


if __name__ == "__main__":
    main()
