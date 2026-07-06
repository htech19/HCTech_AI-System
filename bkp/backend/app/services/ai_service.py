"""Serviço de IA Híbrido - Ollama Local + OpenAI + Anthropic"""
import json
import asyncio
from typing import AsyncGenerator, Optional, Literal
from loguru import logger
import httpx
import os
import sys

root_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
env_file = os.path.join(root_dir, ".env")
if os.path.exists(env_file):
    from dotenv import load_dotenv
    load_dotenv(env_file)

AIProvider = Literal["ollama", "openai", "anthropic"]

OLLAMA_URL = os.getenv("OLLAMA_API_URL", "http://localhost:11434")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "llama3.2:3b")
OLLAMA_TIMEOUT = int(os.getenv("OLLAMA_TIMEOUT", "120"))
OPENAI_KEY = os.getenv("OPENAI_API_KEY", "")
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
ANTHROPIC_KEY = os.getenv("ANTHROPIC_API_KEY", "")
ANTHROPIC_MODEL = os.getenv("ANTHROPIC_MODEL", "claude-3-haiku-20240307")
DEFAULT_PROVIDER = os.getenv("DEFAULT_AI_PROVIDER", "ollama")

class AIService:
    def __init__(self):
        self._openai = None
        self._anthropic = None
        if OPENAI_KEY:
            try:
                from openai import AsyncOpenAI
                self._openai = AsyncOpenAI(api_key=OPENAI_KEY)
            except ImportError:
                pass
        if ANTHROPIC_KEY:
            try:
                import anthropic
                self._anthropic = anthropic.AsyncAnthropic(api_key=ANTHROPIC_KEY)
            except ImportError:
                pass

    async def check_ollama(self) -> bool:
        try:
            async with httpx.AsyncClient(timeout=5.0) as c:
                r = await c.get(f"{OLLAMA_URL}/api/tags")
                return r.status_code == 200
        except:
            return False

    async def get_ollama_models(self) -> list:
        try:
            async with httpx.AsyncClient(timeout=5.0) as c:
                r = await c.get(f"{OLLAMA_URL}/api/tags")
                data = r.json()
                return [m["name"] for m in data.get("models", [])]
        except:
            return []

    async def status(self) -> list:
        ollama_ok = await self.check_ollama()
        models = await self.get_ollama_models() if ollama_ok else []
        return [
            {"provider": "ollama", "name": "Ollama (Local)", "model": OLLAMA_MODEL,
             "available": ollama_ok, "local": True, "free": True,
             "models": models, "description": "100% privado, roda no seu PC"},
            {"provider": "openai", "name": "OpenAI GPT", "model": OPENAI_MODEL,
             "available": bool(self._openai), "local": False, "free": False,
             "description": "GPT-4o Mini - Rápido e preciso"},
            {"provider": "anthropic", "name": "Anthropic Claude", "model": ANTHROPIC_MODEL,
             "available": bool(self._anthropic), "local": False, "free": False,
             "description": "Claude Haiku - Analítico e criativo"},
        ]

    async def chat(self, messages: list, provider: str = None, system_prompt: str = None,
                   temperature: float = 0.7, max_tokens: int = 2000, stream: bool = False):
        p = provider or DEFAULT_PROVIDER
        if system_prompt:
            messages = [{"role": "system", "content": system_prompt}] + messages
        if stream:
            return self._stream(messages, p, temperature, max_tokens)
        return await self._complete(messages, p, temperature, max_tokens)

    async def _complete(self, messages, provider, temperature, max_tokens):
        try:
            if provider == "ollama":
                return await self._ollama_chat(messages, temperature, max_tokens)
            elif provider == "openai":
                return await self._openai_chat(messages, temperature, max_tokens)
            elif provider == "anthropic":
                return await self._anthropic_chat(messages, temperature, max_tokens)
        except Exception as e:
            logger.error(f"Erro {provider}: {e}")
            if provider != "ollama" and await self.check_ollama():
                logger.info("Fallback para Ollama...")
                return await self._ollama_chat(messages, temperature, max_tokens)
            raise

    async def _stream(self, messages, provider, temperature, max_tokens):
        try:
            if provider == "ollama":
                async for c in self._ollama_stream(messages, temperature, max_tokens):
                    yield c
            elif provider == "openai":
                async for c in self._openai_stream(messages, temperature, max_tokens):
                    yield c
            elif provider == "anthropic":
                async for c in self._anthropic_stream(messages, temperature, max_tokens):
                    yield c
        except Exception as e:
            yield f"\n\n[Erro: {e}]"

    async def _ollama_chat(self, messages, temperature, max_tokens):
        async with httpx.AsyncClient(timeout=OLLAMA_TIMEOUT) as c:
            r = await c.post(f"{OLLAMA_URL}/api/chat", json={
                "model": OLLAMA_MODEL, "messages": messages, "stream": False,
                "options": {"temperature": temperature, "num_predict": max_tokens}
            })
            r.raise_for_status()
            return r.json()["message"]["content"]

    async def _ollama_stream(self, messages, temperature, max_tokens):
        async with httpx.AsyncClient(timeout=OLLAMA_TIMEOUT) as c:
            async with c.stream("POST", f"{OLLAMA_URL}/api/chat", json={
                "model": OLLAMA_MODEL, "messages": messages, "stream": True,
                "options": {"temperature": temperature, "num_predict": max_tokens}
            }) as r:
                async for line in r.aiter_lines():
                    if line:
                        try:
                            d = json.loads(line)
                            if "message" in d and "content" in d["message"]:
                                yield d["message"]["content"]
                            if d.get("done"):
                                break
                        except:
                            continue

    async def _openai_chat(self, messages, temperature, max_tokens):
        if not self._openai:
            raise ValueError("OpenAI não configurado. Adicione OPENAI_API_KEY no .env")
        r = await self._openai.chat.completions.create(
            model=OPENAI_MODEL, messages=messages, temperature=temperature, max_tokens=max_tokens)
        return r.choices[0].message.content

    async def _openai_stream(self, messages, temperature, max_tokens):
        if not self._openai:
            raise ValueError("OpenAI não configurado")
        stream = await self._openai.chat.completions.create(
            model=OPENAI_MODEL, messages=messages, temperature=temperature,
            max_tokens=max_tokens, stream=True)
        async for chunk in stream:
            if chunk.choices[0].delta.content:
                yield chunk.choices[0].delta.content

    async def _anthropic_chat(self, messages, temperature, max_tokens):
        if not self._anthropic:
            raise ValueError("Anthropic não configurado. Adicione ANTHROPIC_API_KEY no .env")
        system = next((m["content"] for m in messages if m["role"] == "system"), "Você é um assistente útil.")
        msgs = [m for m in messages if m["role"] != "system"]
        r = await self._anthropic.messages.create(
            model=ANTHROPIC_MODEL, max_tokens=max_tokens, system=system,
            messages=msgs, temperature=temperature)
        return r.content[0].text

    async def _anthropic_stream(self, messages, temperature, max_tokens):
        if not self._anthropic:
            raise ValueError("Anthropic não configurado")
        system = next((m["content"] for m in messages if m["role"] == "system"), "Você é um assistente útil.")
        msgs = [m for m in messages if m["role"] != "system"]
        async with self._anthropic.messages.stream(
            model=ANTHROPIC_MODEL, max_tokens=max_tokens, system=system,
            messages=msgs, temperature=temperature) as s:
            async for text in s.text_stream:
                yield text

    async def analyze_sentiment(self, text: str) -> str:
        try:
            r = await self.chat([{"role": "user", "content": f'Analise o sentimento e responda APENAS uma palavra: "positive", "negative" ou "neutral". Texto: "{text[:200]}"'}], temperature=0.1, max_tokens=10)
            s = r.strip().lower()
            return s if s in ["positive", "negative", "neutral"] else "neutral"
        except:
            return "neutral"

    async def generate_review_response(self, review: str, rating: int, business: str = "HC Tech") -> str:
        tone = "agradecido e entusiasmado" if rating >= 4 else "empático e solícito"
        return await self.chat([{"role": "user", "content": f"Resposta profissional para avaliação de assistência técnica:\n\nAvaliação ({rating}⭐): \"{review}\"\n\nTom: {tone}. Mencione {business}. Máx 3-4 frases. Use 1-2 emojis. Em português brasileiro."}], temperature=0.7, max_tokens=200)

ai_service = AIService()