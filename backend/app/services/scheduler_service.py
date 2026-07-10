"""Servico de automacao real - APScheduler + dispatch de jobs por tipo."""
from datetime import datetime, timedelta
from pathlib import Path

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from loguru import logger
from sqlalchemy import select

from app.database import AsyncSessionLocal, AutomationJob, Agent, KnowledgeBase
from app.services.ai_service import ai_service

scheduler = AsyncIOScheduler()

DATA_DIR = Path(__file__).parent.parent.parent.parent / "data"
DB_PATH = DATA_DIR / "hctech.db"
BACKUP_DIR = DATA_DIR / "backups"


async def _get_agent(session, agent_id: str) -> Agent | None:
    result = await session.execute(select(Agent).where(Agent.id == agent_id))
    return result.scalar_one_or_none()


async def _job_social_content(config: dict) -> dict:
    """Gera posts reais via HC-SOCIAL e salva na Knowledge Base para revisao."""
    servicos = config.get("services", [
        "troca de tela rapida de iPhone",
        "reparo de placa de iPhone (micro-soldagem e reballing)",
        "troca de bateria de celular",
    ])
    canais = config.get("channels", ["instagram", "facebook"])

    gerados = 0
    async with AsyncSessionLocal() as session:
        agente = await _get_agent(session, "hc-social")
        if not agente:
            raise RuntimeError("Agente hc-social nao encontrado no banco")

        for servico in servicos:
            for canal in canais:
                pergunta = f"Crie uma legenda para {canal} sobre o serviço: {servico}."
                resposta = await ai_service.chat(
                    messages=[{"role": "user", "content": pergunta}],
                    provider=agente.ai_provider or "ollama",
                    system_prompt=agente.system_prompt,
                    model=agente.model,
                    stream=False,
                )
                entrada = KnowledgeBase(
                    title=f"Post {canal.capitalize()} - {servico} - {datetime.now().strftime('%d/%m/%Y')}",
                    content=resposta,
                    category="Posts Sociais Gerados",
                    agent_id="hc-social",
                    tags=["auto-gerado", canal, "aguardando-revisao"],
                    is_public=False,
                )
                session.add(entrada)
                gerados += 1

        await session.commit()

    logger.info(f"Job social_content: {gerados} posts gerados e salvos na Knowledge Base")
    return {"posts_gerados": gerados, "servicos": len(servicos), "canais": len(canais)}


async def _job_backup(config: dict) -> dict:
    """Backup do banco SQLite com retencao configuravel."""
    keep_days = config.get("keep_days", 7)
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)

    if not DB_PATH.exists():
        raise RuntimeError(f"Banco nao encontrado em {DB_PATH}")

    destino = BACKUP_DIR / f"hctech_{datetime.now().strftime('%Y%m%d_%H%M%S')}.db"
    destino.write_bytes(DB_PATH.read_bytes())

    limite = datetime.now() - timedelta(days=keep_days)
    removidos = 0
    for arquivo in BACKUP_DIR.glob("hctech_*.db"):
        if datetime.fromtimestamp(arquivo.stat().st_mtime) < limite:
            arquivo.unlink()
            removidos += 1

    logger.info(f"Job backup: {destino.name} criado, {removidos} backup(s) antigo(s) removido(s)")
    return {"backup": str(destino.name), "removidos": removidos}


JOB_HANDLERS = {
    "social_content": _job_social_content,
    "backup": _job_backup,
    # "review_check" e "seo_report" ainda nao tem handler real implementado -
    # cadastrados no banco como pauta futura, disparam erro claro se agendados.
}


async def execute_job(job_id: int) -> dict:
    """Executa um job (chamado pelo scheduler OU pelo endpoint manual /run).
    Fonte unica de verdade - nunca so incrementa contador sem rodar nada."""
    async with AsyncSessionLocal() as session:
        result = await session.execute(select(AutomationJob).where(AutomationJob.id == job_id))
        job = result.scalar_one_or_none()
        if not job:
            raise ValueError(f"Job {job_id} nao encontrado")

        job.last_run = datetime.utcnow()
        job.run_count += 1

        handler = JOB_HANDLERS.get(job.job_type)
        if not handler:
            job.error_count += 1
            job.last_error = f"job_type '{job.job_type}' ainda nao tem handler implementado"
            await session.commit()
            raise NotImplementedError(job.last_error)

        try:
            dados = await handler(job.config or {})
            job.success_count += 1
            job.last_error = None
            await session.commit()
            return {"job": job.name, "status": "sucesso", "dados": dados}
        except Exception as e:
            job.error_count += 1
            job.last_error = str(e)
            await session.commit()
            logger.error(f"Job '{job.name}' falhou: {e}")
            raise


async def _carregar_e_agendar_jobs():
    """Le jobs ativos do banco e agenda no scheduler via cron trigger."""
    async with AsyncSessionLocal() as session:
        result = await session.execute(select(AutomationJob).where(AutomationJob.is_active == True))
        jobs = result.scalars().all()

    agendados = 0
    for job in jobs:
        if job.job_type not in JOB_HANDLERS:
            logger.warning(f"Job '{job.name}' (id={job.id}) tem job_type '{job.job_type}' sem handler - nao agendado")
            continue
        try:
            scheduler.add_job(
                execute_job,
                trigger=CronTrigger.from_crontab(job.schedule),
                args=[job.id],
                id=f"job_{job.id}",
                replace_existing=True,
                misfire_grace_time=3600,
            )
            agendados += 1
        except Exception as e:
            logger.error(f"Falha ao agendar job '{job.name}': {e}")

    logger.info(f"Scheduler: {agendados}/{len(jobs)} job(s) ativo(s) agendado(s)")


async def start_scheduler():
    await _carregar_e_agendar_jobs()
    scheduler.start()
    logger.info("Scheduler de automacao iniciado")


async def stop_scheduler():
    if scheduler.running:
        scheduler.shutdown(wait=False)
        logger.info("Scheduler de automacao encerrado")
