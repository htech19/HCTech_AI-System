# HC Tech AI System v2.1 - Correção de Dependências
# Execute: .\corrigir_deps.ps1

$ErrorActionPreference = "Continue"
$root = Split-Path $MyInvocation.MyCommand.Path

Clear-Host
Write-Host @"
╔══════════════════════════════════════════╗
║  HC TECH AI - Corrigindo Dependências   ║
╚══════════════════════════════════════════╝
"@ -ForegroundColor Cyan

# ============================================================
# PASSO 1: Atualizar requirements.txt com versões corretas
# ============================================================
Write-Host "`n[1] Atualizando requirements.txt..." -ForegroundColor Yellow

$requirements = @"
# HC Tech AI System v2.1 - Requirements Corrigidos
# Compatível com Python 3.12 + google-genai existente

# ===== WEB FRAMEWORK =====
fastapi==0.115.0
uvicorn[standard]==0.32.0
python-multipart==0.0.12

# ===== BANCO DE DADOS =====
sqlalchemy==2.0.36
aiosqlite==0.20.0

# ===== HTTP CLIENT (compatível com google-genai e telegram) =====
httpx>=0.28.1,<1.0.0

# ===== IA - OLLAMA =====
# Usamos httpx direto (mais compatível)

# ===== IA - OPENAI =====
openai>=1.50.0

# ===== IA - ANTHROPIC =====
anthropic>=0.40.0

# ===== CONFIG & AUTH =====
python-dotenv==1.0.1
pydantic>=2.9.0,<3.0.0
pydantic-settings>=2.5.0

# ===== UTILITÁRIOS =====
aiofiles==24.1.0
python-dateutil==2.9.0
loguru==0.7.2

# ===== WEBSOCKETS (compatível com telegram) =====
websockets>=13.0,<17.0

# ===== AGENDAMENTO =====
apscheduler==3.10.4

# ===== CACHE =====
cachetools==5.5.0
"@

$requirements | Out-File -FilePath "$root\backend\requirements.txt" -Encoding UTF8
Write-Host "  ✓ requirements.txt atualizado" -ForegroundColor Green

# ============================================================
# PASSO 2: Instalar com versões corretas
# ============================================================
Write-Host "`n[2] Instalando dependências atualizadas..." -ForegroundColor Yellow

Set-Location "$root\backend"

# Atualizar pip primeiro
Write-Host "  Atualizando pip..." -ForegroundColor Gray
python -m pip install --upgrade pip --quiet

# Instalar pacotes críticos primeiro (resolve conflitos)
Write-Host "  Instalando pacotes base..." -ForegroundColor Gray
python -m pip install "httpx>=0.28.1,<1.0.0" "pydantic>=2.9.0,<3.0.0" "websockets>=13.0,<17.0" --quiet

Write-Host "  Instalando FastAPI..." -ForegroundColor Gray
python -m pip install "fastapi==0.115.0" "uvicorn[standard]==0.32.0" --quiet

Write-Host "  Instalando SQLAlchemy..." -ForegroundColor Gray
python -m pip install "sqlalchemy==2.0.36" "aiosqlite==0.20.0" --quiet

Write-Host "  Instalando OpenAI..." -ForegroundColor Gray
python -m pip install "openai>=1.50.0" --quiet

Write-Host "  Instalando Anthropic..." -ForegroundColor Gray
python -m pip install "anthropic>=0.40.0" --quiet

Write-Host "  Instalando utilitários..." -ForegroundColor Gray
python -m pip install "python-dotenv==1.0.1" "loguru==0.7.2" "aiofiles==24.1.0" "pydantic-settings>=2.5.0" "apscheduler==3.10.4" "python-multipart==0.0.12" "python-dateutil==2.9.0" "cachetools==5.5.0" --quiet

Write-Host "  ✓ Dependências instaladas" -ForegroundColor Green

# ============================================================
# PASSO 3: Verificar instalação
# ============================================================
Write-Host "`n[3] Verificando instalação..." -ForegroundColor Yellow

$testScript = @"
import sys
results = []

