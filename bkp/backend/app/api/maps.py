"""API Google Maps / Reviews"""
from datetime import datetime
from fastapi import APIRouter, HTTPException
from sqlalchemy import select
from app.database import AsyncSessionLocal, Review
from app.services.ai_service import ai_service

router = APIRouter()

@router.get("/reviews")
async def get_reviews():
    async with AsyncSessionLocal() as s:
        r = await s.execute(select(Review).order_by(Review.review_date.desc()))
        reviews = r.scalars().all()
        return [{"id": rv.id, "author": rv.author, "rating": rv.rating, "content": rv.content,
                 "source": rv.source, "sentiment": rv.sentiment, "ai_response": rv.ai_response,
                 "responded": rv.responded, "review_date": rv.review_date.isoformat()} for rv in reviews]

@router.post("/reviews/{review_id}/respond")
async def respond_review(review_id: int, body: dict):
    response_text = body.get("response", "")
    async with AsyncSessionLocal() as s:
        r = await s.execute(select(Review).where(Review.id == review_id))
        rv = r.scalar_one_or_none()
        if not rv:
            raise HTTPException(404, "Review não encontrado")
        rv.ai_response = response_text
        rv.responded = True
        rv.response_date = datetime.utcnow()
        await s.commit()
    return {"message": "Resposta salva"}

@router.post("/reviews/{review_id}/auto-respond")
async def auto_respond(review_id: int):
    async with AsyncSessionLocal() as s:
        r = await s.execute(select(Review).where(Review.id == review_id))
        rv = r.scalar_one_or_none()
        if not rv:
            raise HTTPException(404, "Review não encontrado")
        response = await ai_service.generate_review_response(rv.content, rv.rating)
        rv.ai_response = response
        rv.responded = True
        rv.response_date = datetime.utcnow()
        await s.commit()
        return {"response": response, "message": "Resposta gerada pela IA"}

@router.get("/profile")
async def get_profile():
    async with AsyncSessionLocal() as s:
        r = await s.execute(select(Review))
        reviews = r.scalars().all()
        total = len(reviews)
        avg = sum(rv.rating for rv in reviews) / total if total else 0
        responded = len([rv for rv in reviews if rv.responded])
        return {
            "name": "HC Tech Assistência Técnica", "rating": round(avg, 1),
            "total_reviews": total, "responded_reviews": responded,
            "response_rate": f"{int(responded/total*100)}%" if total else "0%",
            "profile_completeness": 87,
            "monthly_views": 1247, "calls": 89, "directions": 156,
            "status": "Verificado ✓"
        }