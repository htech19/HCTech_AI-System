"""API de Métricas"""
from fastapi import APIRouter
from app.database import AsyncSessionLocal, Review, Task, SEOKeyword, SocialPost
from sqlalchemy import select, func

router = APIRouter()

@router.get("/dashboard")
async def get_dashboard():
    async with AsyncSessionLocal() as s:
        reviews = (await s.execute(select(Review))).scalars().all()
        tasks = (await s.execute(select(Task))).scalars().all()
        keywords = (await s.execute(select(SEOKeyword))).scalars().all()
        
        total_rev = len(reviews)
        avg_rating = sum(r.rating for r in reviews) / total_rev if total_rev else 0
        pending_rev = len([r for r in reviews if not r.responded])
        
        total_tasks = len(tasks)
        done_tasks = len([t for t in tasks if t.status == "done"])
        
        total_kw = len(keywords)
        top10_kw = len([k for k in keywords if k.position <= 10])
        avg_pos = sum(k.position for k in keywords) / total_kw if total_kw else 0
        
        return {
            "leads_organicos": {"value": 147, "change": "+23%", "trend": "up"},
            "visitantes_unicos": {"value": 2847, "change": "+18%", "trend": "up"},
            "avaliacao_google": {"value": round(avg_rating, 1), "total": total_rev, "pending": pending_rev},
            "ranking_seo": {"avg_position": round(avg_pos, 1), "total_keywords": total_kw, "top10": top10_kw},
            "taxa_conversao": {"value": 14.2, "change": "-0.8%", "trend": "down"},
            "engajamento_social": {"value": 8.4, "change": "+1.2%", "trend": "up"},
            "tasks": {"total": total_tasks, "done": done_tasks, "pending": total_tasks - done_tasks},
            "maps": {"views": 1247, "calls": 89, "directions": 156, "website_clicks": 234},
            "weekly_data": [
                {"day": "Seg", "leads": 12, "trafego": 145, "conversao": 8},
                {"day": "Ter", "leads": 18, "trafego": 198, "conversao": 12},
                {"day": "Qua", "leads": 15, "trafego": 167, "conversao": 10},
                {"day": "Qui", "leads": 22, "trafego": 234, "conversao": 15},
                {"day": "Sex", "leads": 28, "trafego": 289, "conversao": 19},
                {"day": "Sab", "leads": 35, "trafego": 312, "conversao": 24},
                {"day": "Dom", "leads": 20, "trafego": 178, "conversao": 14},
            ]
        }