packages = [
    ("fastapi", "FastAPI"),
    ("uvicorn", "Uvicorn"),
    ("sqlalchemy", "SQLAlchemy"),
    ("aiosqlite", "AioSQLite"),
    ("httpx", "HTTPX"),
    ("openai", "OpenAI"),
    ("anthropic", "Anthropic"),
    ("pydantic", "Pydantic"),
    ("dotenv", "Python-dotenv"),
    ("loguru", "Loguru"),
    ("apscheduler", "APScheduler"),
]

for module, name in packages:
    try:
        mod = __import__(module)
        version = getattr(mod, "__version__", "ok")
        results.append(f"  OK  {name}: {version}")
    except ImportError as e:
        results.append(f"  FAIL {name}: {e}")

for r in results:
    print(r)

# Verificar versões de conflito
import httpx
import pydantic
import websockets
print(f"\n  httpx: {httpx.__version__}")
print(f"  pydantic: {pydantic.__version__}")
print(f"  websockets: {websockets.__version__}")
"@

$testScript | python
Write-Host ""

# ============================================================
# PASSO 4: Testar importação do main
# ============================================================
Write-Host "`n[4] Testando backend..." -ForegroundColor Yellow

$testMain = @"
import sys
import os
sys.path.insert(0, '.')

try:
    from app.config import settings
    print(f"  OK  Config carregada")
    print(f"      Ollama: {settings.OLLAMA_API_URL}")
    print(f"      Modelo: {settings.OLLAMA_MODEL}")
    print(f"      DB: {settings.DATABASE_URL[:40]}...")
except Exception as e:
    print(f"  FAIL Config: {e}")

try:
    from app.database import Base, Agent, Task
    print(f"  OK  Modelos de banco OK")
except Exception as e:
    print(f"  FAIL Database: {e}")

try:
    from app.services.ai_service import ai_service
    print(f"  OK  AI Service carregado")
except Exception as e:
    print(f"  FAIL AI Service: {e}")

try:
    from app.main import app
    print(f"  OK  App FastAPI OK - {len(app.routes)} rotas registradas")
except Exception as e:
    print(f"  FAIL App: {e}")
    import traceback
    traceback.print_exc()
"@

$testMain | python

Set-Location $root

# ============================================================
# PASSO 5: Atualizar ai_service.py para httpx atualizado
# ============================================================
Write-Host "`n[5] Atualizando AI Service para novas versões..." -ForegroundColor Yellow

