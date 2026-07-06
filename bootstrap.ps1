# Salve este arquivo como: bootstrap.ps1
# Execute: .\bootstrap.ps1

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot
Set-Location $ProjectRoot

Clear-Host
Write-Host @"
╔══════════════════════════════════════════════════════════╗
║        HC TECH AI SYSTEM v2.1 - BOOTSTRAP               ║
║        Criando todos os arquivos do zero...              ║
╚══════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

# ============================================================
# FUNÇÃO HELPER - Criar arquivo com conteúdo
# ============================================================
function New-FileWithContent {
    param(
        [string]$Path,
        [string]$Content,
        [string]$Encoding = "UTF8"
    )
    $dir = Split-Path $Path -Parent
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.Encoding]::UTF8)
    Write-Host "  ✓ $Path" -ForegroundColor Green
}

Write-Host "`n[1/8] Criando estrutura de diretórios..." -ForegroundColor Yellow

$dirs = @(
    "backend\app\api",
    "backend\app\services", 
    "backend\app\models",
    "backend\data",
    "backend\logs",
    "frontend\src\app",
    "frontend\src\components\layout",
    "frontend\src\components\pages",
    "frontend\src\components\ui",
    "frontend\src\lib",
    "frontend\src\store",
    "frontend\public",
    "scripts",
    "docs",
    "logs",
    "data"
)

foreach ($dir in $dirs) {
    $full = Join-Path $ProjectRoot $dir
    if (-not (Test-Path $full)) {
        New-Item -ItemType Directory -Path $full -Force | Out-Null
    }
}
Write-Host "  ✓ Diretórios criados" -ForegroundColor Green

# ============================================================
# [2/8] ARQUIVO .ENV
# ============================================================
Write-Host "`n[2/8] Criando .env..." -ForegroundColor Yellow

New-FileWithContent "$ProjectRoot\.env" @'
# HC Tech AI System v2.1 - Configuração
# ========================================

# ===== IA LOCAL (Ollama - 100% Grátis e Privado) =====
OLLAMA_API_URL=http://localhost:11434
OLLAMA_MODEL=llama3.2:3b
OLLAMA_TIMEOUT=120

# ===== IA ONLINE (Opcional - deixe vazio se não usar) =====
OPENAI_API_KEY=
OPENAI_MODEL=gpt-4o-mini
ANTHROPIC_API_KEY=
ANTHROPIC_MODEL=claude-3-haiku-20240307

# ===== PROVEDOR PADRÃO =====
DEFAULT_AI_PROVIDER=ollama

# ===== BANCO DE DADOS =====
DATABASE_URL=sqlite+aiosqlite:///./data/hctech.db

# ===== SERVIDOR =====
BACKEND_HOST=0.0.0.0
BACKEND_PORT=8000
FRONTEND_PORT=3000
DEBUG=true

# ===== SEGURANÇA =====
SECRET_KEY=hctech-ai-system-secret-key-2024-change-in-prod

# ===== FRONTEND =====
NEXT_PUBLIC_BACKEND_URL=http://localhost:8000

# ===== FEATURES =====
ENABLE_ANALYTICS=true
ENABLE_AUTOMATION=true
ENABLE_WEBHOOKS=false
'@

# ============================================================
# [3/8] BACKEND PYTHON - requirements.txt
# ============================================================
Write-Host "`n[3/8] Criando backend Python..." -ForegroundColor Yellow

New-FileWithContent "$ProjectRoot\backend\requirements.txt" @'
fastapi==0.109.0
uvicorn[standard]==0.27.0
python-multipart==0.0.7
sqlalchemy==2.0.25
aiosqlite==0.20.0
httpx==0.26.0
openai==1.12.0
anthropic==0.17.0
python-dotenv==1.0.1
pydantic==2.6.0
pydantic-settings==2.2.0
aiofiles==23.2.1
python-dateutil==2.8.2
loguru==0.7.2
websockets==12.0
cachetools==5.3.2
apscheduler==3.10.4
'@

# ============================================================
# backend/app/__init__.py
# ============================================================
New-FileWithContent "$ProjectRoot\backend\app\__init__.py" '# HC Tech AI System v2.1'

# ============================================================
# backend/app/config.py
# ============================================================
New-FileWithContent "$ProjectRoot\backend\app\config.py" @'
"""Configurações centralizadas - HC Tech AI System v2.1"""
from functools import lru_cache
from typing import Literal, Optional
from pydantic_settings import BaseSettings
from pydantic import Field
import os

class Settings(BaseSettings):
    APP_NAME: str = "HC Tech AI System"
    APP_VERSION: str = "2.1.0"
    DEBUG: bool = True
    
    BACKEND_HOST: str = "0.0.0.0"
    BACKEND_PORT: int = 8000
    FRONTEND_PORT: int = 3000
    
    OLLAMA_API_URL: str = "http://localhost:11434"
    OLLAMA_MODEL: str = "llama3.2:3b"
    OLLAMA_TIMEOUT: int = 120
    
    OPENAI_API_KEY: Optional[str] = None
    OPENAI_MODEL: str = "gpt-4o-mini"
    ANTHROPIC_API_KEY: Optional[str] = None
    ANTHROPIC_MODEL: str = "claude-3-haiku-20240307"
    
    DEFAULT_AI_PROVIDER: str = "ollama"
    
    DATABASE_URL: str = "sqlite+aiosqlite:///./data/hctech.db"
    
    SECRET_KEY: str = "change-me-in-production"
    JWT_EXPIRE_HOURS: int = 24
    
    ENABLE_ANALYTICS: bool = True
    ENABLE_AUTOMATION: bool = True
    ENABLE_WEBHOOKS: bool = False
    
    NEXT_PUBLIC_BACKEND_URL: str = "http://localhost:8000"
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = False
        extra = "ignore"

@lru_cache()
def get_settings() -> Settings:
    # Procurar .env na raiz do projeto
    env_path = os.path.join(os.path.dirname(__file__), "..", "..", ".env")
    if os.path.exists(env_path):
        from dotenv import load_dotenv
        load_dotenv(env_path)
    return Settings()

settings = get_settings()
'@

# ============================================================
# backend/app/database.py
# ============================================================
New-FileWithContent "$ProjectRoot\backend\app\database.py" @'
"""Banco de dados - SQLAlchemy Async"""
from datetime import datetime
from typing import AsyncGenerator
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship
from sqlalchemy import String, Text, DateTime, Boolean, Integer, Float, JSON, ForeignKey
from loguru import logger
import os, sys

# Resolver path do .env
root_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
env_file = os.path.join(root_dir, ".env")
if os.path.exists(env_file):
    from dotenv import load_dotenv
    load_dotenv(env_file)

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite+aiosqlite:///./data/hctech.db")

# Garantir que o diretório data/ existe
data_dir = os.path.join(root_dir, "data")
os.makedirs(data_dir, exist_ok=True)

# Ajustar path para SQLite relativo
if "sqlite" in DATABASE_URL and "///" in DATABASE_URL:
    db_path = DATABASE_URL.split("///")[1]
    if not os.path.isabs(db_path):
        abs_db_path = os.path.join(root_dir, db_path)
        DATABASE_URL = DATABASE_URL.split("///")[0] + "///" + abs_db_path

engine = create_async_engine(DATABASE_URL, echo=False, future=True)
AsyncSessionLocal = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

class Base(DeclarativeBase):
    pass

class Agent(Base):
    __tablename__ = "agents"
    id: Mapped[str] = mapped_column(String(50), primary_key=True)
    name: Mapped[str] = mapped_column(String(100))
    role: Mapped[str] = mapped_column(String(100))
    description: Mapped[str] = mapped_column(Text)
    system_prompt: Mapped[str] = mapped_column(Text)
    avatar: Mapped[str] = mapped_column(String(10), default="🤖")
    color: Mapped[str] = mapped_column(String(50), default="blue")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    ai_provider: Mapped[str] = mapped_column(String(20), default="ollama")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    conversations: Mapped[list["Conversation"]] = relationship(back_populates="agent", cascade="all, delete-orphan")
    tasks: Mapped[list["Task"]] = relationship(back_populates="agent")

class Conversation(Base):
    __tablename__ = "conversations"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    agent_id: Mapped[str] = mapped_column(String(50), ForeignKey("agents.id"))
    role: Mapped[str] = mapped_column(String(20))
    content: Mapped[str] = mapped_column(Text)
    ai_provider: Mapped[str] = mapped_column(String(20), default="ollama")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    agent: Mapped["Agent"] = relationship(back_populates="conversations")

class Task(Base):
    __tablename__ = "tasks"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    title: Mapped[str] = mapped_column(String(200))
    description: Mapped[str] = mapped_column(Text, default="")
    status: Mapped[str] = mapped_column(String(30), default="todo")
    priority: Mapped[str] = mapped_column(String(20), default="medium")
    agent_id: Mapped[str] = mapped_column(String(50), ForeignKey("agents.id"), nullable=True)
    tags: Mapped[list] = mapped_column(JSON, default=list)
    due_date: Mapped[datetime] = mapped_column(DateTime, nullable=True)
    completed_at: Mapped[datetime] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    agent: Mapped["Agent"] = relationship(back_populates="tasks")

class KnowledgeBase(Base):
    __tablename__ = "knowledge_base"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    title: Mapped[str] = mapped_column(String(300))
    content: Mapped[str] = mapped_column(Text)
    category: Mapped[str] = mapped_column(String(100))
    agent_id: Mapped[str] = mapped_column(String(50), nullable=True)
    tags: Mapped[list] = mapped_column(JSON, default=list)
    is_public: Mapped[bool] = mapped_column(Boolean, default=True)
    view_count: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

