"""API de IA - Chat, Streaming e Status dos Provedores"""
import json
import asyncio
from typing import Optional
from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from loguru import logger
from app.services.ai_service import ai_service
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


async def _get_agent_prompt(agent_id: str) -> Optional[str]:
    """Buscar system prompt do agente no banco"""
    if not agent_id:
        return None
    try:
        async with AsyncSessionLocal() as session:
            from sqlalchemy import select
            result = await session.execute(
                select(Agent).where(Agent.id == agent_id)
            )
            agent = result.scalar_one_or_none()
            return agent.system_prompt if agent else None
    except Exception as e:
        logger.error(f"Erro ao buscar agente {agent_id}: {e}")
        return None


async def _save_conversation(agent_id: str, user_msg: str, assistant_msg: str, provider: str):
    """Salvar conversa no banco"""
    try:
        async with AsyncSessionLocal() as session:
            session.add(Conversation(
                agent_id=agent_id,
                role="user",
                content=user_msg,
                ai_provider=provider,
            ))
            session.add(Conversation(
                agent_id=agent_id,
                role="assistant",
                content=assistant_msg,
                ai_provider=provider,
            ))
            await session.commit()
    except Exception as e:
        logger.error(f"Erro ao salvar conversa: {e}")


@router.get("/status")
async def get_ai_status():
    """Status de todos os provedores de IA"""
    providers = await ai_service.status()
    return {
        "providers": providers,
        "default": "ollama",
    }


@router.post("/chat")
async def chat(req: ChatRequest):
    """Chat com IA (nao-streaming)"""
    provider = req.provider or "ollama"
    system_prompt = await _get_agent_prompt(req.agent_id)

    try:
        response = await ai_service.chat(
            messages=req.messages,
            provider=provider,
            system_prompt=system_prompt,
            temperature=req.temperature,
            max_tokens=req.max_tokens,
            stream=False,
        )

        # Salvar no banco
        if req.agent_id and req.messages:
            last_user = next(
                (m["content"] for m in reversed(req.messages) if m["role"] == "user"),
                None,
            )
            if last_user:
                await _save_conversation(req.agent_id, last_user, response, provider)

        return {"response": response, "provider": provider, "agent_id": req.agent_id}

    except Exception as e:
        logger.error(f"Erro no chat: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/chat/stream")
async def chat_stream(req: ChatRequest):
    """Chat com streaming SSE"""
    provider = req.provider or "ollama"
    system_prompt = await _get_agent_prompt(req.agent_id)

    async def generate():
        full_response = ""
        try:
            # Sinalizar inicio
            yield f"data: {json.dumps({'type': 'start', 'provider': provider})}\n\n"

            # Stream de chunks
            async for chunk in await ai_service.chat(
                messages=req.messages,
                provider=provider,
                system_prompt=system_prompt,
                temperature=req.temperature,
                max_tokens=req.max_tokens,
                stream=True,
            ):
                full_response += chunk
                yield f"data: {json.dumps({'type': 'chunk', 'content': chunk})}\n\n"
                await asyncio.sleep(0)  # Yield control

            # Sinalizar fim
            yield f"data: {json.dumps({'type': 'done', 'chars': len(full_response)})}\n\n"

            # Salvar no banco apos streaming completo
            if req.agent_id and full_response and req.messages:
                last_user = next(
                    (m["content"] for m in reversed(req.messages) if m["role"] == "user"),
                    None,
                )
                if last_user:
                    await _save_conversation(req.agent_id, last_user, full_response, provider)

        except Exception as e:
            logger.error(f"Erro no streaming: {e}")
            yield f"data: {json.dumps({'type': 'error', 'message': str(e)})}\n\n"

    return StreamingResponse(
        generate(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
            "Connection": "keep-alive",
        },
    )


@router.post("/quick")
async def quick_chat(req: QuickRequest):
    """Chat rapido com prompt simples"""
    provider = req.provider or "ollama"
    system_prompt = await _get_agent_prompt(req.agent_id)

    try:
        response = await ai_service.chat(
            messages=[{"role": "user", "content": req.prompt}],
            provider=provider,
            system_prompt=system_prompt,
            stream=False,
        )
        return {"response": response, "provider": provider}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/analyze/sentiment")
async def analyze_sentiment(body: dict):
    """Analisar sentimento de texto"""
    text = body.get("text", "")
    if not text:
        raise HTTPException(status_code=400, detail="Texto nao fornecido")

    sentiment = await ai_service.analyze_sentiment(text)
    return {"sentiment": sentiment, "text": text[:100]}


@router.post("/generate/review-response")
async def generate_review_response(body: dict):
    """Gerar resposta automatica para avaliacao"""
    review = body.get("review", "")
    rating = body.get("rating", 5)
    business = body.get("business_name", "HC Tech")

    if not review:
        raise HTTPException(status_code=400, detail="Review nao fornecido")

    response = await ai_service.generate_review_response(review, rating, business)
    return {"response": response, "rating": rating}


@router.post("/generate/social-post")
async def generate_social_post(body: dict):
    """Gerar post para redes sociais"""
    import re
    platform = body.get("platform", "instagram")
    topic = body.get("topic", "")
    post_type = body.get("post_type", "engagement")

    if not topic:
        raise HTTPException(status_code=400, detail="Topico nao fornecido")

    specs = {
        "instagram": "Instagram (max 2200 chars, use emojis, hashtags no final)",
        "facebook": "Facebook (mais informal, pode ser mais longo, menos hashtags)",
    }

    content = await ai_service.chat(
        messages=[{
            "role": "user",
            "content": f"""Crie um post para {specs.get(platform, specs['instagram'])} 
sobre assistencia tecnica de celulares: {topic}

Responda SOMENTE em JSON valido:
{{"caption": "texto do post", "hashtags": ["tag1", "tag2"], "cta": "call to action", "best_time": "19:00"}}"""
        }],
        temperature=0.8,
        max_tokens=500,
    )

    try:
        match = re.search(r'\{[^{}]*\}', content, re.DOTALL)
        if match:
            return json.loads(match.group())
    except Exception:
        pass

    return {
        "caption": content,
        "hashtags": ["#assistenciatecnica", "#celular", "#smartphone"],
        "cta": "Entre em contato!",
        "best_time": "19:00",
    }


@router.post("/generate/seo-content")
async def generate_seo_content(body: dict):
    """Gerar conteudo SEO otimizado"""
    keyword = body.get("keyword", "")
    content_type = body.get("content_type", "blog_post")

    if not keyword:
        raise HTTPException(status_code=400, detail="Keyword nao fornecida")

    prompts = {
        "blog_post": f"Escreva um artigo de 400 palavras sobre '{keyword}' para assistencia tecnica de celulares. Inclua H2 e H3.",
        "meta_description": f"Crie uma meta description de 155 caracteres para '{keyword}' de assistencia tecnica.",
        "title": f"Crie 5 titulos SEO para '{keyword}' de assistencia tecnica de celulares.",
    }

    content = await ai_service.chat(
        messages=[{"role": "user", "content": prompts.get(content_type, prompts["blog_post"])}],
        temperature=0.8,
        max_tokens=1000,
    )

    return {"content": content, "keyword": keyword, "type": content_type}
