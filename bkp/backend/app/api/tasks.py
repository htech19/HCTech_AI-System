"""API de Tarefas - Kanban"""
from datetime import datetime
from fastapi import APIRouter, HTTPException
from sqlalchemy import select
from app.database import AsyncSessionLocal, Task
from pydantic import BaseModel
from typing import Optional, List

router = APIRouter()

class TaskCreate(BaseModel):
    title: str
    description: str = ""
    status: str = "todo"
    priority: str = "medium"
    agent_id: Optional[str] = None
    tags: List[str] = []

class TaskUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    priority: Optional[str] = None
    agent_id: Optional[str] = None
    tags: Optional[List[str]] = None

@router.get("")
async def list_tasks(status: Optional[str] = None):
    async with AsyncSessionLocal() as s:
        q = select(Task).order_by(Task.created_at.desc())
        if status:
            q = q.where(Task.status == status)
        r = await s.execute(q)
        tasks = r.scalars().all()
        return [{"id": t.id, "title": t.title, "description": t.description,
                 "status": t.status, "priority": t.priority, "agent_id": t.agent_id,
                 "tags": t.tags or [], "created_at": t.created_at.isoformat()} for t in tasks]

@router.post("")
async def create_task(data: TaskCreate):
    async with AsyncSessionLocal() as s:
        task = Task(title=data.title, description=data.description, status=data.status,
                    priority=data.priority, agent_id=data.agent_id, tags=data.tags)
        s.add(task)
        await s.commit()
        await s.refresh(task)
        return {"id": task.id, "title": task.title, "status": task.status, "message": "Tarefa criada"}

@router.put("/{task_id}")
async def update_task(task_id: int, data: TaskUpdate):
    async with AsyncSessionLocal() as s:
        r = await s.execute(select(Task).where(Task.id == task_id))
        t = r.scalar_one_or_none()
        if not t:
            raise HTTPException(404, "Tarefa não encontrada")
        if data.title: t.title = data.title
        if data.description is not None: t.description = data.description
        if data.priority: t.priority = data.priority
        if data.agent_id is not None: t.agent_id = data.agent_id
        if data.tags is not None: t.tags = data.tags
        t.updated_at = datetime.utcnow()
        await s.commit()
        return {"message": "Tarefa atualizada"}

@router.patch("/{task_id}/status")
async def move_task(task_id: int, body: dict):
    status = body.get("status")
    if status not in ["todo", "in_progress", "done"]:
        raise HTTPException(400, "Status inválido")
    async with AsyncSessionLocal() as s:
        r = await s.execute(select(Task).where(Task.id == task_id))
        t = r.scalar_one_or_none()
        if not t:
            raise HTTPException(404, "Tarefa não encontrada")
        t.status = status
        t.updated_at = datetime.utcnow()
        if status == "done":
            t.completed_at = datetime.utcnow()
        await s.commit()
        return {"message": f"Tarefa movida para {status}"}

@router.delete("/{task_id}")
async def delete_task(task_id: int):
    async with AsyncSessionLocal() as s:
        r = await s.execute(select(Task).where(Task.id == task_id))
        t = r.scalar_one_or_none()
        if not t:
            raise HTTPException(404, "Tarefa não encontrada")
        await s.delete(t)
        await s.commit()
        return {"message": "Tarefa removida"}