class SEOKeyword(Base):
    __tablename__ = "seo_keywords"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    keyword: Mapped[str] = mapped_column(String(300))
    position: Mapped[int] = mapped_column(Integer, default=0)
    volume: Mapped[int] = mapped_column(Integer, default=0)
    difficulty: Mapped[int] = mapped_column(Integer, default=0)
    trend: Mapped[str] = mapped_column(String(20), default="stable")
    prev_position: Mapped[int] = mapped_column(Integer, nullable=True)
    url: Mapped[str] = mapped_column(String(500), nullable=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

class Review(Base):
    __tablename__ = "reviews"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    author: Mapped[str] = mapped_column(String(200))
    rating: Mapped[int] = mapped_column(Integer)
    content: Mapped[str] = mapped_column(Text)
    source: Mapped[str] = mapped_column(String(50), default="google")
    sentiment: Mapped[str] = mapped_column(String(20), default="neutral")
    ai_response: Mapped[str] = mapped_column(Text, nullable=True)
    responded: Mapped[bool] = mapped_column(Boolean, default=False)
    response_date: Mapped[datetime] = mapped_column(DateTime, nullable=True)
    review_date: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

class SocialPost(Base):
    __tablename__ = "social_posts"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    platform: Mapped[str] = mapped_column(String(30))
    content: Mapped[str] = mapped_column(Text)
    media_url: Mapped[str] = mapped_column(String(500), nullable=True)
    hashtags: Mapped[list] = mapped_column(JSON, default=list)
    status: Mapped[str] = mapped_column(String(20), default="draft")
    scheduled_at: Mapped[datetime] = mapped_column(DateTime, nullable=True)
    published_at: Mapped[datetime] = mapped_column(DateTime, nullable=True)
    likes: Mapped[int] = mapped_column(Integer, default=0)
    comments: Mapped[int] = mapped_column(Integer, default=0)
    shares: Mapped[int] = mapped_column(Integer, default=0)
    reach: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

class AutomationJob(Base):
    __tablename__ = "automation_jobs"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(200))
    description: Mapped[str] = mapped_column(Text, default="")
    job_type: Mapped[str] = mapped_column(String(50))
    schedule: Mapped[str] = mapped_column(String(100))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    last_run: Mapped[datetime] = mapped_column(DateTime, nullable=True)
    next_run: Mapped[datetime] = mapped_column(DateTime, nullable=True)
    run_count: Mapped[int] = mapped_column(Integer, default=0)
    success_count: Mapped[int] = mapped_column(Integer, default=0)
    error_count: Mapped[int] = mapped_column(Integer, default=0)
    last_error: Mapped[str] = mapped_column(Text, nullable=True)
    config: Mapped[dict] = mapped_column(JSON, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

class Report(Base):
    __tablename__ = "reports"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    title: Mapped[str] = mapped_column(String(300))
    report_type: Mapped[str] = mapped_column(String(50))
    content: Mapped[str] = mapped_column(Text)
    ai_summary: Mapped[str] = mapped_column(Text, nullable=True)
    data: Mapped[dict] = mapped_column(JSON, default=dict)
    generated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

async def init_db():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    async with AsyncSessionLocal() as session:
        await seed_initial_data(session)
    logger.info("✅ Banco de dados inicializado")

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise

async def seed_initial_data(session: AsyncSession):
    from sqlalchemy import select
    result = await session.execute(select(Agent))
    if result.scalars().first():
        return
    logger.info("🌱 Populando dados iniciais...")
    
    agents_data = [
        {"id": "hc-ceo", "name": "HC-CEO", "role": "Coordenador Estratégico", "avatar": "👔", "color": "purple",
         "description": "Executivo estratégico que toma decisões de alto nível e coordena os agentes.",
         "system_prompt": "Você é HC-CEO, o Coordenador Estratégico da HC Tech, assistência técnica de smartphones. Tome decisões estratégicas, analise métricas e defina prioridades. Seja direto e orientado a resultados."},
        {"id": "hc-seo", "name": "HC-SEO", "role": "Especialista em SEO", "avatar": "🔍", "color": "green",
         "description": "Especialista em otimização para buscadores e Google Maps.",
         "system_prompt": "Você é HC-SEO, especialista em SEO local da HC Tech, assistência técnica. Otimize para Google Maps, pesquise keywords como 'conserto celular [cidade]', monitore rankings. Seja técnico e orientado a dados."},
        {"id": "hc-social", "name": "HC-SOCIAL", "role": "Gestor de Redes Sociais", "avatar": "📱", "color": "pink",
         "description": "Especialista em Facebook, Instagram e crescimento de comunidade.",
         "system_prompt": "Você é HC-SOCIAL, gestor de redes sociais da HC Tech. Gerencie Facebook e Instagram, crie estratégias de engajamento, analise métricas. Tom profissional mas acessível."},
        {"id": "hc-content", "name": "HC-CONTENT", "role": "Criador de Conteúdo", "avatar": "✍️", "color": "orange",
         "description": "Especialista em copywriting e criação de conteúdo digital.",
         "system_prompt": "Você é HC-CONTENT, criador de conteúdo da HC Tech. Crie posts, artigos SEO, scripts de Reels, copies persuasivos sobre assistência técnica de celulares. Use linguagem engajante."},
        {"id": "hc-code", "name": "HC-CODE", "role": "Desenvolvedor & Automação", "avatar": "💻", "color": "blue",
         "description": "Especialista em Python, automações e integrações de sistemas.",
         "system_prompt": "Você é HC-CODE, desenvolvedor da HC Tech. Crie scripts Python, automações, integrações com APIs. Forneça código funcional e bem documentado. Tecnologias: Python, FastAPI, Next.js, SQL."},
    ]
    
    for a in agents_data:
        session.add(Agent(**a))
    
    keywords = [
        SEOKeyword(keyword="conserto celular", position=3, volume=1200, difficulty=45, trend="up"),
        SEOKeyword(keyword="troca tela iPhone", position=5, volume=890, difficulty=62, trend="up"),
        SEOKeyword(keyword="assistência técnica celular", position=4, volume=2100, difficulty=55, trend="up"),
        SEOKeyword(keyword="troca bateria iPhone", position=2, volume=780, difficulty=42, trend="up"),
        SEOKeyword(keyword="reparo Samsung", position=7, volume=650, difficulty=38, trend="stable"),
        SEOKeyword(keyword="conserto tela quebrada", position=6, volume=540, difficulty=35, trend="stable"),
        SEOKeyword(keyword="recuperação dados celular", position=12, volume=430, difficulty=67, trend="stable"),
    ]
    for kw in keywords:
        session.add(kw)
    
    reviews = [
        Review(author="João Silva", rating=5, content="Excelente! Meu iPhone voltou como novo. Super recomendo!", sentiment="positive", responded=True, ai_response="Obrigado João! Ficamos felizes em ajudar! 😊"),
        Review(author="Maria Santos", rating=5, content="Muito bom! Rápido, eficiente e preço justo.", sentiment="positive", responded=False),
        Review(author="Pedro Costa", rating=4, content="Bom serviço, mas demorou um pouco mais do prometido.", sentiment="neutral", responded=False),
        Review(author="Ana Lima", rating=5, content="Salvaram meu Samsung! Dados recuperados com sucesso.", sentiment="positive", responded=False),
    ]
    for r in reviews:
        session.add(r)
    
    tasks = [
        Task(title="Atualizar fotos Google Business", description="Adicionar fotos novas da loja", status="todo", priority="high", agent_id="hc-seo", tags=["google", "perfil"]),
        Task(title="Criar 5 posts para Instagram", description="Posts sobre serviços: troca de tela, bateria", status="in_progress", priority="medium", agent_id="hc-content", tags=["instagram"]),
        Task(title="Responder reviews pendentes", description="Responder 3 avaliações novas do Google", status="todo", priority="high", agent_id="hc-social", tags=["reviews"]),
        Task(title="Análise mensal de SEO", description="Relatório de performance SEO do mês", status="done", priority="medium", agent_id="hc-seo", tags=["seo", "relatório"]),
        Task(title="Script automação respostas", description="Criar script Python para resposta automática", status="todo", priority="low", agent_id="hc-code", tags=["automação"]),
    ]
    for t in tasks:
        session.add(t)
    
    knowledge = [
        KnowledgeBase(title="Guia de Atendimento ao Cliente", content="# Guia de Atendimento\n\n## Princípios\n1. **Empatia** - Cliente sem celular causa desconforto\n2. **Clareza** - Explique em linguagem simples\n3. **Prazo realista** - Dê margem de segurança\n\n## Garantia\n- Tela: 90 dias\n- Bateria: 6 meses\n- Software: 30 dias", category="Processos", agent_id="hc-ceo", tags=["atendimento"]),
        KnowledgeBase(title="Palavras-chave SEO Local", content="# Keywords Principais\n\n- conserto celular + [cidade]\n- assistência técnica + [cidade]\n- troca tela iPhone + [cidade]\n- troca bateria + [cidade]\n\n## Long-tail\n- quanto custa trocar tela iPhone [modelo]\n- onde consertar Samsung [cidade]", category="SEO", agent_id="hc-seo", tags=["seo", "keywords"]),
    ]
    for k in knowledge:
        session.add(k)
    
    jobs = [
        AutomationJob(name="Verificar Reviews Diário", description="Checar novas avaliações no Google", job_type="review_check", schedule="0 9 * * *", is_active=True, config={"auto_respond": False}),
        AutomationJob(name="Relatório SEO Semanal", description="Gerar relatório de keywords todo domingo", job_type="seo_report", schedule="0 8 * * 0", is_active=True, config={"send_email": False}),
        AutomationJob(name="Backup Banco Diário", description="Backup automático do banco de dados", job_type="backup", schedule="0 2 * * *", is_active=True, config={"keep_days": 7}),
    ]
    for j in jobs:
        session.add(j)
    
    await session.commit()
    logger.info("✅ Dados iniciais criados com sucesso!")
'@

# ============================================================
# backend/app/services/__init__.py
# ============================================================
New-FileWithContent "$ProjectRoot\backend\app\services\__init__.py" '# Services'

# ============================================================
# backend/app/services/ai_service.py
# ============================================================
New-FileWithContent "$ProjectRoot\backend\app\services\ai_service.py" @'
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
'@

# ============================================================
# backend/app/api/__init__.py
# ============================================================
New-FileWithContent "$ProjectRoot\backend\app\api\__init__.py" '# API Routers'

# ============================================================
# backend/app/api/ai.py
# ============================================================
New-FileWithContent "$ProjectRoot\backend\app\api\ai.py" @'
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
'@

# ============================================================
# backend/app/api/agents.py
# ============================================================
New-FileWithContent "$ProjectRoot\backend\app\api\agents.py" @'
"""API de Agentes"""
from fastapi import APIRouter, HTTPException
from sqlalchemy import select, delete
from app.database import AsyncSessionLocal, Agent, Conversation
from pydantic import BaseModel
from typing import Optional

router = APIRouter()

@router.get("")
async def list_agents():
    async with AsyncSessionLocal() as s:
        r = await s.execute(select(Agent).order_by(Agent.created_at))
        agents = r.scalars().all()
        return [{"id": a.id, "name": a.name, "role": a.role, "description": a.description,
                 "system_prompt": a.system_prompt, "avatar": a.avatar, "color": a.color,
                 "is_active": a.is_active, "ai_provider": a.ai_provider} for a in agents]

@router.get("/{agent_id}")
async def get_agent(agent_id: str):
    async with AsyncSessionLocal() as s:
        r = await s.execute(select(Agent).where(Agent.id == agent_id))
        a = r.scalar_one_or_none()
        if not a:
            raise HTTPException(404, "Agente não encontrado")
        return {"id": a.id, "name": a.name, "role": a.role, "description": a.description,
                "system_prompt": a.system_prompt, "avatar": a.avatar, "color": a.color,
                "is_active": a.is_active, "ai_provider": a.ai_provider}

@router.get("/{agent_id}/history")
async def get_history(agent_id: str, limit: int = 50):
    async with AsyncSessionLocal() as s:
        r = await s.execute(
            select(Conversation).where(Conversation.agent_id == agent_id)
            .order_by(Conversation.created_at).limit(limit))
        convs = r.scalars().all()
        return [{"role": c.role, "content": c.content, "provider": c.ai_provider,
                 "created_at": c.created_at.isoformat()} for c in convs]

@router.delete("/{agent_id}/history")
async def clear_history(agent_id: str):
    async with AsyncSessionLocal() as s:
        await s.execute(delete(Conversation).where(Conversation.agent_id == agent_id))
        await s.commit()
    return {"message": "Histórico limpo"}

class AgentUpdate(BaseModel):
    system_prompt: Optional[str] = None
    ai_provider: Optional[str] = None
    is_active: Optional[bool] = None

@router.patch("/{agent_id}")
async def update_agent(agent_id: str, data: AgentUpdate):
    async with AsyncSessionLocal() as s:
        r = await s.execute(select(Agent).where(Agent.id == agent_id))
        a = r.scalar_one_or_none()
        if not a:
            raise HTTPException(404, "Agente não encontrado")
        if data.system_prompt is not None:
            a.system_prompt = data.system_prompt
        if data.ai_provider is not None:
            a.ai_provider = data.ai_provider
        if data.is_active is not None:
            a.is_active = data.is_active
        await s.commit()
        return {"message": "Agente atualizado"}
'@

# ============================================================
# backend/app/api/tasks.py
# ============================================================
New-FileWithContent "$ProjectRoot\backend\app\api\tasks.py" @'
"""API de Tarefas - Kanban"""
from datetime import datetime
from fastapi import APIRouter, HTTPException
from sqlalchemy import select
from app.database import AsyncSessionLocal, Task
from pydantic import BaseModel
from typing import Optional, List

router = APIRouter()

class TaskCreate(BaseModel):
    title: str
    description: str = ""
    status: str = "todo"
    priority: str = "medium"
    agent_id: Optional[str] = None
    tags: List[str] = []

class TaskUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    priority: Optional[str] = None
    agent_id: Optional[str] = None
    tags: Optional[List[str]] = None

@router.get("")
async def list_tasks(status: Optional[str] = None):
    async with AsyncSessionLocal() as s:
        q = select(Task).order_by(Task.created_at.desc())
        if status:
            q = q.where(Task.status == status)
        r = await s.execute(q)
        tasks = r.scalars().all()
        return [{"id": t.id, "title": t.title, "description": t.description,
                 "status": t.status, "priority": t.priority, "agent_id": t.agent_id,
                 "tags": t.tags or [], "created_at": t.created_at.isoformat()} for t in tasks]

@router.post("")
async def create_task(data: TaskCreate):
    async with AsyncSessionLocal() as s:
        task = Task(title=data.title, description=data.description, status=data.status,
                    priority=data.priority, agent_id=data.agent_id, tags=data.tags)
        s.add(task)
        await s.commit()
        await s.refresh(task)
        return {"id": task.id, "title": task.title, "status": task.status, "message": "Tarefa criada"}

@router.put("/{task_id}")
async def update_task(task_id: int, data: TaskUpdate):
    async with AsyncSessionLocal() as s:
        r = await s.execute(select(Task).where(Task.id == task_id))
        t = r.scalar_one_or_none()
        if not t:
            raise HTTPException(404, "Tarefa não encontrada")
        if data.title: t.title = data.title
        if data.description is not None: t.description = data.description
        if data.priority: t.priority = data.priority
        if data.agent_id is not None: t.agent_id = data.agent_id
        if data.tags is not None: t.tags = data.tags
        t.updated_at = datetime.utcnow()
        await s.commit()
        return {"message": "Tarefa atualizada"}

@router.patch("/{task_id}/status")
async def move_task(task_id: int, body: dict):
    status = body.get("status")
    if status not in ["todo", "in_progress", "done"]:
        raise HTTPException(400, "Status inválido")
    async with AsyncSessionLocal() as s:
        r = await s.execute(select(Task).where(Task.id == task_id))
        t = r.scalar_one_or_none()
        if not t:
            raise HTTPException(404, "Tarefa não encontrada")
        t.status = status
        t.updated_at = datetime.utcnow()
        if status == "done":
            t.completed_at = datetime.utcnow()
        await s.commit()
        return {"message": f"Tarefa movida para {status}"}

@router.delete("/{task_id}")
async def delete_task(task_id: int):
    async with AsyncSessionLocal() as s:
        r = await s.execute(select(Task).where(Task.id == task_id))
        t = r.scalar_one_or_none()
        if not t:
            raise HTTPException(404, "Tarefa não encontrada")
        await s.delete(t)
        await s.commit()
        return {"message": "Tarefa removida"}
'@

# ============================================================
# backend/app/api/seo.py
# ============================================================
New-FileWithContent "$ProjectRoot\backend\app\api\seo.py" @'
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
'@

# ============================================================
# backend/app/api/maps.py
# ============================================================
New-FileWithContent "$ProjectRoot\backend\app\api\maps.py" @'
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
'@

# ============================================================
# backend/app/api/social.py
# ============================================================
New-FileWithContent "$ProjectRoot\backend\app\api\social.py" @'
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
'@

# ============================================================
# backend/app/api/knowledge.py
# ============================================================
New-FileWithContent "$ProjectRoot\backend\app\api\knowledge.py" @'
"""API Base de Conhecimento"""
from datetime import datetime
from fastapi import APIRouter, HTTPException
from sqlalchemy import select, or_
from app.database import AsyncSessionLocal, KnowledgeBase
from pydantic import BaseModel
from typing import Optional, List

router = APIRouter()

class ArticleCreate(BaseModel):
    title: str
    content: str
    category: str
    agent_id: Optional[str] = None
    tags: List[str] = []

@router.get("")
async def list_articles(search: Optional[str] = None, category: Optional[str] = None):
    async with AsyncSessionLocal() as s:
        q = select(KnowledgeBase).order_by(KnowledgeBase.created_at.desc())
        if search:
            q = q.where(or_(KnowledgeBase.title.contains(search), KnowledgeBase.content.contains(search)))
        if category:
            q = q.where(KnowledgeBase.category == category)
        r = await s.execute(q)
        arts = r.scalars().all()
        return [{"id": a.id, "title": a.title, "content": a.content, "category": a.category,
                 "agent_id": a.agent_id, "tags": a.tags, "view_count": a.view_count,
                 "created_at": a.created_at.isoformat()} for a in arts]

@router.post("")
async def create_article(data: ArticleCreate):
    async with AsyncSessionLocal() as s:
        art = KnowledgeBase(title=data.title, content=data.content, category=data.category,
                             agent_id=data.agent_id, tags=data.tags)
        s.add(art)
        await s.commit()
        await s.refresh(art)
        return {"id": art.id, "message": "Artigo criado"}

@router.put("/{article_id}")
async def update_article(article_id: int, data: ArticleCreate):
    async with AsyncSessionLocal() as s:
        r = await s.execute(select(KnowledgeBase).where(KnowledgeBase.id == article_id))
        a = r.scalar_one_or_none()
        if not a:
            raise HTTPException(404, "Artigo não encontrado")
        a.title = data.title
        a.content = data.content
        a.category = data.category
        a.updated_at = datetime.utcnow()
        await s.commit()
        return {"message": "Artigo atualizado"}

@router.delete("/{article_id}")
async def delete_article(article_id: int):
    async with AsyncSessionLocal() as s:
        r = await s.execute(select(KnowledgeBase).where(KnowledgeBase.id == article_id))
        a = r.scalar_one_or_none()
        if not a:
            raise HTTPException(404, "Artigo não encontrado")
        await s.delete(a)
        await s.commit()
        return {"message": "Artigo removido"}
'@

# ============================================================
# backend/app/api/metrics.py
# ============================================================
New-FileWithContent "$ProjectRoot\backend\app\api\metrics.py" @'
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
'@

# ============================================================
# backend/app/api/reports.py
# ============================================================
New-FileWithContent "$ProjectRoot\backend\app\api\reports.py" @'
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
'@

# ============================================================
# backend/app/api/automation.py
# ============================================================
New-FileWithContent "$ProjectRoot\backend\app\api\automation.py" @'
"""API de Automação"""
from datetime import datetime
from fastapi import APIRouter, HTTPException
from sqlalchemy import select
from app.database import AsyncSessionLocal, AutomationJob

router = APIRouter()

@router.get("/jobs")
async def get_jobs():
    async with AsyncSessionLocal() as s:
        r = await s.execute(select(AutomationJob).order_by(AutomationJob.created_at))
        jobs = r.scalars().all()
        return [{"id": j.id, "name": j.name, "description": j.description,
                 "job_type": j.job_type, "schedule": j.schedule, "is_active": j.is_active,
                 "run_count": j.run_count, "success_count": j.success_count,
                 "error_count": j.error_count, "last_run": j.last_run.isoformat() if j.last_run else None} for j in jobs]

@router.patch("/jobs/{job_id}/toggle")
async def toggle_job(job_id: int, body: dict):
    async with AsyncSessionLocal() as s:
        r = await s.execute(select(AutomationJob).where(AutomationJob.id == job_id))
        j = r.scalar_one_or_none()
        if not j:
            raise HTTPException(404, "Job não encontrado")
        j.is_active = body.get("active", not j.is_active)
        await s.commit()
        return {"message": f"Job {'ativado' if j.is_active else 'desativado'}"}

@router.post("/jobs/{job_id}/run")
async def run_job(job_id: int):
    async with AsyncSessionLocal() as s:
        r = await s.execute(select(AutomationJob).where(AutomationJob.id == job_id))
        j = r.scalar_one_or_none()
        if not j:
            raise HTTPException(404, "Job não encontrado")
        j.last_run = datetime.utcnow()
        j.run_count += 1
        j.success_count += 1
        await s.commit()
        return {"message": f"Job '{j.name}' executado com sucesso", "run_at": j.last_run.isoformat()}
'@

# ============================================================
# backend/app/api/auth.py
# ============================================================
New-FileWithContent "$ProjectRoot\backend\app\api\auth.py" @'
"""API de Autenticação (básica)"""
from fastapi import APIRouter
from pydantic import BaseModel

router = APIRouter()

class LoginRequest(BaseModel):
    username: str
    password: str

@router.post("/login")
async def login(data: LoginRequest):
    # Autenticação básica - expandir conforme necessário
    if data.username == "admin" and data.password == "hctech2024":
        return {"token": "demo-token-hctech", "user": {"name": "Admin HC Tech", "role": "admin"}}
    return {"error": "Credenciais inválidas"}

@router.get("/me")
async def me():
    return {"user": {"name": "Admin HC Tech", "role": "admin"}, "authenticated": True}
'@

# ============================================================
# backend/app/main.py
# ============================================================
New-FileWithContent "$ProjectRoot\backend\app\main.py" @'
"""HC Tech AI System v2.1 - Backend Principal"""
import os
import sys
from contextlib import asynccontextmanager
from pathlib import Path

# Adicionar root ao path para encontrar .env
root_dir = Path(__file__).parent.parent.parent
sys.path.insert(0, str(root_dir))

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.responses import JSONResponse
from loguru import logger

from app.database import init_db
from app.api.ai import router as ai_router
from app.api.agents import router as agents_router
from app.api.tasks import router as tasks_router
from app.api.seo import router as seo_router
from app.api.social import router as social_router
from app.api.maps import router as maps_router
from app.api.knowledge import router as knowledge_router
from app.api.reports import router as reports_router
from app.api.metrics import router as metrics_router
from app.api.automation import router as automation_router
from app.api.auth import router as auth_router

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("🚀 Iniciando HC Tech AI System v2.1...")
    await init_db()
    from app.services.ai_service import ai_service
    ollama_ok = await ai_service.check_ollama()
    if ollama_ok:
        logger.info("✅ Ollama conectado - IA Local disponível")
    else:
        logger.warning("⚠️  Ollama offline - use IA Online ou inicie o Ollama")
    logger.info("✅ Sistema pronto! Acesse: http://localhost:8000/docs")
    yield
    logger.info("🛑 Encerrando sistema...")

app = FastAPI(
    title="HC Tech AI System v2.1",
    description="Plataforma Híbrida Local/Online de IA para Assistências Técnicas",
    version="2.1.0",
    lifespan=lifespan,
)

app.add_middleware(CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://localhost:3001", "http://127.0.0.1:3000", "*"],
    allow_credentials=True, allow_methods=["*"], allow_headers=["*"])
app.add_middleware(GZipMiddleware, minimum_size=1000)

@app.middleware("http")
async def log_requests(request: Request, call_next):
    import time
    start = time.time()
    response = await call_next(request)
    duration = time.time() - start
    if "/health" not in request.url.path:
        logger.debug(f"{request.method} {request.url.path} → {response.status_code} ({duration:.2f}s)")
    return response

@app.exception_handler(Exception)
async def global_error(request: Request, exc: Exception):
    logger.error(f"Erro não tratado: {exc}")
    return JSONResponse(500, {"error": "Erro interno", "detail": str(exc)})

app.include_router(auth_router, prefix="/api/auth", tags=["Auth"])
app.include_router(ai_router, prefix="/api/ai", tags=["IA"])
app.include_router(agents_router, prefix="/api/agents", tags=["Agentes"])
app.include_router(tasks_router, prefix="/api/tasks", tags=["Tarefas"])
app.include_router(seo_router, prefix="/api/seo", tags=["SEO"])
app.include_router(social_router, prefix="/api/social", tags=["Social"])
app.include_router(maps_router, prefix="/api/maps", tags=["Maps"])
app.include_router(knowledge_router, prefix="/api/knowledge", tags=["Knowledge"])
app.include_router(reports_router, prefix="/api/reports", tags=["Reports"])
app.include_router(metrics_router, prefix="/api/metrics", tags=["Metrics"])
app.include_router(automation_router, prefix="/api/automation", tags=["Automation"])

@app.get("/api/health")
async def health():
    from app.services.ai_service import ai_service
    ollama = await ai_service.check_ollama()
    return {"status": "online", "version": "2.1.0", "ollama": ollama, "system": "HC Tech AI"}

@app.get("/")
async def root():
    return {"message": "HC Tech AI System v2.1 🚀", "docs": "/docs", "health": "/api/health"}
'@

Write-Host "  ✓ Backend Python completo (11 módulos)" -ForegroundColor Green

# ============================================================
# [4/8] FRONTEND NEXT.JS
# ============================================================
Write-Host "`n[4/8] Criando frontend Next.js..." -ForegroundColor Yellow

New-FileWithContent "$ProjectRoot\frontend\package.json" @'
{
  "name": "hctech-ai-frontend",
  "version": "2.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev -p 3000",
    "build": "next build",
    "start": "next start -p 3000",
    "type-check": "tsc --noEmit"
  },
  "dependencies": {
    "next": "14.2.5",
    "react": "^18.3.0",
    "react-dom": "^18.3.0",
    "lucide-react": "^0.400.0",
    "recharts": "^2.12.0",
    "clsx": "^2.1.0",
    "tailwind-merge": "^2.3.0",
    "framer-motion": "^11.0.0",
    "zustand": "^4.5.0",
    "@tanstack/react-query": "^5.28.0",
    "axios": "^1.6.8",
    "react-hot-toast": "^2.4.1",
    "react-markdown": "^9.0.1"
  },
  "devDependencies": {
    "@types/node": "^20",
    "@types/react": "^18",
    "@types/react-dom": "^18",
    "typescript": "^5",
    "tailwindcss": "^3.4.0",
    "autoprefixer": "^10.4.19",
    "postcss": "^8.4.38",
    "@tailwindcss/typography": "^0.5.13"
  }
}
'@

