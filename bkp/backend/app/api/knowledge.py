"""API Base de Conhecimento"""
from datetime import datetime
from fastapi import APIRouter, HTTPException
from sqlalchemy import select, or_
from app.database import AsyncSessionLocal, KnowledgeBase
from pydantic import BaseModel
from typing import Optional, List

router = APIRouter()

class ArticleCreate(BaseModel):
    title: str
    content: str
    category: str
    agent_id: Optional[str] = None
    tags: List[str] = []

@router.get("")
async def list_articles(search: Optional[str] = None, category: Optional[str] = None):
    async with AsyncSessionLocal() as s:
        q = select(KnowledgeBase).order_by(KnowledgeBase.created_at.desc())
        if search:
            q = q.where(or_(KnowledgeBase.title.contains(search), KnowledgeBase.content.contains(search)))
        if category:
            q = q.where(KnowledgeBase.category == category)
        r = await s.execute(q)
        arts = r.scalars().all()
        return [{"id": a.id, "title": a.title, "content": a.content, "category": a.category,
                 "agent_id": a.agent_id, "tags": a.tags, "view_count": a.view_count,
                 "created_at": a.created_at.isoformat()} for a in arts]

@router.post("")
async def create_article(data: ArticleCreate):
    async with AsyncSessionLocal() as s:
        art = KnowledgeBase(title=data.title, content=data.content, category=data.category,
                             agent_id=data.agent_id, tags=data.tags)
        s.add(art)
        await s.commit()
        await s.refresh(art)
        return {"id": art.id, "message": "Artigo criado"}

@router.put("/{article_id}")
async def update_article(article_id: int, data: ArticleCreate):
    async with AsyncSessionLocal() as s:
        r = await s.execute(select(KnowledgeBase).where(KnowledgeBase.id == article_id))
        a = r.scalar_one_or_none()
        if not a:
            raise HTTPException(404, "Artigo não encontrado")
        a.title = data.title
        a.content = data.content
        a.category = data.category
        a.updated_at = datetime.utcnow()
        await s.commit()
        return {"message": "Artigo atualizado"}

@router.delete("/{article_id}")
async def delete_article(article_id: int):
    async with AsyncSessionLocal() as s:
        r = await s.execute(select(KnowledgeBase).where(KnowledgeBase.id == article_id))
        a = r.scalar_one_or_none()
        if not a:
            raise HTTPException(404, "Artigo não encontrado")
        await s.delete(a)
        await s.commit()
        return {"message": "Artigo removido"}