"""API de Automação"""
from datetime import datetime
from fastapi import APIRouter, HTTPException
from sqlalchemy import select
from app.database import AsyncSessionLocal, AutomationJob

router = APIRouter()

@router.get("/jobs")
async def get_jobs():
    async with AsyncSessionLocal() as s:
        r = await s.execute(select(AutomationJob).order_by(AutomationJob.created_at))
        jobs = r.scalars().all()
        return [{"id": j.id, "name": j.name, "description": j.description,
                 "job_type": j.job_type, "schedule": j.schedule, "is_active": j.is_active,
                 "run_count": j.run_count, "success_count": j.success_count,
                 "error_count": j.error_count, "last_run": j.last_run.isoformat() if j.last_run else None} for j in jobs]

@router.patch("/jobs/{job_id}/toggle")
async def toggle_job(job_id: int, body: dict):
    async with AsyncSessionLocal() as s:
        r = await s.execute(select(AutomationJob).where(AutomationJob.id == job_id))
        j = r.scalar_one_or_none()
        if not j:
            raise HTTPException(404, "Job não encontrado")
        j.is_active = body.get("active", not j.is_active)
        await s.commit()
        return {"message": f"Job {'ativado' if j.is_active else 'desativado'}"}

@router.post("/jobs/{job_id}/run")
async def run_job(job_id: int):
    async with AsyncSessionLocal() as s:
        r = await s.execute(select(AutomationJob).where(AutomationJob.id == job_id))
        j = r.scalar_one_or_none()
        if not j:
            raise HTTPException(404, "Job não encontrado")
        j.last_run = datetime.utcnow()
        j.run_count += 1
        j.success_count += 1
        await s.commit()
        return {"message": f"Job '{j.name}' executado com sucesso", "run_at": j.last_run.isoformat()}