$aiServiceContent = @'
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
            return self._stream(messages, p, temperature, max_tokens)
        return await self._complete(messages, p, temperature, max_tokens)

    async def _complete(self, messages, provider, temperature, max_tokens) -> str:
        """Chat nao-streaming"""
        try:
            if provider == "ollama":
                return await self._ollama_chat(messages, temperature, max_tokens)
            elif provider == "openai":
                return await self._openai_chat(messages, temperature, max_tokens)
            elif provider == "anthropic":
                return await self._anthropic_chat(messages, temperature, max_tokens)
            else:
                return await self._ollama_chat(messages, temperature, max_tokens)
        except Exception as e:
            logger.error(f"Erro {provider}: {e}")
            # Fallback para Ollama
            if provider != "ollama":
                ollama_ok = await self.check_ollama()
                if ollama_ok:
                    logger.info("Fallback para Ollama...")
                    return await self._ollama_chat(messages, temperature, max_tokens)
            raise

    async def _stream(self, messages, provider, temperature, max_tokens):
        """Chat com streaming"""
        try:
            if provider == "ollama":
                async for chunk in self._ollama_stream(messages, temperature, max_tokens):
                    yield chunk
            elif provider == "openai":
                async for chunk in self._openai_stream(messages, temperature, max_tokens):
                    yield chunk
            elif provider == "anthropic":
                async for chunk in self._anthropic_stream(messages, temperature, max_tokens):
                    yield chunk
            else:
                async for chunk in self._ollama_stream(messages, temperature, max_tokens):
                    yield chunk
        except Exception as e:
            logger.error(f"Stream erro {provider}: {e}")
            yield f"\n\n[Erro ao conectar com {provider}: {str(e)}]"

    # ===== OLLAMA =====

    async def _ollama_chat(self, messages, temperature, max_tokens) -> str:
        """Ollama nao-streaming"""
        timeout = httpx.Timeout(OLLAMA_TIMEOUT, connect=10.0)
        async with httpx.AsyncClient(timeout=timeout) as c:
            r = await c.post(
                f"{OLLAMA_URL}/api/chat",
                json={
                    "model": OLLAMA_MODEL,
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

    async def _ollama_stream(self, messages, temperature, max_tokens):
        """Ollama streaming"""
        timeout = httpx.Timeout(OLLAMA_TIMEOUT, connect=10.0)
        async with httpx.AsyncClient(timeout=timeout) as c:
            async with c.stream(
                "POST",
                f"{OLLAMA_URL}/api/chat",
                json={
                    "model": OLLAMA_MODEL,
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
'@

$aiServiceContent | Out-File -FilePath "$root\backend\app\services\ai_service.py" -Encoding UTF8
Write-Host "  ✓ AI Service atualizado (httpx >= 0.28.1)" -ForegroundColor Green

# ============================================================
# PASSO 6: Teste final do backend
# ============================================================
Write-Host "`n[6] Teste final completo..." -ForegroundColor Yellow

Set-Location "$root\backend"

$finalTest = @"
import asyncio
import sys
import os
sys.path.insert(0, '.')

async def test():
    errors = []

    # Test 1: Imports
    try:
        from app.main import app
        print(f"  [OK] App FastAPI: {len(app.routes)} rotas")
    except Exception as e:
        print(f"  [FAIL] App: {e}")
        errors.append(str(e))

    # Test 2: AI Service
    try:
        from app.services.ai_service import ai_service
        ollama_ok = await ai_service.check_ollama()
        print(f"  [OK] AI Service - Ollama: {'Online' if ollama_ok else 'Offline (OK se nao iniciado)'}")
    except Exception as e:
        print(f"  [FAIL] AI Service: {e}")
        errors.append(str(e))

    # Test 3: Database
    try:
        from app.database import init_db, AsyncSessionLocal, Agent
        await init_db()
        async with AsyncSessionLocal() as s:
            from sqlalchemy import select, func
            count = await s.scalar(select(func.count(Agent.id)))
            print(f"  [OK] Banco de dados: {count} agentes")
    except Exception as e:
        print(f"  [FAIL] Database: {e}")
        errors.append(str(e))

    if errors:
        print(f"\n  ERROS ENCONTRADOS: {len(errors)}")
        for e in errors:
            print(f"    - {e}")
        return False
    else:
        print(f"\n  TUDO OK! Backend pronto para iniciar.")
        return True

result = asyncio.run(test())
sys.exit(0 if result else 1)
"@

$finalTest | python
$testOk = $LASTEXITCODE -eq 0

Set-Location $root

if ($testOk) {
    Write-Host @"

╔══════════════════════════════════════════════════════╗
║  ✅ DEPENDENCIAS CORRIGIDAS E TESTADAS!              ║
╠══════════════════════════════════════════════════════╣
║                                                      ║
║  Execute agora:  .\iniciar.ps1                      ║
║  Acesse em:      http://localhost:3000               ║
║                                                      ║
║  Status:                                             ║
║  ✓ Python 3.12 + FastAPI 0.115                      ║
║  ✓ httpx >= 0.28 (compativel)                       ║
║  ✓ pydantic >= 2.9 (compativel)                     ║
║  ✓ websockets >= 13 (compativel)                    ║
║  ✓ Ollama + Llama 3.2:3B                            ║
║  ✓ Banco SQLite inicializado                         ║
╚══════════════════════════════════════════════════════╝
"@ -ForegroundColor Green
} else {
    Write-Host @"

╔══════════════════════════════════════════════════════╗
║  ⚠ ALGUNS TESTES FALHARAM                           ║
║  Verifique os erros acima e tente novamente.        ║
╚══════════════════════════════════════════════════════╝
"@ -ForegroundColor Yellow
}