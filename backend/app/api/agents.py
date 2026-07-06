"""API de Agentes"""
from fastapi import APIRouter, HTTPException
from sqlalchemy import select, delete
from app.database import AsyncSessionLocal, Agent, Conversation
from pydantic import BaseModel
from typing import Optional

router = APIRouter()

@router.get("")
async def list_agents():
    async with AsyncSessionLocal() as s:
        r = await s.execute(select(Agent).order_by(Agent.created_at))
        agents = r.scalars().all()
        return [{"id": a.id, "name": a.name, "role": a.role, "description": a.description,
                 "system_prompt": a.system_prompt, "avatar": a.avatar, "color": a.color,
                 "is_active": a.is_active, "ai_provider": a.ai_provider} for a in agents]

@router.get("/{agent_id}")
async def get_agent(agent_id: str):
    async with AsyncSessionLocal() as s:
        r = await s.execute(select(Agent).where(Agent.id == agent_id))
        a = r.scalar_one_or_none()
        if not a:
            raise HTTPException(404, "Agente não encontrado")
        return {"id": a.id, "name": a.name, "role": a.role, "description": a.description,
                "system_prompt": a.system_prompt, "avatar": a.avatar, "color": a.color,
                "is_active": a.is_active, "ai_provider": a.ai_provider}

@router.get("/{agent_id}/history")
async def get_history(agent_id: str, limit: int = 50):
    async with AsyncSessionLocal() as s:
        r = await s.execute(
            select(Conversation).where(Conversation.agent_id == agent_id)
            .order_by(Conversation.created_at).limit(limit))
        convs = r.scalars().all()
        return [{"role": c.role, "content": c.content, "provider": c.ai_provider,
                 "created_at": c.created_at.isoformat()} for c in convs]

@router.delete("/{agent_id}/history")
async def clear_history(agent_id: str):
    async with AsyncSessionLocal() as s:
        await s.execute(delete(Conversation).where(Conversation.agent_id == agent_id))
        await s.commit()
    return {"message": "Histórico limpo"}

class AgentUpdate(BaseModel):
    system_prompt: Optional[str] = None
    ai_provider: Optional[str] = None
    is_active: Optional[bool] = None

@router.patch("/{agent_id}")
async def update_agent(agent_id: str, data: AgentUpdate):
    async with AsyncSessionLocal() as s:
        r = await s.execute(select(Agent).where(Agent.id == agent_id))
        a = r.scalar_one_or_none()
        if not a:
            raise HTTPException(404, "Agente não encontrado")
        if data.system_prompt is not None:
            a.system_prompt = data.system_prompt
        if data.ai_provider is not None:
            a.ai_provider = data.ai_provider
        if data.is_active is not None:
            a.is_active = data.is_active
        await s.commit()
        return {"message": "Agente atualizado"}