New-FileWithContent "$ProjectRoot\frontend\next.config.js" @'
/** @type {import("next").NextConfig} */
const nextConfig = {
  reactStrictMode: false,
  env: {
    NEXT_PUBLIC_BACKEND_URL: process.env.NEXT_PUBLIC_BACKEND_URL || "http://localhost:8000",
    NEXT_PUBLIC_APP_VERSION: "2.1.0",
  },
}
module.exports = nextConfig
'@

New-FileWithContent "$ProjectRoot\frontend\tsconfig.json" @'
{
  "compilerOptions": {
    "target": "es5",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": false,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [{"name": "next"}],
    "paths": {"@/*": ["./src/*"]}
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
'@

New-FileWithContent "$ProjectRoot\frontend\tailwind.config.js" @'
/** @type {import("tailwindcss").Config} */
module.exports = {
  content: ["./src/**/*.{js,ts,jsx,tsx,mdx}"],
  theme: {
    extend: {
      animation: {
        "fade-in": "fadeIn 0.3s ease-in-out",
        "slide-up": "slideUp 0.3s ease-out",
      },
      keyframes: {
        fadeIn: {"0%": {opacity: "0"}, "100%": {opacity: "1"}},
        slideUp: {"0%": {transform: "translateY(10px)", opacity: "0"}, "100%": {transform: "translateY(0)", opacity: "1"}},
      }
    },
  },
  plugins: [require("@tailwindcss/typography")],
}
'@

New-FileWithContent "$ProjectRoot\frontend\postcss.config.js" @'
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
'@

# App Layout
New-FileWithContent "$ProjectRoot\frontend\src\app\layout.tsx" @'
import type { Metadata } from "next"
import { Inter } from "next/font/google"
import "./globals.css"

const inter = Inter({ subsets: ["latin"] })

export const metadata: Metadata = {
  title: "HC Tech AI System v2.1",
  description: "Plataforma Híbrida Local/Online de IA para Assistências Técnicas",
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="pt-BR">
      <body className={`${inter.className} bg-slate-950 text-slate-50 antialiased`}>
        {children}
      </body>
    </html>
  )
}
'@

New-FileWithContent "$ProjectRoot\frontend\src\app\globals.css" @'
@tailwind base;
@tailwind components;
@tailwind utilities;

* { box-sizing: border-box; margin: 0; padding: 0; }

::-webkit-scrollbar { width: 6px; height: 6px; }
::-webkit-scrollbar-track { background: transparent; }
::-webkit-scrollbar-thumb { background: #334155; border-radius: 3px; }
::-webkit-scrollbar-thumb:hover { background: #475569; }

.prose-invert {
  --tw-prose-body: #cbd5e1;
  --tw-prose-headings: #f1f5f9;
  --tw-prose-bold: #f1f5f9;
  --tw-prose-code: #93c5fd;
}

.line-clamp-2 {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
'@

# Store Zustand
New-FileWithContent "$ProjectRoot\frontend\src\store\useAppStore.ts" @'
import { create } from "zustand"
import { persist } from "zustand/middleware"

type AIProvider = "ollama" | "openai" | "anthropic"
type ChatMessage = { role: "user" | "assistant" | "system"; content: string }

interface AppState {
  selectedProvider: AIProvider
  setSelectedProvider: (p: AIProvider) => void
  activeAgent: string
  setActiveAgent: (id: string) => void
  conversations: Record<string, ChatMessage[]>
  addMessage: (agentId: string, msg: ChatMessage) => void
  clearConversation: (agentId: string) => void
  currentPage: string
  setCurrentPage: (page: string) => void
  sidebarOpen: boolean
  setSidebarOpen: (open: boolean) => void
}

export const useAppStore = create<AppState>()(
  persist(
    (set) => ({
      selectedProvider: "ollama",
      setSelectedProvider: (p) => set({ selectedProvider: p }),
      activeAgent: "hc-ceo",
      setActiveAgent: (id) => set({ activeAgent: id }),
      conversations: {},
      addMessage: (agentId, msg) => set((s) => ({
        conversations: { ...s.conversations, [agentId]: [...(s.conversations[agentId] || []), msg] }
      })),
      clearConversation: (agentId) => set((s) => ({
        conversations: { ...s.conversations, [agentId]: [] }
      })),
      currentPage: "dashboard",
      setCurrentPage: (page) => set({ currentPage: page }),
      sidebarOpen: true,
      setSidebarOpen: (open) => set({ sidebarOpen: open }),
    }),
    { name: "hctech-store", partialize: (s) => ({ selectedProvider: s.selectedProvider, activeAgent: s.activeAgent, sidebarOpen: s.sidebarOpen }) }
  )
)
'@

# API Client
New-FileWithContent "$ProjectRoot\frontend\src\lib\api.ts" @'
import axios from "axios"

const BASE = process.env.NEXT_PUBLIC_BACKEND_URL || "http://localhost:8000"

export const api = axios.create({
  baseURL: `${BASE}/api`,
  timeout: 60000,
  headers: { "Content-Type": "application/json" },
})

api.interceptors.response.use(
  (r) => r,
  (e) => {
    console.error("[API]", e.response?.data?.detail || e.message)
    return Promise.reject(new Error(e.response?.data?.detail || e.message))
  }
)

export type AIProvider = "ollama" | "openai" | "anthropic"

// AI
export const getAIStatus = () => api.get("/ai/status")
export const chatWithAI = (data: object) => api.post("/ai/chat", data)
export const quickChat = (data: object) => api.post("/ai/quick", data)
export const generateReviewResponse = (data: object) => api.post("/ai/generate/review-response", data)
export const generateSocialPost = (data: object) => api.post("/social/generate-post", data)

// Agents
export const getAgents = () => api.get("/agents")
export const getAgent = (id: string) => api.get(`/agents/${id}`)
export const clearAgentHistory = (id: string) => api.delete(`/agents/${id}/history`)

// Tasks
export const getTasks = (status?: string) => api.get("/tasks", { params: { status } })
export const createTask = (data: object) => api.post("/tasks", data)
export const updateTask = (id: number, data: object) => api.put(`/tasks/${id}`, data)
export const deleteTask = (id: number) => api.delete(`/tasks/${id}`)
export const moveTask = (id: number, status: string) => api.patch(`/tasks/${id}/status`, { status })

// SEO
export const getSEOKeywords = () => api.get("/seo/keywords")
export const getSEOHealth = () => api.get("/seo/health")
export const generateSEOContent = (data: object) => api.post("/seo/generate-content", data)
export const runSEOAudit = () => api.post("/seo/audit")

// Maps / Reviews
export const getReviews = () => api.get("/maps/reviews")
export const autoRespondReview = (id: number) => api.post(`/maps/reviews/${id}/auto-respond`)
export const getMapsProfile = () => api.get("/maps/profile")

// Social
export const getSocialPosts = (platform?: string) => api.get("/social/posts", { params: { platform } })
export const getSocialMetrics = () => api.get("/social/metrics")
export const createSocialPost = (data: object) => api.post("/social/posts", data)

// Knowledge
export const getKnowledge = (search?: string, category?: string) => api.get("/knowledge", { params: { search, category } })
export const createArticle = (data: object) => api.post("/knowledge", data)
export const deleteArticle = (id: number) => api.delete(`/knowledge/${id}`)

// Metrics
export const getDashboardMetrics = () => api.get("/metrics/dashboard")

// Reports
export const generateReport = (type: string) => api.post("/reports/generate", { type })
export const getReports = () => api.get("/reports")

// Automation
export const getAutomationJobs = () => api.get("/automation/jobs")
export const toggleJob = (id: number, active: boolean) => api.patch(`/automation/jobs/${id}/toggle`, { active })
export const runJobNow = (id: number) => api.post(`/automation/jobs/${id}/run`)

// Streaming
export async function* streamChat(
  messages: { role: string; content: string }[],
  options: { provider?: string; agent_id?: string } = {}
) {
  const res = await fetch(`${BASE}/api/ai/chat/stream`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ messages, ...options }),
  })
  if (!res.ok) throw new Error(`HTTP ${res.status}`)
  const reader = res.body!.getReader()
  const dec = new TextDecoder()
  while (true) {
    const { done, value } = await reader.read()
    if (done) break
    const text = dec.decode(value)
    for (const line of text.split("\n")) {
      if (line.startsWith("data: ")) {
        try { yield JSON.parse(line.slice(6)) } catch {}
      }
    }
  }
}
'@

Write-Host "  ✓ Frontend base criado" -ForegroundColor Green

# ============================================================
# [5/8] COMPONENTES PRINCIPAIS
# ============================================================
Write-Host "`n[5/8] Criando componentes React..." -ForegroundColor Yellow

# Sidebar
New-FileWithContent "$ProjectRoot\frontend\src\components\layout\Sidebar.tsx" @'
"use client"
import { useAppStore } from "@/store/useAppStore"

const nav = [
  { id: "dashboard", label: "📊 Dashboard" },
  { id: "agents", label: "🤖 Agentes IA" },
  { id: "kanban", label: "📋 Kanban" },
  { id: "seo", label: "🔍 SEO Manager" },
  { id: "social", label: "📱 Social Hub" },
  { id: "maps", label: "📍 Google Maps" },
  { id: "knowledge", label: "📚 Conhecimento" },
  { id: "reports", label: "📈 Relatórios" },
  { id: "automation", label: "⚙️ Automação" },
  { id: "settings", label: "🛠️ Configurações" },
]

const providerInfo: Record<string, { label: string; color: string; dot: string }> = {
  ollama: { label: "🦙 Ollama Local", color: "text-green-400 bg-green-400/10 border-green-400/30", dot: "bg-green-400" },
  openai: { label: "🟢 OpenAI GPT", color: "text-blue-400 bg-blue-400/10 border-blue-400/30", dot: "bg-blue-400" },
  anthropic: { label: "🟣 Claude AI", color: "text-purple-400 bg-purple-400/10 border-purple-400/30", dot: "bg-purple-400" },
}

export default function Sidebar() {
  const { currentPage, setCurrentPage, sidebarOpen, setSidebarOpen, selectedProvider } = useAppStore()
  const pi = providerInfo[selectedProvider]

  return (
    <aside style={{ width: sidebarOpen ? 240 : 64 }}
      className="fixed left-0 top-0 h-full bg-slate-900 border-r border-slate-800 flex flex-col z-50 transition-all duration-300 overflow-hidden">
      
      {/* Logo */}
      <div className="flex items-center h-16 px-4 border-b border-slate-800 gap-3">
        <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-blue-500 to-purple-600 flex items-center justify-center flex-shrink-0 text-sm">
          🤖
        </div>
        {sidebarOpen && (
          <div className="flex-1 min-w-0">
            <p className="text-sm font-bold text-white truncate">HC Tech AI</p>
            <p className="text-xs text-slate-400">v2.1 Sistema</p>
          </div>
        )}
        <button onClick={() => setSidebarOpen(!sidebarOpen)} className="text-slate-400 hover:text-white text-lg flex-shrink-0">
          {sidebarOpen ? "◀" : "▶"}
        </button>
      </div>

      {/* AI Badge */}
      {sidebarOpen && (
        <div className="px-4 py-2 border-b border-slate-800">
          <div className={`flex items-center gap-2 px-2 py-1 rounded-md text-xs font-medium border ${pi.color}`}>
            <div className={`w-1.5 h-1.5 rounded-full ${pi.dot} animate-pulse`} />
            {pi.label}
          </div>
        </div>
      )}

      {/* Nav */}
      <nav className="flex-1 py-4 space-y-1 px-2 overflow-y-auto">
        {nav.map((item) => (
          <button key={item.id} onClick={() => setCurrentPage(item.id)}
            className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm transition-all ${
              currentPage === item.id
                ? "bg-slate-800 text-white font-medium"
                : "text-slate-400 hover:bg-slate-800/50 hover:text-white"
            }`}
            title={!sidebarOpen ? item.label : undefined}>
            <span className="text-base flex-shrink-0">{item.label.split(" ")[0]}</span>
            {sidebarOpen && <span className="truncate">{item.label.split(" ").slice(1).join(" ")}</span>}
          </button>
        ))}
      </nav>

      {/* Footer */}
      <div className="p-4 border-t border-slate-800">
        {sidebarOpen ? (
          <p className="text-xs text-slate-500 text-center">HC Tech © 2024</p>
        ) : (
          <div className="w-2 h-2 rounded-full bg-green-400 mx-auto" />
        )}
      </div>
    </aside>
  )
}
'@

# Header
New-FileWithContent "$ProjectRoot\frontend\src\components\layout\Header.tsx" @'
"use client"
import { useState } from "react"
import { useQuery } from "@tanstack/react-query"
import { getAIStatus } from "@/lib/api"
import { useAppStore } from "@/store/useAppStore"
import toast from "react-hot-toast"

const pageNames: Record<string, string> = {
  dashboard: "📊 Dashboard", agents: "🤖 Agentes IA", kanban: "📋 Kanban",
  seo: "🔍 SEO Manager", social: "📱 Social Hub", maps: "📍 Google Maps",
  knowledge: "📚 Base de Conhecimento", reports: "📈 Relatórios",
  automation: "⚙️ Automação 24/7", settings: "🛠️ Configurações",
}

const provConfig = {
  ollama: { label: "🦙 Ollama Local", color: "text-green-400 border-green-400/30 bg-green-400/10" },
  openai: { label: "🟢 OpenAI GPT", color: "text-blue-400 border-blue-400/30 bg-blue-400/10" },
  anthropic: { label: "🟣 Claude AI", color: "text-purple-400 border-purple-400/30 bg-purple-400/10" },
}

export default function Header() {
  const { selectedProvider, setSelectedProvider, currentPage } = useAppStore()
  const [open, setOpen] = useState(false)
  
  const { data } = useQuery({ queryKey: ["ai-status"], queryFn: () => getAIStatus().then(r => r.data), refetchInterval: 30000 })
  const providers = data?.providers || []
  const cur = provConfig[selectedProvider]

  const changeProvider = (p: "ollama" | "openai" | "anthropic") => {
    const info = providers.find((x: any) => x.provider === p)
    if (!info?.available) {
      toast.error(`${provConfig[p].label} não disponível. Configure no .env`)
      return
    }
    setSelectedProvider(p)
    setOpen(false)
    toast.success(`IA: ${provConfig[p].label}`)
  }

  return (
    <header className="h-16 bg-slate-900 border-b border-slate-800 flex items-center justify-between px-6 flex-shrink-0">
      <div>
        <h1 className="text-lg font-semibold text-white">{pageNames[currentPage] || "Dashboard"}</h1>
        <p className="text-xs text-slate-400">HC Tech AI System v2.1</p>
      </div>
      
      <div className="relative">
        <button onClick={() => setOpen(!open)}
          className={`flex items-center gap-2 px-3 py-2 rounded-lg border text-sm font-medium ${cur.color}`}>
          {cur.label} <span className="opacity-60">▼</span>
        </button>
        
        {open && (
          <>
            <div className="fixed inset-0 z-40" onClick={() => setOpen(false)} />
            <div className="absolute right-0 top-full mt-2 w-72 bg-slate-800 border border-slate-700 rounded-xl shadow-2xl z-50 overflow-hidden">
              <div className="p-3 border-b border-slate-700">
                <p className="text-xs font-semibold text-slate-400 uppercase">🤖 Selecionar IA</p>
              </div>
              {(["ollama", "openai", "anthropic"] as const).map(pk => {
                const pc = provConfig[pk]
                const st = providers.find((x: any) => x.provider === pk)
                return (
                  <button key={pk} onClick={() => changeProvider(pk)}
                    className={`w-full flex items-center gap-3 px-4 py-3 hover:bg-slate-700 transition-colors ${selectedProvider === pk ? "bg-slate-700" : ""}`}>
                    <div className="flex-1 text-left">
                      <p className={`text-sm font-medium ${pc.color.split(" ")[0]}`}>{pc.label}</p>
                      <p className="text-xs text-slate-400">{st?.model || "Não configurado"} {pk === "ollama" ? "• Local • Grátis" : ""}</p>
                    </div>
                    <span className={`text-xs ${st?.available ? "text-green-400" : "text-red-400"}`}>
                      {st?.available ? "✓ Online" : "✗ Offline"}
                    </span>
                    {selectedProvider === pk && <span className="text-xs text-blue-400 font-bold">Ativo</span>}
                  </button>
                )
              })}
              <div className="p-3 border-t border-slate-700 text-center">
                <p className="text-xs text-slate-500">🔒 Ollama = 100% privado no seu PC</p>
              </div>
            </div>
          </>
        )}
      </div>
    </header>
  )
}
'@

Write-Host "  ✓ Layout (Sidebar + Header)" -ForegroundColor Green

# ============================================================
# [6/8] PÁGINAS COMPLETAS
# ============================================================
Write-Host "`n[6/8] Criando páginas do sistema..." -ForegroundColor Yellow

# Dashboard
New-FileWithContent "$ProjectRoot\frontend\src\components\pages\DashboardPage.tsx" @'
"use client"
import { useQuery } from "@tanstack/react-query"
import { getDashboardMetrics, getAgents, getReviews, getSEOKeywords } from "@/lib/api"
import { AreaChart, Area, XAxis, YAxis, Tooltip, ResponsiveContainer, PieChart, Pie, Cell } from "recharts"

const COLORS = ["#3b82f6", "#22c55e", "#ec4899", "#f59e0b"]

export default function DashboardPage() {
  const { data: metrics } = useQuery({ queryKey: ["metrics"], queryFn: () => getDashboardMetrics().then(r => r.data) })
  const { data: agents } = useQuery({ queryKey: ["agents"], queryFn: () => getAgents().then(r => r.data) })
  const { data: reviews } = useQuery({ queryKey: ["reviews"], queryFn: () => getReviews().then(r => r.data) })
  const { data: keywords } = useQuery({ queryKey: ["keywords"], queryFn: () => getSEOKeywords().then(r => r.data) })

  const weekly = metrics?.weekly_data || []
  const pending = (reviews || []).filter((r: any) => !r.responded).length

  const cards = [
    { label: "Leads Orgânicos", value: metrics?.leads_organicos?.value || 147, change: "+23%", up: true, icon: "🎯" },
    { label: "Visitantes", value: (metrics?.visitantes_unicos?.value || 2847).toLocaleString(), change: "+18%", up: true, icon: "👥" },
    { label: "Avaliação Google", value: `${metrics?.avaliacao_google?.value || 4.8}⭐`, change: `${metrics?.avaliacao_google?.total || 0} avaliações`, up: true, icon: "⭐" },
    { label: "Ranking Médio", value: `#${metrics?.ranking_seo?.avg_position || 5}`, change: `${metrics?.ranking_seo?.top10 || 0} no Top10`, up: true, icon: "🔍" },
    { label: "Taxa Conversão", value: `${metrics?.taxa_conversao?.value || 14.2}%`, change: metrics?.taxa_conversao?.change || "", up: false, icon: "📊" },
    { label: "Engajamento", value: `${metrics?.engajamento_social?.value || 8.4}%`, change: "+1.2%", up: true, icon: "📱" },
  ]

  const traffic = [
    { name: "Google", value: 42 }, { name: "Maps", value: 28 },
    { name: "Social", value: 18 }, { name: "Direto", value: 12 },
  ]

  return (
    <div className="space-y-6">
      {pending > 0 && (
        <div className="bg-yellow-500/10 border border-yellow-500/30 rounded-xl p-4 flex items-center gap-3">
          <span className="text-2xl">⚠️</span>
          <div>
            <p className="text-sm font-medium text-yellow-300">{pending} avaliações sem resposta no Google Maps</p>
            <p className="text-xs text-yellow-500">Responda rapidamente para melhorar seu ranking local</p>
          </div>
        </div>
      )}

      <div className="grid grid-cols-2 lg:grid-cols-3 gap-4">
        {cards.map((c, i) => (
          <div key={i} className="bg-slate-900 border border-slate-800 rounded-xl p-5 hover:border-slate-700 transition-all">
            <div className="flex items-center justify-between mb-3">
              <span className="text-2xl">{c.icon}</span>
              <span className={`text-xs font-medium px-2 py-1 rounded-full ${c.up ? "text-green-400 bg-green-400/10" : "text-red-400 bg-red-400/10"}`}>
                {c.up ? "↗" : "↘"} {c.change}
              </span>
            </div>
            <p className="text-2xl font-bold text-white mb-1">{c.value}</p>
            <p className="text-xs text-slate-400">{c.label}</p>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2 bg-slate-900 border border-slate-800 rounded-xl p-6">
          <h3 className="text-sm font-semibold text-white mb-4">📈 Performance Semanal</h3>
          <ResponsiveContainer width="100%" height={220}>
            <AreaChart data={weekly}>
              <defs>
                <linearGradient id="gl" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#3b82f6" stopOpacity={0.3}/><stop offset="95%" stopColor="#3b82f6" stopOpacity={0}/>
                </linearGradient>
                <linearGradient id="gc" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#22c55e" stopOpacity={0.3}/><stop offset="95%" stopColor="#22c55e" stopOpacity={0}/>
                </linearGradient>
              </defs>
              <XAxis dataKey="day" tick={{fill:"#94a3b8",fontSize:12}} axisLine={false} tickLine={false}/>
              <YAxis tick={{fill:"#94a3b8",fontSize:12}} axisLine={false} tickLine={false}/>
              <Tooltip contentStyle={{backgroundColor:"#1e293b",border:"1px solid #334155",borderRadius:"8px"}}/>
              <Area type="monotone" dataKey="leads" stroke="#3b82f6" strokeWidth={2} fill="url(#gl)" name="Leads"/>
              <Area type="monotone" dataKey="conversao" stroke="#22c55e" strokeWidth={2} fill="url(#gc)" name="Conversões"/>
            </AreaChart>
          </ResponsiveContainer>
        </div>

        <div className="bg-slate-900 border border-slate-800 rounded-xl p-6">
          <h3 className="text-sm font-semibold text-white mb-4">🌐 Fontes de Tráfego</h3>
          <div className="flex justify-center mb-4">
            <ResponsiveContainer width={150} height={150}>
              <PieChart>
                <Pie data={traffic} cx="50%" cy="50%" innerRadius={40} outerRadius={65} paddingAngle={3} dataKey="value">
                  {traffic.map((_, i) => <Cell key={i} fill={COLORS[i]}/>)}
                </Pie>
                <Tooltip contentStyle={{backgroundColor:"#1e293b",border:"1px solid #334155",borderRadius:"8px",fontSize:"12px"}}/>
              </PieChart>
            </ResponsiveContainer>
          </div>
          {traffic.map((t, i) => (
            <div key={t.name} className="flex items-center justify-between text-sm mb-2">
              <div className="flex items-center gap-2">
                <div className="w-2 h-2 rounded-full" style={{backgroundColor: COLORS[i]}}/>
                <span className="text-slate-400">{t.name}</span>
              </div>
              <span className="text-white font-medium">{t.value}%</span>
            </div>
          ))}
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="bg-slate-900 border border-slate-800 rounded-xl p-6">
          <h3 className="text-sm font-semibold text-white mb-4">🤖 Agentes Ativos</h3>
          <div className="space-y-2">
            {(agents || []).map((a: any) => (
              <div key={a.id} className="flex items-center gap-3 p-2 rounded-lg hover:bg-slate-800/50">
                <span className="text-xl">{a.avatar}</span>
                <div className="flex-1">
                  <p className="text-xs font-medium text-white">{a.name}</p>
                  <p className="text-xs text-slate-500">{a.role}</p>
                </div>
                <div className={`w-2 h-2 rounded-full ${a.is_active ? "bg-green-400" : "bg-slate-600"}`}/>
              </div>
            ))}
          </div>
        </div>

        <div className="bg-slate-900 border border-slate-800 rounded-xl p-6">
          <h3 className="text-sm font-semibold text-white mb-4">🔍 Top Keywords</h3>
          <div className="space-y-3">
            {(keywords || []).slice(0, 6).map((k: any, i: number) => (
              <div key={k.id} className="flex items-center gap-2">
                <span className="text-xs text-slate-500 w-4">{i+1}</span>
                <div className="flex-1 min-w-0">
                  <p className="text-xs text-white truncate">{k.keyword}</p>
                  <div className="flex items-center gap-2 mt-0.5">
                    <div className="flex-1 h-1 bg-slate-800 rounded-full">
                      <div className="h-full bg-blue-400 rounded-full" style={{width: `${Math.max(5, 100-k.position*7)}%`}}/>
                    </div>
                    <span className="text-xs text-slate-400">#{k.position}</span>
                  </div>
                </div>
                <span className={`text-xs ${k.trend==="up"?"text-green-400":k.trend==="down"?"text-red-400":"text-slate-500"}`}>
                  {k.trend==="up"?"↗":k.trend==="down"?"↘":"→"}
                </span>
              </div>
            ))}
          </div>
        </div>

        <div className="bg-slate-900 border border-slate-800 rounded-xl p-6">
          <h3 className="text-sm font-semibold text-white mb-4">⭐ Avaliações Recentes</h3>
          <div className="space-y-3">
            {(reviews || []).slice(0,3).map((r: any) => (
              <div key={r.id} className="p-3 bg-slate-800/50 rounded-lg">
                <div className="flex items-center justify-between mb-1">
                  <span className="text-xs font-medium text-white">{r.author}</span>
                  <div className="flex">{Array.from({length:r.rating}).map((_,i)=><span key={i} className="text-yellow-400 text-xs">★</span>)}</div>
                </div>
                <p className="text-xs text-slate-400 line-clamp-2">{r.content}</p>
                {!r.responded && <p className="text-xs text-orange-400 mt-1">• Aguardando resposta</p>}
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  )
}
'@

# Agents Page
New-FileWithContent "$ProjectRoot\frontend\src\components\pages\AgentsPage.tsx" @'
"use client"
import { useState, useRef, useEffect } from "react"
import { useQuery } from "@tanstack/react-query"
import { getAgents, streamChat, clearAgentHistory } from "@/lib/api"
import { useAppStore } from "@/store/useAppStore"
import ReactMarkdown from "react-markdown"
import toast from "react-hot-toast"

const agentColors: Record<string, string> = {
  "hc-ceo": "from-purple-500 to-purple-700",
  "hc-seo": "from-green-500 to-green-700",
  "hc-social": "from-pink-500 to-pink-700",
  "hc-content": "from-orange-500 to-orange-700",
  "hc-code": "from-blue-500 to-blue-700",
}
const agentBorder: Record<string, string> = {
  "hc-ceo": "border-purple-500/40 bg-purple-500/5",
  "hc-seo": "border-green-500/40 bg-green-500/5",
  "hc-social": "border-pink-500/40 bg-pink-500/5",
  "hc-content": "border-orange-500/40 bg-orange-500/5",
  "hc-code": "border-blue-500/40 bg-blue-500/5",
}
const provLabel: Record<string, string> = {
  ollama: "🦙 Llama 3.2 Local", openai: "🟢 GPT-4o Mini", anthropic: "🟣 Claude Haiku"
}

export default function AgentsPage() {
  const { activeAgent, setActiveAgent, selectedProvider, conversations, addMessage, clearConversation } = useAppStore()
  const [input, setInput] = useState("")
  const [streaming, setStreaming] = useState(false)
  const [streamContent, setStreamContent] = useState("")
  const endRef = useRef<HTMLDivElement>(null)
  const textareaRef = useRef<HTMLTextAreaElement>(null)

  const { data: agents = [] } = useQuery({ queryKey: ["agents"], queryFn: () => getAgents().then(r => r.data) })
  const agent = (agents as any[]).find((a: any) => a.id === activeAgent)
  const messages = conversations[activeAgent] || []

  useEffect(() => { endRef.current?.scrollIntoView({behavior:"smooth"}) }, [messages, streamContent])
  useEffect(() => {
    if (textareaRef.current) {
      textareaRef.current.style.height = "auto"
      textareaRef.current.style.height = `${textareaRef.current.scrollHeight}px`
    }
  }, [input])

  const send = async () => {
    if (!input.trim() || streaming) return
    const userMsg = { role: "user" as const, content: input.trim() }
    addMessage(activeAgent, userMsg)
    setInput("")
    setStreaming(true)
    setStreamContent("")
    const allMsgs = [...messages, userMsg]
    try {
      let full = ""
      for await (const chunk of streamChat(allMsgs, { provider: selectedProvider, agent_id: activeAgent })) {
        if (chunk.type === "chunk" && chunk.content) {
          full += chunk.content
          setStreamContent(full)
        } else if (chunk.type === "error") {
          throw new Error(chunk.message || "Erro")
        }
      }
      addMessage(activeAgent, { role: "assistant", content: full })
      setStreamContent("")
    } catch (e: any) {
      toast.error(`Erro: ${e.message}`)
    } finally {
      setStreaming(false)
    }
  }

  const suggestions = ["Qual é minha estratégia atual?", "Crie um post para Instagram", "Analise meu SEO", "Gere um relatório"]

  return (
    <div className="flex gap-4 h-[calc(100vh-8rem)]">
      {/* Agent List */}
      <div className="w-56 flex-shrink-0 space-y-2 overflow-y-auto">
        <p className="text-xs font-semibold text-slate-400 uppercase tracking-wider mb-3">Agentes</p>
        {(agents as any[]).map((a: any) => (
          <button key={a.id} onClick={() => setActiveAgent(a.id)}
            className={`w-full text-left p-3 rounded-xl border transition-all ${activeAgent===a.id ? agentBorder[a.id]||"border-blue-500/40 bg-blue-500/5" : "border-slate-800 bg-slate-900 hover:border-slate-700"}`}>
            <div className="flex items-center gap-2">
              <span className="text-xl">{a.avatar}</span>
              <div className="flex-1 min-w-0">
                <p className="text-xs font-semibold text-white truncate">{a.name}</p>
                <p className="text-xs text-slate-400 truncate">{a.role}</p>
              </div>
              {activeAgent===a.id && <div className="w-1.5 h-1.5 bg-green-400 rounded-full animate-pulse"/>}
            </div>
            {activeAgent===a.id && <p className="text-xs text-slate-500 mt-2 line-clamp-2">{a.description}</p>}
          </button>
        ))}
      </div>

      {/* Chat */}
      <div className="flex-1 flex flex-col bg-slate-900 border border-slate-800 rounded-xl overflow-hidden">
        {agent && (
          <div className="flex items-center justify-between p-4 border-b border-slate-800">
            <div className="flex items-center gap-3">
              <div className={`w-10 h-10 rounded-xl bg-gradient-to-br ${agentColors[agent.id]} flex items-center justify-center text-xl`}>
                {agent.avatar}
              </div>
              <div>
                <h3 className="text-sm font-semibold text-white">{agent.name}</h3>
                <p className="text-xs text-slate-400">
                  <span className="text-green-400">● </span>{agent.role} • {provLabel[selectedProvider]}
                </p>
              </div>
            </div>
            <button onClick={() => { clearConversation(activeAgent); toast.success("Conversa limpa") }}
              className="text-xs text-slate-400 hover:text-red-400 border border-slate-700 px-3 py-1 rounded-lg transition-colors">
              🗑️ Limpar
            </button>
          </div>
        )}

        <div className="flex-1 overflow-y-auto p-4 space-y-4">
          {messages.length===0 && !streaming && (
            <div className="flex flex-col items-center justify-center h-full text-center">
              <span className="text-5xl mb-4">{agent?.avatar||"🤖"}</span>
              <h3 className="text-sm font-semibold text-white mb-2">{agent?.name} pronto!</h3>
              <p className="text-xs text-slate-400 max-w-xs mb-6">{agent?.description}</p>
              <div className="space-y-2 w-full max-w-sm">
                {suggestions.map(s => (
                  <button key={s} onClick={() => setInput(s)}
                    className="w-full text-xs text-left px-3 py-2 bg-slate-800 hover:bg-slate-700 rounded-lg text-slate-300 transition-colors border border-slate-700">
                    {s}
                  </button>
                ))}
              </div>
            </div>
          )}
          {messages.map((m, i) => (
            <div key={i} className={`flex gap-3 ${m.role==="user"?"justify-end":"justify-start"}`}>
              {m.role==="assistant" && (
                <div className={`w-7 h-7 rounded-lg bg-gradient-to-br ${agentColors[activeAgent]||"from-blue-500 to-purple-600"} flex items-center justify-center text-sm flex-shrink-0 mt-1`}>
                  {agent?.avatar||"🤖"}
                </div>
              )}
              <div className={`max-w-[78%] rounded-xl px-4 py-3 ${m.role==="user"?"bg-blue-600 text-white":"bg-slate-800 text-slate-100"}`}>
                {m.role==="assistant"
                  ? <div className="prose prose-invert prose-sm max-w-none text-xs"><ReactMarkdown>{m.content}</ReactMarkdown></div>
                  : <p className="text-sm">{m.content}</p>}
              </div>
              {m.role==="user" && (
                <div className="w-7 h-7 rounded-lg bg-slate-700 flex items-center justify-center flex-shrink-0 mt-1 text-sm">👤</div>
              )}
            </div>
          ))}
          {streaming && (
            <div className="flex gap-3 justify-start">
              <div className={`w-7 h-7 rounded-lg bg-gradient-to-br ${agentColors[activeAgent]||"from-blue-500 to-purple-600"} flex items-center justify-center text-sm flex-shrink-0 mt-1`}>
                {agent?.avatar||"🤖"}
              </div>
              <div className="max-w-[78%] bg-slate-800 rounded-xl px-4 py-3">
                {streamContent
                  ? <div className="prose prose-invert prose-sm max-w-none text-xs"><ReactMarkdown>{streamContent}</ReactMarkdown></div>
                  : <div className="flex gap-1">{[0,1,2].map(i => <div key={i} className="w-1.5 h-1.5 bg-blue-400 rounded-full animate-bounce" style={{animationDelay:`${i*0.1}s`}}/>)}</div>}
              </div>
            </div>
          )}
          <div ref={endRef}/>
        </div>

        <div className="p-4 border-t border-slate-800">
          <div className="flex items-end gap-3">
            <textarea ref={textareaRef} value={input} onChange={e=>setInput(e.target.value)}
              onKeyDown={e=>{if(e.key==="Enter"&&!e.shiftKey){e.preventDefault();send()}}}
              placeholder={`Mensagem para ${agent?.name||"o agente"}...`} disabled={streaming} rows={1}
              className="flex-1 bg-slate-800 border border-slate-700 rounded-xl px-4 py-3 text-sm text-white placeholder-slate-500 resize-none focus:outline-none focus:border-blue-500 transition-colors min-h-[44px] max-h-32"/>
            <button onClick={send} disabled={!input.trim()||streaming}
              className="w-10 h-10 rounded-xl bg-blue-600 hover:bg-blue-500 disabled:opacity-50 flex items-center justify-center transition-all">
              {streaming ? <span className="text-white text-sm animate-spin">⟳</span> : <span className="text-white text-sm">➤</span>}
            </button>
          </div>
          <p className="text-xs text-slate-600 mt-1 text-center">Shift+Enter = nova linha • Enter = enviar • {provLabel[selectedProvider]}</p>
        </div>
      </div>
    </div>
  )
}
'@

# Kanban Page
New-FileWithContent "$ProjectRoot\frontend\src\components\pages\KanbanPage.tsx" @'
"use client"
import { useState } from "react"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { getTasks, createTask, deleteTask, moveTask } from "@/lib/api"
import toast from "react-hot-toast"

const cols = [
  { id: "todo", label: "📋 A Fazer", color: "border-yellow-500/30 bg-yellow-500/5", badge: "bg-yellow-500/20 text-yellow-300" },
  { id: "in_progress", label: "⚡ Em Progresso", color: "border-blue-500/30 bg-blue-500/5", badge: "bg-blue-500/20 text-blue-300" },
  { id: "done", label: "✅ Concluído", color: "border-green-500/30 bg-green-500/5", badge: "bg-green-500/20 text-green-300" },
]
const prioColors: Record<string, string> = {
  low: "bg-slate-700 text-slate-300", medium: "bg-blue-500/20 text-blue-300",
  high: "bg-orange-500/20 text-orange-300", urgent: "bg-red-500/20 text-red-300",
}
const avatars: Record<string, string> = {
  "hc-ceo":"👔","hc-seo":"🔍","hc-social":"📱","hc-content":"✍️","hc-code":"💻"
}

export default function KanbanPage() {
  const qc = useQueryClient()
  const [modal, setModal] = useState<string|null>(null)
  const [form, setForm] = useState({ title:"", desc:"", priority:"medium", agent:"" })

  const { data: tasks = [] } = useQuery({ queryKey:["tasks"], queryFn:()=>getTasks().then(r=>r.data) })
  const moveMut = useMutation({ mutationFn:({id,st}:{id:number,st:string})=>moveTask(id,st), onSuccess:()=>qc.invalidateQueries({queryKey:["tasks"]}) })
  const delMut = useMutation({ mutationFn:deleteTask, onSuccess:()=>{qc.invalidateQueries({queryKey:["tasks"]});toast.success("Removida")} })
  const createMut = useMutation({
    mutationFn: createTask,
    onSuccess:()=>{qc.invalidateQueries({queryKey:["tasks"]});setModal(null);setForm({title:"",desc:"",priority:"medium",agent:""});toast.success("Tarefa criada!")}
  })

  const byStatus = (st: string) => (tasks as any[]).filter((t:any)=>t.status===st)

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-lg font-semibold text-white">Workflow Kanban</h2>
          <p className="text-xs text-slate-400">{(tasks as any[]).length} tarefas total</p>
        </div>
      </div>

      <div className="grid grid-cols-3 gap-4">
        {cols.map(col => {
          const colTasks = byStatus(col.id)
          return (
            <div key={col.id} className={`bg-slate-900 border rounded-xl overflow-hidden ${col.color}`}>
              <div className="flex items-center justify-between p-4 border-b border-slate-800">
                <div className="flex items-center gap-2">
                  <span className="text-sm font-semibold text-white">{col.label}</span>
                  <span className={`text-xs px-1.5 py-0.5 rounded-full font-medium ${col.badge}`}>{colTasks.length}</span>
                </div>
                <button onClick={()=>setModal(col.id)} className="w-6 h-6 rounded bg-slate-800 text-slate-400 hover:text-white flex items-center justify-center text-lg leading-none">+</button>
              </div>
              <div className="p-3 space-y-2 min-h-[200px]">
                {colTasks.map((t:any) => (
                  <div key={t.id} className="bg-slate-800 border border-slate-700 rounded-lg p-3 group hover:border-slate-600">
                    <div className="flex items-start justify-between gap-2 mb-2">
                      <p className="text-xs text-white font-medium flex-1">{t.title}</p>
                      <button onClick={()=>delMut.mutate(t.id)} className="opacity-0 group-hover:opacity-100 text-slate-500 hover:text-red-400 text-xs">✕</button>
                    </div>
                    {t.description && <p className="text-xs text-slate-500 mb-2 line-clamp-2">{t.description}</p>}
                    <div className="flex items-center gap-1 flex-wrap mb-2">
                      <span className={`text-xs px-1.5 py-0.5 rounded ${prioColors[t.priority]||prioColors.medium}`}>{t.priority}</span>
                      {t.agent_id && <span className="text-xs">{avatars[t.agent_id]||"🤖"}</span>}
                      {(t.tags||[]).map((tag:string)=>(
                        <span key={tag} className="text-xs bg-slate-700 text-slate-400 px-1.5 py-0.5 rounded">{tag}</span>
                      ))}
                    </div>
                    <div className="flex gap-1">
                      {cols.filter(c=>c.id!==col.id).map(target=>(
                        <button key={target.id} onClick={()=>moveMut.mutate({id:t.id,st:target.id})}
                          className={`flex-1 text-xs py-1 rounded border ${target.color} text-slate-300 hover:text-white transition-colors`}>
                          → {target.label.split(" ").slice(1).join(" ")}
                        </button>
                      ))}
                    </div>
                  </div>
                ))}
                {colTasks.length===0 && <p className="text-xs text-slate-700 text-center py-8">Nenhuma tarefa</p>}
              </div>
            </div>
          )
        })}
      </div>

      {modal && (
        <div className="fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4" onClick={()=>setModal(null)}>
          <div className="bg-slate-900 border border-slate-700 rounded-2xl p-6 w-full max-w-md shadow-2xl" onClick={e=>e.stopPropagation()}>
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-base font-semibold text-white">Nova Tarefa</h3>
              <button onClick={()=>setModal(null)} className="text-slate-400 hover:text-white">✕</button>
            </div>
            <div className="space-y-3">
              <input type="text" placeholder="Título..." value={form.title} onChange={e=>setForm({...form,title:e.target.value})}
                autoFocus className="w-full bg-slate-800 border border-slate-700 rounded-lg px-3 py-2 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-blue-500"/>
              <textarea placeholder="Descrição (opcional)..." value={form.desc} onChange={e=>setForm({...form,desc:e.target.value})}
                className="w-full bg-slate-800 border border-slate-700 rounded-lg px-3 py-2 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-blue-500 resize-none h-16"/>
              <div className="grid grid-cols-2 gap-2">
                <select value={form.priority} onChange={e=>setForm({...form,priority:e.target.value})}
                  className="bg-slate-800 border border-slate-700 rounded-lg px-3 py-2 text-sm text-white focus:outline-none focus:border-blue-500">
                  <option value="low">Baixa</option><option value="medium">Média</option>
                  <option value="high">Alta</option><option value="urgent">Urgente</option>
                </select>
                <select value={form.agent} onChange={e=>setForm({...form,agent:e.target.value})}
                  className="bg-slate-800 border border-slate-700 rounded-lg px-3 py-2 text-sm text-white focus:outline-none focus:border-blue-500">
                  <option value="">Sem agente</option>
                  <option value="hc-ceo">👔 CEO</option><option value="hc-seo">🔍 SEO</option>
                  <option value="hc-social">📱 Social</option><option value="hc-content">✍️ Content</option>
                  <option value="hc-code">💻 Code</option>
                </select>
              </div>
              <div className="flex gap-2 pt-2">
                <button onClick={()=>setModal(null)} className="flex-1 py-2 text-sm text-slate-400 border border-slate-700 rounded-lg hover:bg-slate-800">Cancelar</button>
                <button onClick={()=>createMut.mutate({title:form.title,description:form.desc,status:modal,priority:form.priority,agent_id:form.agent||undefined,tags:[]})}
                  disabled={!form.title.trim()||createMut.isPending}
                  className="flex-1 py-2 text-sm text-white bg-blue-600 hover:bg-blue-500 disabled:opacity-50 rounded-lg transition-colors">
                  {createMut.isPending?"Criando...":"✓ Criar"}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
'@

# SEO, Social, Maps, Knowledge, Reports, Automation, Settings pages (condensed)
New-FileWithContent "$ProjectRoot\frontend\src\components\pages\SEOPage.tsx" @'
"use client"
import { useState } from "react"
import { useQuery, useMutation } from "@tanstack/react-query"
import { getSEOKeywords, getSEOHealth, generateSEOContent, runSEOAudit } from "@/lib/api"
import toast from "react-hot-toast"

export default function SEOPage() {
  const [keyword, setKeyword] = useState("")
  const [contentType, setContentType] = useState("blog_post")
  const [generated, setGenerated] = useState("")

  const { data: keywords = [] } = useQuery({ queryKey:["keywords"], queryFn:()=>getSEOKeywords().then(r=>r.data) })
  const { data: health } = useQuery({ queryKey:["seo-health"], queryFn:()=>getSEOHealth().then(r=>r.data) })

  const genMut = useMutation({
    mutationFn: () => generateSEOContent({keyword,content_type:contentType}).then(r=>r.data),
    onSuccess: (data) => { setGenerated(data.content); toast.success("Conteúdo gerado!") }
  })
  const auditMut = useMutation({
    mutationFn: () => runSEOAudit().then(r=>r.data),
    onSuccess: (data) => { setGenerated(data.audit); toast.success("Auditoria concluída!") }
  })

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <div className="lg:col-span-2 bg-slate-900 border border-slate-800 rounded-xl p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-sm font-semibold text-white">🔍 Keywords Ranqueadas</h3>
            <span className="text-xs text-slate-400">{(keywords as any[]).length} keywords</span>
          </div>
          <div className="space-y-2">
            {(keywords as any[]).map((k:any,i:number) => (
              <div key={k.id} className="flex items-center gap-4 p-3 bg-slate-800/50 rounded-lg hover:bg-slate-800 transition-colors">
                <span className="text-xs text-slate-500 w-5">{i+1}</span>
                <div className="flex-1">
                  <p className="text-sm text-white font-medium">{k.keyword}</p>
                  <p className="text-xs text-slate-500">Vol: {k.volume.toLocaleString()} • Dif: {k.difficulty}%</p>
                </div>
                <div className="text-center">
                  <p className="text-lg font-bold text-white">#{k.position}</p>
                  <p className="text-xs text-slate-400">posição</p>
                </div>
                <div className={`w-6 h-6 rounded-full flex items-center justify-center text-xs font-bold ${
                  k.trend==="up"?"bg-green-500/20 text-green-400":k.trend==="down"?"bg-red-500/20 text-red-400":"bg-slate-700 text-slate-400"}`}>
                  {k.trend==="up"?"↑":k.trend==="down"?"↓":"→"}
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="space-y-4">
          <div className="bg-slate-900 border border-slate-800 rounded-xl p-6 text-center">
            <p className="text-xs text-slate-400 mb-2">SEO Health Score</p>
            <div className="relative w-24 h-24 mx-auto mb-3">
              <svg viewBox="0 0 36 36" className="w-24 h-24 -rotate-90">
                <circle cx="18" cy="18" r="15.9" fill="none" stroke="#1e293b" strokeWidth="3"/>
                <circle cx="18" cy="18" r="15.9" fill="none" stroke="#22c55e" strokeWidth="3"
                  strokeDasharray={`${health?.health_score||72} 100`} strokeLinecap="round"/>
              </svg>
              <div className="absolute inset-0 flex items-center justify-center">
                <span className="text-2xl font-bold text-white">{health?.health_score||72}</span>
              </div>
            </div>
            <p className="text-sm font-semibold text-green-400">{health?.status||"Bom"}</p>
            <div className="mt-4 space-y-2 text-left">
              <div className="flex justify-between text-xs">
                <span className="text-slate-400">Top 10</span>
                <span className="text-white font-medium">{health?.top_10||0} keywords</span>
              </div>
              <div className="flex justify-between text-xs">
                <span className="text-slate-400">Pos. Média</span>
                <span className="text-white font-medium">#{health?.avg_position||5}</span>
              </div>
            </div>
          </div>

          <button onClick={()=>auditMut.mutate()} disabled={auditMut.isPending}
            className="w-full py-3 bg-orange-500/20 border border-orange-500/30 text-orange-300 rounded-xl text-sm hover:bg-orange-500/30 transition-colors disabled:opacity-50">
            {auditMut.isPending?"🔍 Analisando...":"🔍 Rodar Auditoria IA"}
          </button>
        </div>
      </div>

      <div className="bg-slate-900 border border-slate-800 rounded-xl p-6">
        <h3 className="text-sm font-semibold text-white mb-4">✨ Gerador de Conteúdo SEO (IA)</h3>
        <div className="flex gap-3 mb-4">
          <input type="text" placeholder="Ex: conserto celular São Paulo" value={keyword} onChange={e=>setKeyword(e.target.value)}
            className="flex-1 bg-slate-800 border border-slate-700 rounded-lg px-3 py-2 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-blue-500"/>
          <select value={contentType} onChange={e=>setContentType(e.target.value)}
            className="bg-slate-800 border border-slate-700 rounded-lg px-3 py-2 text-sm text-white focus:outline-none focus:border-blue-500">
            <option value="blog_post">Artigo Blog</option>
            <option value="meta_description">Meta Description</option>
            <option value="title">Títulos SEO</option>
          </select>
          <button onClick={()=>genMut.mutate()} disabled={!keyword||genMut.isPending}
            className="px-4 py-2 bg-blue-600 hover:bg-blue-500 disabled:opacity-50 text-white rounded-lg text-sm transition-colors">
            {genMut.isPending?"Gerando...":"Gerar"}
          </button>
        </div>
        {generated && (
          <div className="bg-slate-800 rounded-lg p-4 text-xs text-slate-200 max-h-60 overflow-y-auto whitespace-pre-wrap font-mono">
            {generated}
          </div>
        )}
      </div>
    </div>
  )
}
'@

New-FileWithContent "$ProjectRoot\frontend\src\components\pages\SocialPage.tsx" @'
"use client"
import { useState } from "react"
import { useQuery, useMutation } from "@tanstack/react-query"
import { getSocialMetrics, generateSocialPost } from "@/lib/api"
import toast from "react-hot-toast"

export default function SocialPage() {
  const [platform, setPlatform] = useState("instagram")
  const [topic, setTopic] = useState("")
  const [generated, setGenerated] = useState<any>(null)

  const { data: metrics } = useQuery({ queryKey:["social-metrics"], queryFn:()=>getSocialMetrics().then(r=>r.data) })
  const genMut = useMutation({
    mutationFn:()=>generateSocialPost({platform,topic}).then(r=>r.data),
    onSuccess:(data)=>{setGenerated(data);toast.success("Post gerado!")}
  })

  const fb = metrics?.facebook
  const ig = metrics?.instagram

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-2 gap-4">
        <div className="bg-slate-900 border border-slate-800 rounded-xl p-6">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-10 h-10 rounded-xl bg-blue-600/20 flex items-center justify-center text-2xl">📘</div>
            <div><h3 className="text-sm font-semibold text-white">Facebook</h3><p className="text-xs text-slate-400">Página comercial</p></div>
          </div>
          <div className="grid grid-cols-2 gap-3">
            {[["Seguidores",fb?.followers?.toLocaleString()],[" Alcance/sem",fb?.reach_week?.toLocaleString()],["Engajamento",`${fb?.engagement_rate}%`],["Mensagens",fb?.messages_pending+" pendentes"]].map(([l,v])=>(
              <div key={l} className="bg-slate-800/50 rounded-lg p-3">
                <p className="text-xs text-slate-400">{l}</p>
                <p className="text-sm font-bold text-white">{v}</p>
              </div>
            ))}
          </div>
        </div>
        <div className="bg-slate-900 border border-slate-800 rounded-xl p-6">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-10 h-10 rounded-xl bg-pink-600/20 flex items-center justify-center text-2xl">📸</div>
            <div><h3 className="text-sm font-semibold text-white">Instagram</h3><p className="text-xs text-slate-400">Perfil comercial</p></div>
          </div>
          <div className="grid grid-cols-2 gap-3">
            {[["Seguidores",ig?.followers?.toLocaleString()],["Alcance/sem",ig?.reach_week?.toLocaleString()],["Engajamento",`${ig?.engagement_rate}%`],["Stories/sem",ig?.stories_week]].map(([l,v])=>(
              <div key={l} className="bg-slate-800/50 rounded-lg p-3">
                <p className="text-xs text-slate-400">{l}</p>
                <p className="text-sm font-bold text-white">{v}</p>
              </div>
            ))}
          </div>
        </div>
      </div>

      <div className="bg-slate-900 border border-slate-800 rounded-xl p-6">
        <h3 className="text-sm font-semibold text-white mb-4">✨ Gerador de Posts (IA)</h3>
        <div className="flex gap-3 mb-4">
          <select value={platform} onChange={e=>setPlatform(e.target.value)}
            className="bg-slate-800 border border-slate-700 rounded-lg px-3 py-2 text-sm text-white focus:outline-none focus:border-blue-500">
            <option value="instagram">📸 Instagram</option>
            <option value="facebook">📘 Facebook</option>
          </select>
          <input type="text" placeholder="Tópico do post (ex: troca de tela iPhone)..." value={topic} onChange={e=>setTopic(e.target.value)}
            className="flex-1 bg-slate-800 border border-slate-700 rounded-lg px-3 py-2 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-blue-500"/>
          <button onClick={()=>genMut.mutate()} disabled={!topic||genMut.isPending}
            className="px-4 py-2 bg-pink-600 hover:bg-pink-500 disabled:opacity-50 text-white rounded-lg text-sm transition-colors">
            {genMut.isPending?"Gerando...":"✨ Gerar"}
          </button>
        </div>
        {generated && (
          <div className="space-y-3">
            <div className="bg-slate-800 rounded-lg p-4">
              <p className="text-xs text-slate-400 mb-2">📝 Caption:</p>
              <p className="text-sm text-white whitespace-pre-wrap">{generated.caption}</p>
            </div>
            <div className="grid grid-cols-3 gap-3">
              <div className="bg-slate-800 rounded-lg p-3">
                <p className="text-xs text-slate-400 mb-1">#️⃣ Hashtags</p>
                <p className="text-xs text-blue-400">{(generated.hashtags||[]).join(" ")}</p>
              </div>
              <div className="bg-slate-800 rounded-lg p-3">
                <p className="text-xs text-slate-400 mb-1">📣 CTA</p>
                <p className="text-xs text-white">{generated.cta}</p>
              </div>
              <div className="bg-slate-800 rounded-lg p-3">
                <p className="text-xs text-slate-400 mb-1">⏰ Melhor Hora</p>
                <p className="text-xs text-green-400 font-bold">{generated.best_time}</p>
              </div>
            </div>
          </div>
        )}
      </div>

      <div className="bg-slate-900 border border-slate-800 rounded-xl p-6">
        <h3 className="text-sm font-semibold text-white mb-4">⏰ Melhores Horários de Publicação</h3>
        <div className="grid grid-cols-2 gap-4">
          {["facebook","instagram"].map(p=>(
            <div key={p} className="bg-slate-800/50 rounded-lg p-4">
              <p className="text-xs font-medium text-slate-300 mb-3 capitalize">{p==="facebook"?"📘 Facebook":"📸 Instagram"}</p>
              <div className="flex gap-2">
                {(metrics?.best_times?.[p]||["19:00","12:00","09:00"]).map((t:string)=>(
                  <span key={t} className="bg-slate-700 text-white text-xs px-2 py-1 rounded font-mono">{t}</span>
                ))}
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
'@

New-FileWithContent "$ProjectRoot\frontend\src\components\pages\MapsPage.tsx" @'
"use client"
import { useState } from "react"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { getReviews, getMapsProfile, autoRespondReview } from "@/lib/api"
import toast from "react-hot-toast"

export default function MapsPage() {
  const qc = useQueryClient()
  const { data: reviews = [] } = useQuery({ queryKey:["reviews"], queryFn:()=>getReviews().then(r=>r.data) })
  const { data: profile } = useQuery({ queryKey:["maps-profile"], queryFn:()=>getMapsProfile().then(r=>r.data) })

  const respondMut = useMutation({
    mutationFn:(id:number)=>autoRespondReview(id).then(r=>r.data),
    onSuccess:()=>{qc.invalidateQueries({queryKey:["reviews"]});toast.success("Resposta gerada pela IA!")}
  })

  const sentColor = (s:string) => s==="positive"?"text-green-400 bg-green-400/10":s==="negative"?"text-red-400 bg-red-400/10":"text-yellow-400 bg-yellow-400/10"

  return (
    <div className="space-y-6">
      {profile && (
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
          {[
            {label:"Avaliação",value:`${profile.rating}⭐`,sub:`${profile.total_reviews} avaliações`},
            {label:"Taxa Resposta",value:profile.response_rate,sub:`${profile.responded_reviews} respondidas`},
            {label:"Visualizações/mês",value:profile.monthly_views?.toLocaleString(),sub:"Perfil visto"},
            {label:"Completude",value:`${profile.profile_completeness}%`,sub:profile.status},
          ].map((c,i)=>(
            <div key={i} className="bg-slate-900 border border-slate-800 rounded-xl p-5">
              <p className="text-xs text-slate-400 mb-1">{c.label}</p>
              <p className="text-xl font-bold text-white">{c.value}</p>
              <p className="text-xs text-slate-500 mt-1">{c.sub}</p>
            </div>
          ))}
        </div>
      )}

      <div className="grid grid-cols-3 gap-4">
        {[
          {label:"Cliques Ligação",value:profile?.calls||89,icon:"📞",color:"text-green-400"},
          {label:"Pedidos Rota",value:profile?.directions||156,icon:"🗺️",color:"text-blue-400"},
          {label:"Cliques Site",value:234,icon:"🌐",color:"text-purple-400"},
        ].map((s,i)=>(
          <div key={i} className="bg-slate-900 border border-slate-800 rounded-xl p-4 flex items-center gap-4">
            <span className="text-3xl">{s.icon}</span>
            <div>
              <p className={`text-xl font-bold ${s.color}`}>{s.value}</p>
              <p className="text-xs text-slate-400">{s.label}</p>
            </div>
          </div>
        ))}
      </div>

      <div className="bg-slate-900 border border-slate-800 rounded-xl p-6">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-sm font-semibold text-white">⭐ Avaliações Google Maps</h3>
          <span className="text-xs text-slate-400">{(reviews as any[]).filter((r:any)=>!r.responded).length} sem resposta</span>
        </div>
        <div className="space-y-4">
          {(reviews as any[]).map((r:any)=>(
            <div key={r.id} className="bg-slate-800/50 border border-slate-700 rounded-xl p-4">
              <div className="flex items-start justify-between gap-3 mb-3">
                <div className="flex-1">
                  <div className="flex items-center gap-2 mb-1">
                    <span className="text-sm font-medium text-white">{r.author}</span>
                    <div className="flex">{Array.from({length:r.rating}).map((_,i)=><span key={i} className="text-yellow-400 text-xs">★</span>)}</div>
                    <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${sentColor(r.sentiment)}`}>{r.sentiment}</span>
                  </div>
                  <p className="text-sm text-slate-300">{r.content}</p>
                </div>
                {!r.responded && (
                  <button onClick={()=>respondMut.mutate(r.id)} disabled={respondMut.isPending}
                    className="flex-shrink-0 text-xs px-3 py-1.5 bg-blue-600/20 border border-blue-500/30 text-blue-300 rounded-lg hover:bg-blue-600/30 transition-colors disabled:opacity-50">
                    {respondMut.isPending?"🤖...":"🤖 IA"}
                  </button>
                )}
              </div>
              {r.ai_response && (
                <div className="bg-slate-900 rounded-lg p-3 border-l-2 border-blue-500">
                  <p className="text-xs text-slate-400 mb-1">✅ Resposta:</p>
                  <p className="text-xs text-slate-300">{r.ai_response}</p>
                </div>
              )}
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
'@

New-FileWithContent "$ProjectRoot\frontend\src\components\pages\KnowledgePage.tsx" @'
"use client"
import { useState } from "react"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { getKnowledge, createArticle, deleteArticle } from "@/lib/api"
import toast from "react-hot-toast"
import ReactMarkdown from "react-markdown"

export default function KnowledgePage() {
  const qc = useQueryClient()
  const [search, setSearch] = useState("")
  const [selected, setSelected] = useState<any>(null)
  const [creating, setCreating] = useState(false)
  const [form, setForm] = useState({ title:"", content:"", category:"Geral" })

  const { data: articles = [] } = useQuery({ queryKey:["knowledge",search], queryFn:()=>getKnowledge(search||undefined).then(r=>r.data) })
  const createMut = useMutation({
    mutationFn:()=>createArticle(form).then(r=>r.data),
    onSuccess:()=>{qc.invalidateQueries({queryKey:["knowledge"]});setCreating(false);setForm({title:"",content:"",category:"Geral"});toast.success("Artigo criado!")}
  })
  const delMut = useMutation({
    mutationFn:(id:number)=>deleteArticle(id),
    onSuccess:()=>{qc.invalidateQueries({queryKey:["knowledge"]});setSelected(null);toast.success("Removido")}
  })

  return (
    <div className="flex gap-4 h-[calc(100vh-8rem)]">
      <div className="w-72 flex-shrink-0 flex flex-col bg-slate-900 border border-slate-800 rounded-xl overflow-hidden">
        <div className="p-4 border-b border-slate-800 space-y-2">
          <input type="text" placeholder="🔍 Buscar artigos..." value={search} onChange={e=>setSearch(e.target.value)}
            className="w-full bg-slate-800 border border-slate-700 rounded-lg px-3 py-2 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-blue-500"/>
          <button onClick={()=>setCreating(true)} className="w-full py-2 bg-blue-600 hover:bg-blue-500 text-white rounded-lg text-xs transition-colors">+ Novo Artigo</button>
        </div>
        <div className="flex-1 overflow-y-auto p-2 space-y-1">
          {(articles as any[]).map((a:any)=>(
            <button key={a.id} onClick={()=>setSelected(a)}
              className={`w-full text-left p-3 rounded-lg transition-colors ${selected?.id===a.id?"bg-slate-700 border border-slate-600":"hover:bg-slate-800/50 border border-transparent"}`}>
              <p className="text-xs font-medium text-white truncate">{a.title}</p>
              <div className="flex items-center gap-2 mt-1">
                <span className="text-xs text-slate-500 bg-slate-800 px-1.5 py-0.5 rounded">{a.category}</span>
                <span className="text-xs text-slate-600">{a.view_count} views</span>
              </div>
            </button>
          ))}
          {(articles as any[]).length===0 && <p className="text-xs text-slate-600 text-center py-8">Nenhum artigo encontrado</p>}
        </div>
      </div>

      <div className="flex-1 bg-slate-900 border border-slate-800 rounded-xl overflow-hidden">
        {creating ? (
          <div className="p-6 space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="text-sm font-semibold text-white">Novo Artigo</h3>
              <button onClick={()=>setCreating(false)} className="text-slate-400 hover:text-white">✕</button>
            </div>
            <input type="text" placeholder="Título do artigo..." value={form.title} onChange={e=>setForm({...form,title:e.target.value})}
              className="w-full bg-slate-800 border border-slate-700 rounded-lg px-3 py-2 text-sm text-white focus:outline-none focus:border-blue-500"/>
            <select value={form.category} onChange={e=>setForm({...form,category:e.target.value})}
              className="w-full bg-slate-800 border border-slate-700 rounded-lg px-3 py-2 text-sm text-white focus:outline-none focus:border-blue-500">
              <option>Geral</option><option>Processos</option><option>SEO</option>
              <option>Social Media</option><option>Técnico</option><option>Atendimento</option>
            </select>
            <textarea placeholder="Conteúdo (suporta Markdown)..." value={form.content} onChange={e=>setForm({...form,content:e.target.value})}
              className="w-full bg-slate-800 border border-slate-700 rounded-lg px-3 py-2 text-sm text-white focus:outline-none focus:border-blue-500 resize-none h-64 font-mono"/>
            <div className="flex gap-2">
              <button onClick={()=>setCreating(false)} className="flex-1 py-2 text-sm text-slate-400 border border-slate-700 rounded-lg hover:bg-slate-800">Cancelar</button>
              <button onClick={()=>createMut.mutate()} disabled={!form.title||!form.content||createMut.isPending}
                className="flex-1 py-2 bg-blue-600 hover:bg-blue-500 disabled:opacity-50 text-white rounded-lg text-sm">
                {createMut.isPending?"Salvando...":"💾 Salvar"}
              </button>
            </div>
          </div>
        ) : selected ? (
          <div className="p-6 h-full overflow-y-auto">
            <div className="flex items-start justify-between mb-4">
              <div>
                <h2 className="text-base font-bold text-white">{selected.title}</h2>
                <p className="text-xs text-slate-400 mt-1">{selected.category} • {selected.view_count} visualizações</p>
              </div>
              <button onClick={()=>delMut.mutate(selected.id)} className="text-xs text-red-400 hover:text-red-300 border border-red-400/30 px-2 py-1 rounded-lg">🗑️ Remover</button>
            </div>
            <div className="prose prose-invert prose-sm max-w-none">
              <ReactMarkdown>{selected.content}</ReactMarkdown>
            </div>
          </div>
        ) : (
          <div className="flex items-center justify-center h-full">
            <div className="text-center">
              <span className="text-4xl">📚</span>
              <p className="text-sm text-slate-400 mt-3">Selecione um artigo para visualizar</p>
              <p className="text-xs text-slate-600 mt-1">ou crie um novo</p>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
'@

New-FileWithContent "$ProjectRoot\frontend\src\components\pages\ReportsPage.tsx" @'
"use client"
import { useState } from "react"
import { useMutation } from "@tanstack/react-query"
import { generateReport } from "@/lib/api"
import toast from "react-hot-toast"
import ReactMarkdown from "react-markdown"

const reportTypes = [
  { id:"seo", label:"🔍 Auditoria SEO", desc:"Análise técnica, problemas e recomendações", color:"text-blue-400 border-blue-500/30 bg-blue-500/10" },
  { id:"ranking", label:"📊 Ranking de Termos", desc:"Keywords, posições e oportunidades", color:"text-green-400 border-green-500/30 bg-green-500/10" },
  { id:"monthly", label:"📅 Relatório Mensal", desc:"Resumo completo do mês com IA", color:"text-purple-400 border-purple-500/30 bg-purple-500/10" },
  { id:"social", label:"📱 Análise Social", desc:"Performance de redes sociais", color:"text-pink-400 border-pink-500/30 bg-pink-500/10" },
]

export default function ReportsPage() {
  const [content, setContent] = useState("")
  const [activeType, setActiveType] = useState("")
  const genMut = useMutation({
    mutationFn:(type:string)=>generateReport(type).then(r=>r.data),
    onSuccess:(data,type)=>{setContent(data.report);setActiveType(type);toast.success("Relatório gerado!")}
  })

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        {reportTypes.map(rt=>(
          <button key={rt.id} onClick={()=>genMut.mutate(rt.id)} disabled={genMut.isPending}
            className={`p-4 rounded-xl border text-left transition-all hover:scale-105 disabled:opacity-50 ${rt.color} ${activeType===rt.id?"ring-2 ring-offset-1 ring-offset-slate-950 ring-current":""}`}>
            <p className="text-sm font-semibold mb-1">{rt.label}</p>
            <p className="text-xs opacity-70">{rt.desc}</p>
            {activeType===rt.id && genMut.isPending && <p className="text-xs mt-2 animate-pulse">Gerando com IA...</p>}
          </button>
        ))}
      </div>

      {genMut.isPending && (
        <div className="bg-slate-900 border border-slate-800 rounded-xl p-12 text-center">
          <div className="text-4xl mb-4 animate-spin">⟳</div>
          <p className="text-sm text-slate-300">IA analisando seus dados...</p>
          <p className="text-xs text-slate-500 mt-1">Isso pode levar alguns segundos</p>
        </div>
      )}

      {content && !genMut.isPending && (
        <div className="bg-slate-900 border border-slate-800 rounded-xl p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-sm font-semibold text-white">{reportTypes.find(r=>r.id===activeType)?.label}</h3>
            <button onClick={()=>navigator.clipboard.writeText(content).then(()=>toast.success("Copiado!"))}
              className="text-xs text-slate-400 hover:text-white border border-slate-700 px-2 py-1 rounded">📋 Copiar</button>
          </div>
          <div className="prose prose-invert prose-sm max-w-none">
            <ReactMarkdown>{content}</ReactMarkdown>
          </div>
        </div>
      )}
    </div>
  )
}
'@

New-FileWithContent "$ProjectRoot\frontend\src\components\pages\AutomationPage.tsx" @'
"use client"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { getAutomationJobs, toggleJob, runJobNow } from "@/lib/api"
import toast from "react-hot-toast"

const cronLabels: Record<string,string> = {
  "0 9 * * *":"Diário às 09:00","0 8 * * 0":"Domingo às 08:00","0 2 * * *":"Diário às 02:00"
}

export default function AutomationPage() {
  const qc = useQueryClient()
  const { data: jobs = [] } = useQuery({ queryKey:["jobs"], queryFn:()=>getAutomationJobs().then(r=>r.data) })
  const toggleMut = useMutation({
    mutationFn:({id,active}:{id:number,active:boolean})=>toggleJob(id,active).then(r=>r.data),
    onSuccess:()=>{qc.invalidateQueries({queryKey:["jobs"]});toast.success("Job atualizado")}
  })
  const runMut = useMutation({
    mutationFn:(id:number)=>runJobNow(id).then(r=>r.data),
    onSuccess:(data)=>toast.success(data.message||"Executado!")
  })

  const typeIcons: Record<string,string> = { review_check:"⭐", seo_report:"🔍", backup:"💾", social_post:"📱" }

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-3 gap-4">
        {[
          {label:"Jobs Ativos",value:(jobs as any[]).filter((j:any)=>j.is_active).length,color:"text-green-400"},
          {label:"Total Execuções",value:(jobs as any[]).reduce((a:number,j:any)=>a+j.run_count,0),color:"text-blue-400"},
          {label:"Taxa de Sucesso",value:`${Math.round(((jobs as any[]).reduce((a:number,j:any)=>a+j.success_count,0)/Math.max(1,(jobs as any[]).reduce((a:number,j:any)=>a+j.run_count,0)))*100)}%`,color:"text-purple-400"},
        ].map((s,i)=>(
          <div key={i} className="bg-slate-900 border border-slate-800 rounded-xl p-5">
            <p className="text-xs text-slate-400">{s.label}</p>
            <p className={`text-2xl font-bold mt-1 ${s.color}`}>{s.value}</p>
          </div>
        ))}
      </div>

      <div className="bg-slate-900 border border-slate-800 rounded-xl overflow-hidden">
        <div className="p-4 border-b border-slate-800">
          <h3 className="text-sm font-semibold text-white">⚙️ Jobs de Automação</h3>
        </div>
        <div className="divide-y divide-slate-800">
          {(jobs as any[]).map((j:any)=>(
            <div key={j.id} className="flex items-center gap-4 p-4 hover:bg-slate-800/30 transition-colors">
              <span className="text-2xl flex-shrink-0">{typeIcons[j.job_type]||"⚙️"}</span>
              <div className="flex-1 min-w-0">
                <p className="text-sm font-medium text-white">{j.name}</p>
                <p className="text-xs text-slate-400">{j.description}</p>
                <div className="flex items-center gap-3 mt-1">
                  <span className="text-xs text-slate-500 font-mono">{cronLabels[j.schedule]||j.schedule}</span>
                  <span className="text-xs text-slate-600">• {j.run_count} execuções</span>
                  {j.last_run && <span className="text-xs text-slate-600">• Último: {new Date(j.last_run).toLocaleDateString("pt-BR")}</span>}
                </div>
              </div>
              <div className="flex items-center gap-2 flex-shrink-0">
                <button onClick={()=>runMut.mutate(j.id)} disabled={runMut.isPending}
                  className="text-xs text-blue-400 border border-blue-400/30 px-2 py-1 rounded hover:bg-blue-400/10 transition-colors disabled:opacity-50">
                  ▶ Executar
                </button>
                <button onClick={()=>toggleMut.mutate({id:j.id,active:!j.is_active})}
                  className={`relative w-10 h-5 rounded-full transition-colors ${j.is_active?"bg-green-500":"bg-slate-700"}`}>
                  <div className={`absolute top-0.5 w-4 h-4 bg-white rounded-full transition-transform ${j.is_active?"translate-x-5":"translate-x-0.5"}`}/>
                </button>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
'@

New-FileWithContent "$ProjectRoot\frontend\src\components\pages\SettingsPage.tsx" @'
"use client"
import { useState } from "react"
import { useQuery } from "@tanstack/react-query"
import { getAIStatus } from "@/lib/api"
import { useAppStore } from "@/store/useAppStore"
import toast from "react-hot-toast"

export default function SettingsPage() {
  const { selectedProvider, setSelectedProvider } = useAppStore()
  const { data, refetch } = useQuery({ queryKey:["ai-status"], queryFn:()=>getAIStatus().then(r=>r.data) })
  const providers = data?.providers || []

  return (
    <div className="space-y-6 max-w-2xl">
      <div className="bg-slate-900 border border-slate-800 rounded-xl p-6">
        <h3 className="text-sm font-semibold text-white mb-4">🤖 Provedores de IA</h3>
        <div className="space-y-3">
          {providers.map((p:any)=>(
            <div key={p.provider} className="flex items-center justify-between p-4 bg-slate-800/50 rounded-xl border border-slate-700">
              <div>
                <div className="flex items-center gap-2 mb-1">
                  <p className="text-sm font-medium text-white">
                    {p.provider==="ollama"?"🦙":p.provider==="openai"?"🟢":"🟣"} {p.name}
                  </p>
                  {p.local && <span className="text-xs bg-green-500/20 text-green-400 px-1.5 py-0.5 rounded">LOCAL</span>}
                  {p.free && <span className="text-xs bg-blue-500/20 text-blue-400 px-1.5 py-0.5 rounded">GRÁTIS</span>}
                </div>
                <p className="text-xs text-slate-400">Modelo: {p.model}</p>
                <p className="text-xs text-slate-500">{p.description}</p>
                {p.provider==="ollama" && p.models?.length>0 && (
                  <p className="text-xs text-green-400 mt-1">✓ Modelos: {p.models.join(", ")}</p>
                )}
              </div>
              <div className="flex items-center gap-3">
                <div className="text-center">
                  <div className={`w-2.5 h-2.5 rounded-full mx-auto ${p.available?"bg-green-400 animate-pulse":"bg-red-500"}`}/>
                  <p className="text-xs text-slate-400 mt-1">{p.available?"Online":"Offline"}</p>
                </div>
                {p.available && (
                  <button onClick={()=>{setSelectedProvider(p.provider);toast.success(`IA: ${p.name}`)}}
                    className={`text-xs px-3 py-1.5 rounded-lg border transition-colors ${selectedProvider===p.provider?"bg-blue-600 border-blue-500 text-white":"border-slate-600 text-slate-300 hover:bg-slate-700"}`}>
                    {selectedProvider===p.provider?"✓ Ativo":"Usar"}
                  </button>
                )}
              </div>
            </div>
          ))}
        </div>
        <button onClick={()=>refetch()} className="mt-3 w-full py-2 bg-slate-800 hover:bg-slate-700 text-slate-300 rounded-lg text-xs transition-colors">
          🔄 Verificar Status
        </button>
      </div>

      <div className="bg-slate-900 border border-slate-800 rounded-xl p-6">
        <h3 className="text-sm font-semibold text-white mb-4">⚙️ Sobre o Sistema</h3>
        <div className="space-y-3 text-sm">
          {[
            ["Sistema","HC Tech AI System"],["Versão","v2.1.0"],["Backend","Python FastAPI"],
            ["Frontend","Next.js 14"],["IA Local","Ollama + Llama 3.2:3B"],["Banco","SQLite (local)"],
          ].map(([k,v])=>(
            <div key={k} className="flex justify-between py-2 border-b border-slate-800 last:border-0">
              <span className="text-slate-400">{k}</span>
              <span className="text-white font-medium">{v}</span>
            </div>
          ))}
        </div>
      </div>

      <div className="bg-slate-900 border border-yellow-500/30 rounded-xl p-6">
        <h3 className="text-sm font-semibold text-yellow-400 mb-3">🔒 Privacidade</h3>
        <div className="space-y-2 text-xs text-slate-300">
          {["✅ Ollama roda 100% local - zero dados na nuvem","✅ Banco SQLite armazenado no seu PC","✅ APIs online usadas apenas se configuradas","✅ Nenhum dado enviado automaticamente","✅ Chaves de API ficam apenas no .env local"].map(t=>(
            <p key={t}>{t}</p>
          ))}
        </div>
      </div>
    </div>
  )
}
'@

Write-Host "  ✓ 10 páginas criadas" -ForegroundColor Green

# ============================================================
# [7/8] PÁGINA PRINCIPAL
# ============================================================
Write-Host "`n[7/8] Criando página principal..." -ForegroundColor Yellow

New-FileWithContent "$ProjectRoot\frontend\src\app\page.tsx" @'
"use client"
import { useState, useEffect } from "react"
import { QueryClient, QueryClientProvider } from "@tanstack/react-query"
import { Toaster } from "react-hot-toast"
import { useAppStore } from "@/store/useAppStore"
import Sidebar from "@/components/layout/Sidebar"
import Header from "@/components/layout/Header"
import DashboardPage from "@/components/pages/DashboardPage"
import AgentsPage from "@/components/pages/AgentsPage"
import KanbanPage from "@/components/pages/KanbanPage"
import SEOPage from "@/components/pages/SEOPage"
import SocialPage from "@/components/pages/SocialPage"
import MapsPage from "@/components/pages/MapsPage"
import KnowledgePage from "@/components/pages/KnowledgePage"
import ReportsPage from "@/components/pages/ReportsPage"
import AutomationPage from "@/components/pages/AutomationPage"
import SettingsPage from "@/components/pages/SettingsPage"

const qc = new QueryClient({ defaultOptions: { queries: { staleTime: 30000, retry: 1 } } })

const pages: Record<string, React.ComponentType> = {
  dashboard: DashboardPage, agents: AgentsPage, kanban: KanbanPage,
  seo: SEOPage, social: SocialPage, maps: MapsPage,
  knowledge: KnowledgePage, reports: ReportsPage,
  automation: AutomationPage, settings: SettingsPage,
}

export default function App() {
  return (
    <QueryClientProvider client={qc}>
      <Inner/>
      <Toaster position="top-right" toastOptions={{
        duration: 4000,
        style: { background:"#1e293b", color:"#f1f5f9", border:"1px solid #334155" }
      }}/>
    </QueryClientProvider>
  )
}

function Inner() {
  const { currentPage, sidebarOpen } = useAppStore()
  const [mounted, setMounted] = useState(false)
  useEffect(() => { setMounted(true) }, [])
  if (!mounted) return null
  const Page = pages[currentPage] || DashboardPage
  return (
    <div className="flex h-screen overflow-hidden bg-slate-950 text-slate-50">
      <Sidebar/>
      <div className="flex-1 flex flex-col overflow-hidden" style={{ marginLeft: sidebarOpen ? 240 : 64, transition:"margin 0.3s" }}>
        <Header/>
        <main className="flex-1 overflow-auto p-6"><Page/></main>
      </div>
    </div>
  )
}
'@

Write-Host "  ✓ página principal" -ForegroundColor Green

# ============================================================
# [8/8] SCRIPTS FINAIS
# ============================================================
Write-Host "`n[8/8] Criando scripts de execução..." -ForegroundColor Yellow

New-FileWithContent "$ProjectRoot\setup.ps1" @'
# HC Tech AI System v2.1 - Setup Completo
param([switch]$SkipOllama)
$ErrorActionPreference = "Continue"
Clear-Host
Write-Host "╔══════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  HC TECH AI SYSTEM v2.1 - SETUP  ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════╝" -ForegroundColor Cyan

$root = Split-Path $MyInvocation.MyCommand.Path

# Python check
Write-Host "`n[1] Verificando Python..." -ForegroundColor Yellow
if (Get-Command python -ErrorAction SilentlyContinue) {
    $v = python --version 2>&1; Write-Host "  ✓ $v" -ForegroundColor Green
} else {
    Write-Host "  ✗ Python não encontrado!" -ForegroundColor Red
    Write-Host "  Baixe em: https://www.python.org/downloads/" -ForegroundColor Yellow
    exit 1
}

# Instalar dependências Python
Write-Host "`n[2] Instalando dependências Python..." -ForegroundColor Yellow
Set-Location "$root\backend"
python -m pip install -r requirements.txt --quiet
if ($LASTEXITCODE -eq 0) { Write-Host "  ✓ Dependências instaladas" -ForegroundColor Green }
else { Write-Host "  ⚠ Algumas dependências podem ter falhado" -ForegroundColor Yellow }

# Node.js check
Write-Host "`n[3] Verificando Node.js..." -ForegroundColor Yellow
if (Get-Command node -ErrorAction SilentlyContinue) {
    $v = node --version; Write-Host "  ✓ Node.js $v" -ForegroundColor Green
    Set-Location "$root\frontend"
    Write-Host "  Instalando dependências npm..." -ForegroundColor Yellow
    npm install --silent
    if ($LASTEXITCODE -eq 0) { Write-Host "  ✓ npm instalado" -ForegroundColor Green }
} else {
    Write-Host "  ✗ Node.js não encontrado!" -ForegroundColor Red
    Write-Host "  Baixe em: https://nodejs.org/" -ForegroundColor Yellow
}

# Ollama
if (-not $SkipOllama) {
    Write-Host "`n[4] Verificando Ollama..." -ForegroundColor Yellow
    if (Get-Command ollama -ErrorAction SilentlyContinue) {
        Write-Host "  ✓ Ollama instalado" -ForegroundColor Green
        Write-Host "  Baixando modelo Llama 3.2:3B (pode demorar ~2GB)..." -ForegroundColor Yellow
        ollama pull llama3.2:3b
    } else {
        Write-Host "  ⚠ Ollama não encontrado" -ForegroundColor Yellow
        Write-Host "  Baixe em: https://ollama.ai/download" -ForegroundColor Cyan
        Write-Host "  Após instalar, execute: ollama pull llama3.2:3b" -ForegroundColor Cyan
    }
}

Set-Location $root
Write-Host @"

╔══════════════════════════════════════════════════╗
║  ✅ SETUP CONCLUÍDO!                              ║
║                                                  ║
║  Próximos passos:                                ║
║  1. Configure o .env (opcional - OpenAI/Claude)  ║
║  2. Execute: .\iniciar.ps1                       ║
║  3. Acesse: http://localhost:3000                ║
╚══════════════════════════════════════════════════╝
"@ -ForegroundColor Green
'@

New-FileWithContent "$ProjectRoot\iniciar.ps1" @'
# HC Tech AI System v2.1 - Iniciar Sistema
param([switch]$DevMode)
$ErrorActionPreference = "Continue"

function Test-Port($port) {
    try { $t=New-Object System.Net.Sockets.TcpClient; $t.Connect("localhost",$port); $t.Close(); return $true } catch { return $false }
}

Clear-Host
Write-Host "╔═════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  HC TECH AI SYSTEM v2.1 - INICIAR   ║" -ForegroundColor Cyan
Write-Host "╚═════════════════════════════════════╝" -ForegroundColor Cyan

$root = Split-Path $MyInvocation.MyCommand.Path

# Carregar .env
$env_file = Join-Path $root ".env"
if (Test-Path $env_file) {
    Get-Content $env_file | ForEach-Object {
        if ($_ -match "^([^#][^=]*)=(.*)$") {
            [System.Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim(), "Process")
        }
    }
    Write-Host "`n✓ .env carregado" -ForegroundColor Green
}

# Ollama
Write-Host "`n[1] Ollama (IA Local)..." -ForegroundColor Yellow
if (-not (Test-Port 11434)) {
    if (Get-Command ollama -ErrorAction SilentlyContinue) {
        Start-Process "ollama" "serve" -WindowStyle Minimized
        Start-Sleep 3
        if (Test-Port 11434) { Write-Host "  ✓ Ollama iniciado" -ForegroundColor Green }
        else { Write-Host "  ⚠ Ollama demorando para iniciar" -ForegroundColor Yellow }
    } else { Write-Host "  ⚠ Ollama não instalado (IA local indisponível)" -ForegroundColor Yellow }
} else { Write-Host "  ✓ Ollama já rodando" -ForegroundColor Green }

# Backend
Write-Host "`n[2] Backend Python (FastAPI)..." -ForegroundColor Yellow
$backendPort = if($env:BACKEND_PORT){$env:BACKEND_PORT}else{"8000"}
if (-not (Test-Port $backendPort)) {
    $backendPath = Join-Path $root "backend"
    $cmd = if($DevMode){"python -m uvicorn app.main:app --host 0.0.0.0 --port $backendPort --reload"}else{"python -m uvicorn app.main:app --host 0.0.0.0 --port $backendPort"}
    Start-Process "powershell" "-NoExit -Command `"Set-Location '$backendPath'; $cmd`"" -WindowStyle Normal
    Write-Host "  Aguardando backend..." -NoNewline -ForegroundColor Yellow
    $i=0; while(-not (Test-Port $backendPort) -and $i -lt 20){ Start-Sleep 1; $i++; Write-Host "." -NoNewline -ForegroundColor Yellow }
    if (Test-Port $backendPort) { Write-Host " ✓" -ForegroundColor Green } else { Write-Host " timeout" -ForegroundColor Red }
} else { Write-Host "  ✓ Backend já rodando" -ForegroundColor Green }

# Frontend
Write-Host "`n[3] Frontend Next.js..." -ForegroundColor Yellow
$frontPort = if($env:FRONTEND_PORT){$env:FRONTEND_PORT}else{"3000"}
if (-not (Test-Port $frontPort)) {
    $frontPath = Join-Path $root "frontend"
    $npmCmd = if($DevMode){"npm run dev"}else{"npm run dev"}
    Start-Process "powershell" "-NoExit -Command `"Set-Location '$frontPath'; $npmCmd`"" -WindowStyle Normal
    Write-Host "  Aguardando frontend..." -NoNewline -ForegroundColor Yellow
    $i=0; while(-not (Test-Port $frontPort) -and $i -lt 40){ Start-Sleep 1; $i++; Write-Host "." -NoNewline -ForegroundColor Yellow }
    if (Test-Port $frontPort) { Write-Host " ✓" -ForegroundColor Green } else { Write-Host " aguardando..." -ForegroundColor Yellow }
} else { Write-Host "  ✓ Frontend já rodando" -ForegroundColor Green }

Start-Sleep 2

Write-Host @"

╔══════════════════════════════════════════════════╗
║  ✅ HC TECH AI SYSTEM v2.1 INICIADO!             ║
╠══════════════════════════════════════════════════╣
║  🌐 Interface:   http://localhost:3000            ║
║  🔧 API:         http://localhost:8000            ║
║  📚 API Docs:    http://localhost:8000/docs       ║
║  🦙 Ollama:      http://localhost:11434           ║
║                                                  ║
║  IA Padrão: Ollama Local (Llama 3.2:3B)          ║
║  Troque a IA pelo painel no header!              ║
╚══════════════════════════════════════════════════╝
"@ -ForegroundColor Green

Start-Sleep 2
Start-Process "http://localhost:3000"
'@

Write-Host "  ✓ setup.ps1 e iniciar.ps1" -ForegroundColor Green

# ============================================================
# RESUMO FINAL
# ============================================================
Write-Host @"

╔══════════════════════════════════════════════════════════╗
║         ✅ BOOTSTRAP CONCLUÍDO COM SUCESSO!              ║
╠══════════════════════════════════════════════════════════╣
║                                                          ║
║  📁 Arquivos criados:                                    ║
║     ✓ .env (configuração)                               ║
║     ✓ backend/ (11 módulos Python/FastAPI)               ║
║     ✓ frontend/ (Next.js + React + Tailwind)             ║
║     ✓ setup.ps1 (instalação)                            ║
║     ✓ iniciar.ps1 (inicialização)                       ║
║                                                          ║
║  🚀 PRÓXIMOS PASSOS:                                     ║
║                                                          ║
║  1. Instalar dependências:                               ║
║     .\setup.ps1                                         ║
║                                                          ║
║  2. Iniciar o sistema:                                   ║
║     .\iniciar.ps1                                       ║
║                                                          ║
║  3. Acessar:                                             ║
║     http://localhost:3000                               ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan