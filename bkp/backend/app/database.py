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