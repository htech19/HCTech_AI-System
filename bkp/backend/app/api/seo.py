"""API de SEO"""
from fastapi import APIRouter
from sqlalchemy import select
from app.database import AsyncSessionLocal, SEOKeyword
from app.services.ai_service import ai_service

router = APIRouter()

@router.get("/keywords")
async def get_keywords():
    async with AsyncSessionLocal() as s:
        r = await s.execute(select(SEOKeyword).order_by(SEOKeyword.position))
        kws = r.scalars().all()
        return [{"id": k.id, "keyword": k.keyword, "position": k.position,
                 "volume": k.volume, "difficulty": k.difficulty, "trend": k.trend,
                 "prev_position": k.prev_position} for k in kws]

@router.get("/health")
async def get_health():
    async with AsyncSessionLocal() as s:
        r = await s.execute(select(SEOKeyword))
        kws = r.scalars().all()
        total = len(kws)
        top10 = len([k for k in kws if k.position <= 10])
        avg_pos = sum(k.position for k in kws) / total if total else 0
        score = min(100, int((top10 / total * 60) + max(0, (20 - avg_pos) * 2))) if total else 0
        return {"health_score": score, "total_keywords": total, "top_10": top10,
                "avg_position": round(avg_pos, 1), "status": "bom" if score > 70 else "regular"}

@router.post("/generate-content")
async def generate_content(body: dict):
    keyword = body.get("keyword", "")
    content_type = body.get("content_type", "blog_post")
    prompts = {
        "blog_post": f"Escreva um artigo de blog de 400 palavras sobre '{keyword}' para assistência técnica de celulares. Inclua H2 e H3.",
        "meta_description": f"Crie uma meta description de 155 chars para '{keyword}' de assistência técnica.",
        "title": f"Crie 5 títulos SEO para '{keyword}' de assistência técnica.",
    }
    content = await ai_service.chat([{"role": "user", "content": prompts.get(content_type, prompts["blog_post"])}])
    return {"content": content, "keyword": keyword, "type": content_type}

@router.post("/audit")
async def run_audit():
    async with AsyncSessionLocal() as s:
        r = await s.execute(select(SEOKeyword))
        kws = r.scalars().all()
    
    prompt = f"""Faça uma auditoria SEO rápida para uma assistência técnica de celulares com estas keywords:
{chr(10).join([f"- {k.keyword}: posição {k.position}, volume {k.volume}" for k in kws[:5]])}

Forneça: 3 pontos fortes, 3 problemas, 5 recomendações de melhoria."""
    
    audit = await ai_service.chat([{"role": "user", "content": prompt}])
    return {"audit": audit, "keywords_analyzed": len(kws)}