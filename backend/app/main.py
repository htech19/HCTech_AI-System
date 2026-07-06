"""HC Tech AI System v2.1 - Backend Principal FastAPI"""
import os
import sys
from contextlib import asynccontextmanager
from pathlib import Path

# Garantir que o root esta no path para achar .env
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
from app.api.integrations import router as integrations_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Ciclo de vida da aplicacao"""
    logger.info("=" * 50)
    logger.info("  HC Tech AI System v2.1 iniciando...")
    logger.info("=" * 50)

    # Inicializar banco
    await init_db()

    # Verificar Ollama
    from app.services.ai_service import ai_service
    ollama_ok = await ai_service.check_ollama()
    if ollama_ok:
        models = await ai_service.get_ollama_models()
        logger.info(f"Ollama online - Modelos: {models}")
    else:
        logger.warning("Ollama offline - Inicie com: ollama serve")

    logger.info("Sistema pronto! Docs: http://localhost:8000/docs")
    yield

    logger.info("Encerrando HC Tech AI System...")


# Criar app
app = FastAPI(
    title="HC Tech AI System v2.1",
    description="Plataforma Hibrida Local/Online de IA para Assistencias Tecnicas",
    version="2.1.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)

# CORS - permitir frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",
        "http://localhost:3001",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:3001",
        "*",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Compressao gzip
app.add_middleware(GZipMiddleware, minimum_size=1000)


# Middleware de logging
@app.middleware("http")
async def log_requests(request: Request, call_next):
    import time
    start = time.time()
    response = await call_next(request)
    duration = time.time() - start
    if "/health" not in str(request.url):
        logger.debug(
            f"{request.method} {request.url.path} "
            f"-> {response.status_code} ({duration:.3f}s)"
        )
    return response


# Handler de erros global
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error(f"Erro nao tratado em {request.url.path}: {exc}")
    return JSONResponse(
        status_code=500,
        content={"error": "Erro interno", "detail": str(exc)},
    )


# Registrar routers
app.include_router(auth_router,       prefix="/api/auth",       tags=["Auth"])
app.include_router(ai_router,         prefix="/api/ai",         tags=["IA"])
app.include_router(agents_router,     prefix="/api/agents",     tags=["Agentes"])
app.include_router(tasks_router,      prefix="/api/tasks",      tags=["Tarefas"])
app.include_router(seo_router,        prefix="/api/seo",        tags=["SEO"])
app.include_router(social_router,     prefix="/api/social",     tags=["Social"])
app.include_router(maps_router,       prefix="/api/maps",       tags=["Maps"])
app.include_router(knowledge_router,  prefix="/api/knowledge",  tags=["Knowledge"])
app.include_router(reports_router,    prefix="/api/reports",    tags=["Reports"])
app.include_router(metrics_router,    prefix="/api/metrics",    tags=["Metrics"])
app.include_router(automation_router, prefix="/api/automation", tags=["Automation"])
app.include_router(integrations_router, prefix="/api/integrations", tags=["Integrations"])


@app.get("/api/health")
async def health_check():
    """Health check do sistema"""
    from app.services.ai_service import ai_service
    ollama_ok = await ai_service.check_ollama()
    models = await ai_service.get_ollama_models() if ollama_ok else []

    return {
        "status": "online",
        "version": "2.1.0",
        "system": "HC Tech AI System",
        "ai": {
            "ollama": ollama_ok,
            "ollama_model": os.getenv("OLLAMA_MODEL", "llama3.2:3b"),
            "ollama_models": models,
            "openai": bool(os.getenv("OPENAI_API_KEY", "")),
            "anthropic": bool(os.getenv("ANTHROPIC_API_KEY", "")),
            "default_provider": os.getenv("DEFAULT_AI_PROVIDER", "ollama"),
        },
    }


@app.get("/")
async def root():
    return {
        "message": "HC Tech AI System v2.1",
        "docs": "/docs",
        "health": "/api/health",
        "status": "online",
    }
