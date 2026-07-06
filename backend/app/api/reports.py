"""API de Relatórios"""
from datetime import datetime
from fastapi import APIRouter
from app.database import AsyncSessionLocal, Report, SEOKeyword, Review
from app.services.ai_service import ai_service
from sqlalchemy import select

router = APIRouter()

@router.get("")
async def get_reports():
    async with AsyncSessionLocal() as s:
        r = await s.execute(select(Report).order_by(Report.generated_at.desc()).limit(10))
        reports = r.scalars().all()
        return [{"id": rp.id, "title": rp.title, "type": rp.report_type,
                 "generated_at": rp.generated_at.isoformat()} for rp in reports]

@router.post("/generate")
async def generate_report(body: dict):
    report_type = body.get("type", "monthly")
    
    async with AsyncSessionLocal() as s:
        keywords = (await s.execute(select(SEOKeyword).limit(5))).scalars().all()
        reviews = (await s.execute(select(Review).limit(5))).scalars().all()
    
    prompts = {
        "seo": f"Gere um relatório de auditoria SEO para assistência técnica com keywords: {[k.keyword for k in keywords]}. Inclua análise técnica, problemas e recomendações.",
        "ranking": f"Gere um relatório de rankings com estas keywords: {[(k.keyword, k.position) for k in keywords]}. Análise de tendências e oportunidades.",
        "monthly": f"Gere um relatório mensal completo para assistência técnica HC Tech. Reviews: {len(reviews)}, Média: {sum(r.rating for r in reviews)/len(reviews) if reviews else 0:.1f}★. Inclua: conquistas, áreas de melhoria, recomendações.",
        "social": "Gere um relatório de redes sociais para assistência técnica. Analise: engajamento, crescimento, melhores conteúdos e recomendações.",
    }
    
    content = await ai_service.chat([{"role": "user", "content": prompts.get(report_type, prompts["monthly"])}], max_tokens=1500)
    
    titles = {"seo": "Auditoria SEO", "ranking": "Ranking de Termos", "monthly": "Relatório Mensal", "social": "Análise Social Media"}
    
    async with AsyncSessionLocal() as s:
        report = Report(title=f"{titles.get(report_type, 'Relatório')} - {datetime.now().strftime('%B %Y')}",
                        report_type=report_type, content=content, ai_summary=content[:500])
        s.add(report)
        await s.commit()
    
    return {"report": content, "type": report_type, "generated_at": datetime.utcnow().isoformat()}