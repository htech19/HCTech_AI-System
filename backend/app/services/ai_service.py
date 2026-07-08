"""
Servico de IA Hibrido - Ollama Local + OpenAI + Anthropic
Compativel com httpx >= 0.28.1
"""
import json
import asyncio
import os
from typing import AsyncGenerator, Optional
from loguru import logger

# Carregar .env
_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
_env = os.path.join(_root, ".env")
if os.path.exists(_env):
    from dotenv import load_dotenv
    load_dotenv(_env)

import httpx

OLLAMA_URL = os.getenv("OLLAMA_API_URL", "http://localhost:11434")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "llama3.2:3b")
OLLAMA_TIMEOUT = int(os.getenv("OLLAMA_TIMEOUT", "120"))
OPENAI_KEY = os.getenv("OPENAI_API_KEY", "")
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
ANTHROPIC_KEY = os.getenv("ANTHROPIC_API_KEY", "")
ANTHROPIC_MODEL = os.getenv("ANTHROPIC_MODEL", "claude-3-haiku-20240307")
DEFAULT_PROVIDER = os.getenv("DEFAULT_AI_PROVIDER", "ollama")


class AIService:
    """Servico central de IA com suporte hibrido Local/Online"""

    def __init__(self):
        self._openai = None
        self._anthropic = None

        if OPENAI_KEY and OPENAI_KEY.startswith("sk-"):
            try:
                from openai import AsyncOpenAI
                self._openai = AsyncOpenAI(api_key=OPENAI_KEY)
                logger.info("OpenAI configurado")
            except ImportError:
                logger.warning("openai nao instalado")
            except Exception as e:
                logger.warning(f"OpenAI erro: {e}")

        if ANTHROPIC_KEY and len(ANTHROPIC_KEY) > 10:
            try:
                import anthropic
                self._anthropic = anthropic.AsyncAnthropic(api_key=ANTHROPIC_KEY)
                logger.info("Anthropic configurado")
            except ImportError:
                logger.warning("anthropic nao instalado")
            except Exception as e:
                logger.warning(f"Anthropic erro: {e}")

    async def check_ollama(self) -> bool:
        """Verificar se Ollama esta disponivel"""
        try:
            async with httpx.AsyncClient(timeout=httpx.Timeout(5.0)) as c:
                r = await c.get(f"{OLLAMA_URL}/api/tags")
                return r.status_code == 200
        except Exception:
            return False

    async def get_ollama_models(self) -> list:
        """Listar modelos disponiveis no Ollama"""
        try:
            async with httpx.AsyncClient(timeout=httpx.Timeout(5.0)) as c:
                r = await c.get(f"{OLLAMA_URL}/api/tags")
                data = r.json()
                return [m["name"] for m in data.get("models", [])]
        except Exception:
            return []

    async def status(self) -> list:
        """Status de todos os provedores"""
        ollama_ok = await self.check_ollama()
        models = await self.get_ollama_models() if ollama_ok else []
        return [
            {
                "provider": "ollama",
                "name": "Ollama (Local)",
                "model": OLLAMA_MODEL,
                "available": ollama_ok,
                "local": True,
                "free": True,
                "models": models,
                "description": "100% privado, roda no seu PC",
            },
            {
                "provider": "openai",
                "name": "OpenAI GPT",
                "model": OPENAI_MODEL,
                "available": bool(self._openai),
                "local": False,
                "free": False,
                "models": [],
                "description": "GPT-4o Mini - Rapido e preciso",
            },
            {
                "provider": "anthropic",
                "name": "Anthropic Claude",
                "model": ANTHROPIC_MODEL,
                "available": bool(self._anthropic),
                "local": False,
                "free": False,
                "models": [],
                "description": "Claude Haiku - Analitico e criativo",
            },
        ]

    async def chat(
        self,
        messages: list,
        provider: str = None,
        system_prompt: str = None,
        model: str = None,
        temperature: float = 0.7,
        max_tokens: int = 2000,
        stream: bool = False,
    ):
        """Chat principal - roteia para o provedor correto"""
        p = provider or DEFAULT_PROVIDER

        # Adicionar system prompt
        if system_prompt:
            messages = [{"role": "system", "content": system_prompt}] + messages

        if stream:
            return self._stream(messages, p, temperature, max_tokens, model)
        return await self._complete(messages, p, temperature, max_tokens, model)

    async def _complete(self, messages, provider, temperature, max_tokens, model=None) -> str:
        """Chat nao-streaming"""
        try:
            if provider == "ollama":
                return await self._ollama_chat(messages, temperature, max_tokens, model)
            elif provider == "openai":
                return await self._openai_chat(messages, temperature, max_tokens)
            elif provider == "anthropic":
                return await self._anthropic_chat(messages, temperature, max_tokens)
            else:
                return await self._ollama_chat(messages, temperature, max_tokens, model)
        except Exception as e:
            logger.error(f"Erro {provider}: {e}")
            # Fallback para Ollama
            if provider != "ollama":
                ollama_ok = await self.check_ollama()
                if ollama_ok:
                    logger.info("Fallback para Ollama...")
                    return await self._ollama_chat(messages, temperature, max_tokens, model)
            raise

    async def _stream(self, messages, provider, temperature, max_tokens, model=None):
        """Chat com streaming"""
        try:
            if provider == "ollama":
                async for chunk in self._ollama_stream(messages, temperature, max_tokens, model):
                    yield chunk
            elif provider == "openai":
                async for chunk in self._openai_stream(messages, temperature, max_tokens):
                    yield chunk
            elif provider == "anthropic":
                async for chunk in self._anthropic_stream(messages, temperature, max_tokens):
                    yield chunk
            else:
                async for chunk in self._ollama_stream(messages, temperature, max_tokens, model):
                    yield chunk
        except Exception as e:
            logger.error(f"Stream erro {provider}: {e}")
            yield f"\n\n[Erro ao conectar com {provider}: {str(e)}]"

    # ===== OLLAMA =====

    async def _ollama_chat(self, messages, temperature, max_tokens, model=None) -> str:
        """Ollama nao-streaming"""
        timeout = httpx.Timeout(OLLAMA_TIMEOUT, connect=10.0)
        async with httpx.AsyncClient(timeout=timeout) as c:
            r = await c.post(
                f"{OLLAMA_URL}/api/chat",
                json={
                    "model": model or OLLAMA_MODEL,
                    "messages": messages,
                    "stream": False,
                    "options": {
                        "temperature": temperature,
                        "num_predict": max_tokens,
                    },
                },
            )
            r.raise_for_status()
            return r.json()["message"]["content"]

    async def _ollama_stream(self, messages, temperature, max_tokens, model=None):
        """Ollama streaming"""
        timeout = httpx.Timeout(OLLAMA_TIMEOUT, connect=10.0)
        async with httpx.AsyncClient(timeout=timeout) as c:
            async with c.stream(
                "POST",
                f"{OLLAMA_URL}/api/chat",
                json={
                    "model": model or OLLAMA_MODEL,
                    "messages": messages,
                    "stream": True,
                    "options": {
                        "temperature": temperature,
                        "num_predict": max_tokens,
                    },
                },
            ) as r:
                async for line in r.aiter_lines():
                    if line.strip():
                        try:
                            d = json.loads(line)
                            content = d.get("message", {}).get("content", "")
                            if content:
                                yield content
                            if d.get("done"):
                                break
                        except json.JSONDecodeError:
                            continue

    # ===== OPENAI =====

    async def _openai_chat(self, messages, temperature, max_tokens) -> str:
        """OpenAI nao-streaming"""
        if not self._openai:
            raise ValueError("OpenAI nao configurado. Adicione OPENAI_API_KEY no .env")
        r = await self._openai.chat.completions.create(
            model=OPENAI_MODEL,
            messages=messages,
            temperature=temperature,
            max_tokens=max_tokens,
        )
        return r.choices[0].message.content

    async def _openai_stream(self, messages, temperature, max_tokens):
        """OpenAI streaming"""
        if not self._openai:
            raise ValueError("OpenAI nao configurado")
        stream = await self._openai.chat.completions.create(
            model=OPENAI_MODEL,
            messages=messages,
            temperature=temperature,
            max_tokens=max_tokens,
            stream=True,
        )
        async for chunk in stream:
            delta = chunk.choices[0].delta.content
            if delta:
                yield delta

    # ===== ANTHROPIC =====

    async def _anthropic_chat(self, messages, temperature, max_tokens) -> str:
        """Anthropic nao-streaming"""
        if not self._anthropic:
            raise ValueError("Anthropic nao configurado. Adicione ANTHROPIC_API_KEY no .env")
        system = next(
            (m["content"] for m in messages if m["role"] == "system"),
            "Voce e um assistente util.",
        )
        msgs = [m for m in messages if m["role"] != "system"]
        r = await self._anthropic.messages.create(
            model=ANTHROPIC_MODEL,
            max_tokens=max_tokens,
            system=system,
            messages=msgs,
            temperature=temperature,
        )
        return r.content[0].text

    async def _anthropic_stream(self, messages, temperature, max_tokens):
        """Anthropic streaming"""
        if not self._anthropic:
            raise ValueError("Anthropic nao configurado")
        system = next(
            (m["content"] for m in messages if m["role"] == "system"),
            "Voce e um assistente util.",
        )
        msgs = [m for m in messages if m["role"] != "system"]
        async with self._anthropic.messages.stream(
            model=ANTHROPIC_MODEL,
            max_tokens=max_tokens,
            system=system,
            messages=msgs,
            temperature=temperature,
        ) as s:
            async for text in s.text_stream:
                yield text

    # ===== UTILITARIOS =====

    async def analyze_sentiment(self, text: str) -> str:
        """Analisar sentimento"""
        try:
            r = await self.chat(
                [{"role": "user", "content": f'Analise o sentimento e responda APENAS uma palavra: "positive", "negative" ou "neutral". Texto: "{text[:300]}"'}],
                temperature=0.1,
                max_tokens=10,
            )
            s = r.strip().lower().split()[0] if r.strip() else "neutral"
            return s if s in ["positive", "negative", "neutral"] else "neutral"
        except Exception:
            return "neutral"

    async def generate_review_response(
        self, review: str, rating: int, business: str = "HC Tech"
    ) -> str:
        """Gerar resposta para avaliacao"""
        tone = "agradecido e entusiasmado" if rating >= 4 else "empatico e solicito"
        return await self.chat(
            [{"role": "user", "content": f"""Resposta profissional para avaliacao de assistencia tecnica de celulares:

Avaliacao ({rating} estrelas): "{review}"

Instrucoes:
- Tom: {tone}
- Mencione {business}
- Maximo 3-4 frases curtas
- Use 1-2 emojis
- Em portugues brasileiro
- Se negativa: reconheca e ofeca solucao

Resposta:"""}],
            temperature=0.7,
            max_tokens=200,
        )


# Instancia global
ai_service = AIService()
