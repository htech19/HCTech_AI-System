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