"""API Social Media"""
from datetime import datetime
from fastapi import APIRouter, HTTPException
from sqlalchemy import select
from app.database import AsyncSessionLocal, SocialPost
from app.services.ai_service import ai_service
from pydantic import BaseModel
from typing import Optional, List
import json, re

router = APIRouter()

class PostCreate(BaseModel):
    platform: str
    content: str
    hashtags: List[str] = []
    status: str = "draft"
    scheduled_at: Optional[str] = None

@router.get("/posts")
async def get_posts(platform: Optional[str] = None):
    async with AsyncSessionLocal() as s:
        q = select(SocialPost).order_by(SocialPost.created_at.desc())
        if platform:
            q = q.where(SocialPost.platform == platform)
        r = await s.execute(q)
        posts = r.scalars().all()
        return [{"id": p.id, "platform": p.platform, "content": p.content,
                 "hashtags": p.hashtags, "status": p.status, "likes": p.likes,
                 "comments": p.comments, "shares": p.shares, "reach": p.reach,
                 "created_at": p.created_at.isoformat()} for p in posts]

@router.post("/posts")
async def create_post(data: PostCreate):
    async with AsyncSessionLocal() as s:
        post = SocialPost(platform=data.platform, content=data.content,
                          hashtags=data.hashtags, status=data.status)
        s.add(post)
        await s.commit()
        await s.refresh(post)
        return {"id": post.id, "message": "Post criado"}

@router.get("/metrics")
async def get_metrics():
    return {
        "facebook": {"followers": 1247, "reach_week": 3891, "engagement_rate": 6.2, "posts_month": 18, "messages_pending": 3},
        "instagram": {"followers": 892, "reach_week": 2134, "engagement_rate": 8.9, "posts_month": 22, "stories_week": 14},
        "best_times": {"facebook": ["19:00", "12:00", "09:00"], "instagram": ["20:00", "13:00", "07:00"]}
    }

@router.post("/generate-post")
async def generate_post(body: dict):
    platform = body.get("platform", "instagram")
    topic = body.get("topic", "")
    post_type = body.get("post_type", "engagement")
    
    specs = {"instagram": "Instagram (máx 2200 chars, emojis, hashtags no final)", "facebook": "Facebook (mais informal, menos hashtags)"}
    
    content = await ai_service.chat([{"role": "user", "content": f"""Crie um post para {specs.get(platform, "Instagram")} sobre: {topic}
Assistência técnica de celulares.

Responda em JSON:
{{"caption": "texto", "hashtags": ["lista"], "cta": "call to action", "best_time": "horário"}}"""}], temperature=0.8, max_tokens=400)
    
    try:
        m = re.search(r'\{.*\}', content, re.DOTALL)
        if m:
            return json.loads(m.group())
    except:
        pass
    
    return {"caption": content, "hashtags": ["#assistenciatecnica", "#celular", "#smartphone"], "cta": "Entre em contato!", "best_time": "19:00"}