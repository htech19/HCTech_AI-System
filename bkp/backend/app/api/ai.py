"""API de IA - Chat, Streaming e Status"""
import json
import asyncio
from typing import Optional
from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from loguru import logger
from app.services.ai_service import ai_service, AIProvider
from app.database import AsyncSessionLocal, Agent, Conversation

router = APIRouter()

class ChatRequest(BaseModel):
    messages: list[dict]
    provider: Optional[str] = None
    agent_id: Optional[str] = None
    temperature: float = 0.7
    max_tokens: int = 2000

class QuickRequest(BaseModel):
    prompt: str
    provider: Optional[str] = None
    agent_id: Optional[str] = None

async def get_agent_prompt(agent_id: str) -> Optional[str]:
    if not agent_id:
        return None
    async with AsyncSessionLocal() as session:
        from sqlalchemy import select
        r = await session.execute(select(Agent).where(Agent.id == agent_id))
        agent = r.scalar_one_or_none()
        return agent.system_prompt if agent else None

@router.get("/status")
async def get_status():
    providers = await ai_service.status()
    return {"providers": providers, "default": "ollama"}

@router.post("/chat")
async def chat(req: ChatRequest):
    provider = req.provider or "ollama"
    system_prompt = await get_agent_prompt(req.agent_id)
    try:
        response = await ai_service.chat(req.messages, provider, system_prompt, req.temperature, req.max_tokens)
        if req.agent_id:
            async with AsyncSessionLocal() as s:
                last_user = next((m for m in reversed(req.messages) if m["role"] == "user"), None)
                if last_user:
                    s.add(Conversation(agent_id=req.agent_id, role="user", content=last_user["content"], ai_provider=provider))
                s.add(Conversation(agent_id=req.agent_id, role="assistant", content=response, ai_provider=provider))
                await s.commit()
        return {"response": response, "provider": provider}
    except Exception as e:
        logger.error(f"Chat error: {e}")
        raise HTTPException(500, str(e))

@router.post("/chat/stream")
async def chat_stream(req: ChatRequest):
    provider = req.provider or "ollama"
    system_prompt = await get_agent_prompt(req.agent_id)
    
    async def gen():
        full = ""
        try:
            yield f"data: {json.dumps({'type':'start','provider':provider})}\n\n"
            async for chunk in await ai_service.chat(req.messages, provider, system_prompt, req.temperature, req.max_tokens, stream=True):
                full += chunk
                yield f"data: {json.dumps({'type':'chunk','content':chunk})}\n\n"
                await asyncio.sleep(0)
            yield f"data: {json.dumps({'type':'done','chars':len(full)})}\n\n"
            if req.agent_id and full:
                async with AsyncSessionLocal() as s:
                    last_user = next((m for m in reversed(req.messages) if m["role"] == "user"), None)
                    if last_user:
                        s.add(Conversation(agent_id=req.agent_id, role="user", content=last_user["content"], ai_provider=provider))
                    s.add(Conversation(agent_id=req.agent_id, role="assistant", content=full, ai_provider=provider))
                    await s.commit()
        except Exception as e:
            yield f"data: {json.dumps({'type':'error','message':str(e)})}\n\n"
    
    return StreamingResponse(gen(), media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"})

@router.post("/quick")
async def quick(req: QuickRequest):
    system_prompt = await get_agent_prompt(req.agent_id)
    r = await ai_service.chat([{"role": "user", "content": req.prompt}], req.provider, system_prompt)
    return {"response": r, "provider": req.provider or "ollama"}

@router.post("/analyze/sentiment")
async def sentiment(body: dict):
    text = body.get("text", "")
    if not text:
        raise HTTPException(400, "Texto não fornecido")
    s = await ai_service.analyze_sentiment(text)
    return {"sentiment": s}

@router.post("/generate/review-response")
async def review_response(body: dict):
    r = await ai_service.generate_review_response(body.get("review",""), body.get("rating",5), body.get("business_name","HC Tech"))
    return {"response": r}