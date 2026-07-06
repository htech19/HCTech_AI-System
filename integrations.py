"""
API de Integrações - Facebook, Google, Instagram, Mercado Livre
HC Tech AI System v2.1
"""

import os
import json
import httpx
import asyncio
from datetime import datetime, timedelta
from typing import Optional
from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import RedirectResponse, HTMLResponse
from sqlalchemy import select
from pydantic import BaseModel
from loguru import logger

from app.database import AsyncSessionLocal, Base
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy import String, Text, Boolean, DateTime, Integer, JSON

router = APIRouter()

# ============================================================
# MODELOS DE BANCO - Integrações
# ============================================================

from app.database import engine, Base

class Integration(Base):
    __tablename__ = "integrations"
    
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    platform: Mapped[str] = mapped_column(String(50), unique=True)
    name: Mapped[str] = mapped_column(String(100))
    status: Mapped[str] = mapped_column(String(20), default="disconnected")
    access_token: Mapped[str] = mapped_column(Text, nullable=True)
    refresh_token: Mapped[str] = mapped_column(Text, nullable=True)
    token_expires_at: Mapped[datetime] = mapped_column(DateTime, nullable=True)
    account_id: Mapped[str] = mapped_column(String(200), nullable=True)
    account_name: Mapped[str] = mapped_column(String(200), nullable=True)
    account_email: Mapped[str] = mapped_column(String(200), nullable=True)
    avatar_url: Mapped[str] = mapped_column(String(500), nullable=True)
    permissions: Mapped[list] = mapped_column(JSON, default=list)
    metadata_: Mapped[dict] = mapped_column(JSON, default=dict, name="metadata")
    connected_at: Mapped[datetime] = mapped_column(DateTime, nullable=True)
    last_sync: Mapped[datetime] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class IntegrationLog(Base):
    __tablename__ = "integration_logs"
    
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    platform: Mapped[str] = mapped_column(String(50))
    action: Mapped[str] = mapped_column(String(100))
    status: Mapped[str] = mapped_column(String(20))
    message: Mapped[str] = mapped_column(Text, nullable=True)
    data: Mapped[dict] = mapped_column(JSON, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


# ============================================================
# CONFIGURAÇÕES OAuth (lidas do .env)
# ============================================================

def get_oauth_config():
    return {
        "facebook": {
            "app_id": os.getenv("FACEBOOK_APP_ID", ""),
            "app_secret": os.getenv("FACEBOOK_APP_SECRET", ""),
            "scope": "pages_show_list,pages_read_engagement,pages_manage_posts,instagram_basic,instagram_content_publish,pages_manage_metadata",
            "auth_url": "https://www.facebook.com/v18.0/dialog/oauth",
            "token_url": "https://graph.facebook.com/v18.0/oauth/access_token",
            "api_base": "https://graph.facebook.com/v18.0",
        },
        "google": {
            "client_id": os.getenv("GOOGLE_CLIENT_ID", ""),
            "client_secret": os.getenv("GOOGLE_CLIENT_SECRET", ""),
            "scope": "https://www.googleapis.com/auth/business.manage https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/userinfo.profile",
            "auth_url": "https://accounts.google.com/o/oauth2/v2/auth",
            "token_url": "https://oauth2.googleapis.com/token",
            "api_base": "https://mybusinessaccountmanagement.googleapis.com/v1",
        },
        "mercadolivre": {
            "client_id": os.getenv("ML_CLIENT_ID", ""),
            "client_secret": os.getenv("ML_CLIENT_SECRET", ""),
            "scope": "read write offline_access",
            "auth_url": "https://auth.mercadolivre.com.br/authorization",
            "token_url": "https://api.mercadolibre.com/oauth/token",
            "api_base": "https://api.mercadolibre.com",
        },
    }


REDIRECT_BASE = os.getenv("OAUTH_REDIRECT_BASE", "http://localhost:8000")


# ============================================================
# HELPERS
# ============================================================

async def get_integration(platform: str) -> Optional[Integration]:
    async with AsyncSessionLocal() as s:
        r = await s.execute(
            select(Integration).where(Integration.platform == platform)
        )
        return r.scalar_one_or_none()


async def save_integration(platform: str, data: dict):
    async with AsyncSessionLocal() as s:
        r = await s.execute(
            select(Integration).where(Integration.platform == platform)
        )
        integ = r.scalar_one_or_none()
        
        if not integ:
            integ = Integration(platform=platform, name=data.get("name", platform))
            s.add(integ)
        
        for key, value in data.items():
            if hasattr(integ, key):
                setattr(integ, key, value)
            elif key == "metadata":
                integ.metadata_ = value
        
        integ.updated_at = datetime.utcnow()
        await s.commit()


async def log_action(platform: str, action: str, status: str, message: str = "", data: dict = {}):
    async with AsyncSessionLocal() as s:
        s.add(IntegrationLog(
            platform=platform,
            action=action,
            status=status,
            message=message,
            data=data,
        ))
        await s.commit()


async def init_integrations_db():
    """Criar tabelas de integração"""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    
    # Criar registros padrão para cada plataforma
    platforms = [
        {"platform": "facebook", "name": "Facebook & Instagram"},
        {"platform": "google", "name": "Google Meu Negócio"},
        {"platform": "instagram", "name": "Instagram Business"},
        {"platform": "mercadolivre", "name": "Mercado Livre"},
        {"platform": "maps", "name": "Google Maps"},
    ]
    
    async with AsyncSessionLocal() as s:
        for p in platforms:
            r = await s.execute(
                select(Integration).where(Integration.platform == p["platform"])
            )
            if not r.scalar_one_or_none():
                s.add(Integration(**p))
        await s.commit()


# ============================================================
# ENDPOINTS - Status e Listagem
# ============================================================

@router.get("")
async def list_integrations():
    """Listar todas as integrações com status"""
    await init_integrations_db()
    
    async with AsyncSessionLocal() as s:
        r = await s.execute(select(Integration).order_by(Integration.id))
        integrations = r.scalars().all()
    
    result = []
    for integ in integrations:
        result.append({
            "id": integ.id,
            "platform": integ.platform,
            "name": integ.name,
            "status": integ.status,
            "account_name": integ.account_name,
            "account_email": integ.account_email,
            "avatar_url": integ.avatar_url,
            "permissions": integ.permissions or [],
            "connected_at": integ.connected_at.isoformat() if integ.connected_at else None,
            "last_sync": integ.last_sync.isoformat() if integ.last_sync else None,
            "token_valid": _is_token_valid(integ),
            "metadata": integ.metadata_ or {},
        })
    
    return result


def _is_token_valid(integ: Integration) -> bool:
    if not integ.access_token:
        return False
    if integ.token_expires_at and integ.token_expires_at < datetime.utcnow():
        return False
    return True


@router.get("/{platform}/status")
async def get_platform_status(platform: str):
    """Status detalhado de uma plataforma"""
    integ = await get_integration(platform)
    if not integ:
        return {"platform": platform, "status": "disconnected", "connected": False}
    
    return {
        "platform": platform,
        "status": integ.status,
        "connected": integ.status == "connected",
        "account_name": integ.account_name,
        "token_valid": _is_token_valid(integ),
        "last_sync": integ.last_sync.isoformat() if integ.last_sync else None,
    }


# ============================================================
# ENDPOINTS - Configuração Manual de Tokens
# ============================================================

class TokenConfig(BaseModel):
    access_token: str
    account_id: Optional[str] = None
    account_name: Optional[str] = None
    page_id: Optional[str] = None
    page_name: Optional[str] = None


@router.post("/{platform}/configure")
async def configure_token(platform: str, config: TokenConfig):
    """Configurar token manualmente (sem OAuth)"""
    
    validators = {
        "facebook": _validate_facebook_token,
        "instagram": _validate_instagram_token,
        "google": _validate_google_token,
        "mercadolivre": _validate_ml_token,
        "maps": _validate_google_token,
    }
    
    validator = validators.get(platform)
    if not validator:
        raise HTTPException(400, f"Plataforma '{platform}' não suportada")
    
    # Validar token
    result = await validator(config.access_token)
    
    if not result.get("valid"):
        raise HTTPException(400, f"Token inválido: {result.get('error', 'Erro desconhecido')}")
    
    # Salvar integração
    await save_integration(platform, {
        "status": "connected",
        "access_token": config.access_token,
        "account_id": config.account_id or result.get("account_id"),
        "account_name": config.account_name or result.get("account_name"),
        "account_email": result.get("email"),
        "avatar_url": result.get("avatar_url"),
        "permissions": result.get("permissions", []),
        "connected_at": datetime.utcnow(),
        "last_sync": datetime.utcnow(),
        "metadata": result.get("metadata", {}),
    })
    
    await log_action(platform, "configure", "success", f"Token configurado para {result.get('account_name')}")
    
    return {
        "success": True,
        "platform": platform,
        "account_name": result.get("account_name"),
        "message": f"✅ {platform.title()} conectado com sucesso!",
    }


@router.delete("/{platform}/disconnect")
async def disconnect_platform(platform: str):
    """Desconectar plataforma"""
    await save_integration(platform, {
        "status": "disconnected",
        "access_token": None,
        "refresh_token": None,
        "account_id": None,
        "account_name": None,
        "account_email": None,
        "token_expires_at": None,
    })
    
    await log_action(platform, "disconnect", "success", "Plataforma desconectada")
    
    return {"success": True, "message": f"{platform.title()} desconectado"}


# ============================================================
# ENDPOINTS - OAuth URLs
# ============================================================

@router.get("/{platform}/oauth-url")
async def get_oauth_url(platform: str):
    """Gerar URL de autorização OAuth"""
    config = get_oauth_config()
    
    if platform not in config:
        raise HTTPException(400, f"OAuth não configurado para '{platform}'")
    
    cfg = config[platform]
    
    # Verificar credenciais configuradas
    key = "app_id" if platform == "facebook" else "client_id"
    if not cfg.get(key):
        raise HTTPException(400, {
            "error": "credentials_missing",
            "message": f"Configure {key.upper()} no arquivo .env",
            "env_vars": _get_required_env_vars(platform),
        })
    
    redirect_uri = f"{REDIRECT_BASE}/api/integrations/{platform}/callback"
    
    if platform == "facebook":
        url = (
            f"{cfg['auth_url']}"
            f"?client_id={cfg['app_id']}"
            f"&redirect_uri={redirect_uri}"
            f"&scope={cfg['scope']}"
            f"&response_type=code"
            f"&state=hctech_{platform}"
        )
    elif platform == "google" or platform == "maps":
        url = (
            f"{cfg['auth_url']}"
            f"?client_id={cfg['client_id']}"
            f"&redirect_uri={redirect_uri}"
            f"&scope={cfg['scope']}"
            f"&response_type=code"
            f"&access_type=offline"
            f"&prompt=consent"
            f"&state=hctech_{platform}"
        )
    elif platform == "mercadolivre":
        url = (
            f"{cfg['auth_url']}"
            f"?client_id={cfg['client_id']}"
            f"&redirect_uri={redirect_uri}"
            f"&response_type=code"
        )
    else:
        raise HTTPException(400, "Plataforma não suportada")
    
    return {"oauth_url": url, "platform": platform}


def _get_required_env_vars(platform: str) -> list:
    vars_map = {
        "facebook": ["FACEBOOK_APP_ID", "FACEBOOK_APP_SECRET"],
        "google": ["GOOGLE_CLIENT_ID", "GOOGLE_CLIENT_SECRET"],
        "maps": ["GOOGLE_CLIENT_ID", "GOOGLE_CLIENT_SECRET"],
        "mercadolivre": ["ML_CLIENT_ID", "ML_CLIENT_SECRET"],
    }
    return vars_map.get(platform, [])


# ============================================================
# ENDPOINTS - OAuth Callbacks
# ============================================================

@router.get("/{platform}/callback")
async def oauth_callback(platform: str, request: Request):
    """Receber callback OAuth e trocar code por token"""
    code = request.query_params.get("code")
    error = request.query_params.get("error")
    
    if error:
        html = _callback_html("error", platform, f"Erro de autorização: {error}")
        return HTMLResponse(html)
    
    if not code:
        html = _callback_html("error", platform, "Código de autorização não recebido")
        return HTMLResponse(html)
    
    try:
        config = get_oauth_config()
        cfg = config.get(platform, config.get("google"))
        redirect_uri = f"{REDIRECT_BASE}/api/integrations/{platform}/callback"
        
        # Trocar code por token
        if platform == "facebook":
            token_data = await _facebook_exchange_token(cfg, code, redirect_uri)
        elif platform in ["google", "maps"]:
            token_data = await _google_exchange_token(cfg, code, redirect_uri)
        elif platform == "mercadolivre":
            token_data = await _ml_exchange_token(cfg, code, redirect_uri)
        else:
            raise ValueError(f"Plataforma não suportada: {platform}")
        
        # Salvar
        await save_integration(platform, {
            **token_data,
            "status": "connected",
            "connected_at": datetime.utcnow(),
            "last_sync": datetime.utcnow(),
        })
        
        await log_action(platform, "oauth_connect", "success", 
                        f"Conectado via OAuth: {token_data.get('account_name')}")
        
        html = _callback_html("success", platform, token_data.get("account_name", "Conta conectada"))
        return HTMLResponse(html)
        
    except Exception as e:
        logger.error(f"OAuth callback error ({platform}): {e}")
        await log_action(platform, "oauth_connect", "error", str(e))
        html = _callback_html("error", platform, str(e))
        return HTMLResponse(html)


def _callback_html(status: str, platform: str, message: str) -> str:
    """HTML de retorno do OAuth"""
    if status == "success":
        icon, color, title = "✅", "#22c55e", "Conectado com Sucesso!"
    else:
        icon, color, title = "❌", "#ef4444", "Erro na Conexão"
    
    return f"""
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <title>HC Tech AI - {title}</title>
    <style>
        * {{ margin: 0; padding: 0; box-sizing: border-box; }}
        body {{
            font-family: -apple-system, sans-serif;
            background: #0f172a;
            color: #f1f5f9;
            display: flex;
            align-items: center;
            justify-content: center;
            min-height: 100vh;
        }}
        .card {{
            background: #1e293b;
            border: 1px solid #334155;
            border-radius: 16px;
            padding: 40px;
            text-align: center;
            max-width: 400px;
            width: 90%;
        }}
        .icon {{ font-size: 60px; margin-bottom: 16px; }}
        h1 {{ font-size: 20px; color: {color}; margin-bottom: 8px; }}
        p {{ color: #94a3b8; font-size: 14px; margin-bottom: 24px; }}
        .platform {{ color: #60a5fa; font-weight: bold; text-transform: capitalize; }}
        .btn {{
            background: {color};
            color: white;
            border: none;
            padding: 12px 24px;
            border-radius: 8px;
            font-size: 14px;
            cursor: pointer;
            font-weight: 600;
        }}
        .btn:hover {{ opacity: 0.9; }}
    </style>
</head>
<body>
    <div class="card">
        <div class="icon">{icon}</div>
        <h1>{title}</h1>
        <p>
            <span class="platform">{platform}</span><br>
            {message}
        </p>
        <button class="btn" onclick="window.close(); window.opener && window.opener.postMessage({{type:'{status}', platform:'{platform}'}}, '*')">
            Fechar e Continuar
        </button>
    </div>
    <script>
        // Notificar janela pai e fechar
        setTimeout(() => {{
            if (window.opener) {{
                window.opener.postMessage(
                    {{type: '{status}', platform: '{platform}', message: '{message}'}},
                    '*'
                );
            }}
            window.close();
        }}, 2000);
    </script>
</body>
</html>
"""


# ============================================================
# VALIDADORES DE TOKEN
# ============================================================

async def _validate_facebook_token(token: str) -> dict:
    """Validar token do Facebook/Instagram"""
    try:
        async with httpx.AsyncClient(timeout=10.0) as c:
            # Buscar info do usuário/página
            r = await c.get(
                "https://graph.facebook.com/me",
                params={
                    "access_token": token,
                    "fields": "id,name,email,picture",
                }
            )
            
            if r.status_code != 200:
                return {"valid": False, "error": r.json().get("error", {}).get("message", "Token inválido")}
            
            data = r.json()
            
            # Buscar páginas
            pages_r = await c.get(
                "https://graph.facebook.com/me/accounts",
                params={"access_token": token, "fields": "id,name,category,access_token"}
            )
            pages = pages_r.json().get("data", []) if pages_r.status_code == 200 else []
            
            return {
                "valid": True,
                "account_id": data.get("id"),
                "account_name": data.get("name"),
                "email": data.get("email"),
                "avatar_url": data.get("picture", {}).get("data", {}).get("url") if isinstance(data.get("picture"), dict) else None,
                "permissions": ["pages_show_list", "pages_read_engagement"],
                "metadata": {
                    "pages": [{"id": p["id"], "name": p["name"]} for p in pages[:5]],
                    "pages_count": len(pages),
                },
            }
    except Exception as e:
        return {"valid": False, "error": str(e)}


async def _validate_instagram_token(token: str) -> dict:
    """Validar token do Instagram Business"""
    return await _validate_facebook_token(token)  # Usa Graph API do Facebook


async def _validate_google_token(token: str) -> dict:
    """Validar token do Google"""
    try:
        async with httpx.AsyncClient(timeout=10.0) as c:
            r = await c.get(
                "https://www.googleapis.com/oauth2/v3/userinfo",
                headers={"Authorization": f"Bearer {token}"}
            )
            
            if r.status_code != 200:
                return {"valid": False, "error": "Token Google inválido"}
            
            data = r.json()
            
            return {
                "valid": True,
                "account_id": data.get("sub"),
                "account_name": data.get("name"),
                "email": data.get("email"),
                "avatar_url": data.get("picture"),
                "permissions": ["business.manage"],
                "metadata": {"locale": data.get("locale", "pt-BR")},
            }
    except Exception as e:
        return {"valid": False, "error": str(e)}


async def _validate_ml_token(token: str) -> dict:
    """Validar token do Mercado Livre"""
    try:
        async with httpx.AsyncClient(timeout=10.0) as c:
            r = await c.get(
                "https://api.mercadolibre.com/users/me",
                headers={"Authorization": f"Bearer {token}"}
            )
            
            if r.status_code != 200:
                return {"valid": False, "error": "Token Mercado Livre inválido"}
            
            data = r.json()
            
            return {
                "valid": True,
                "account_id": str(data.get("id")),
                "account_name": data.get("nickname") or data.get("first_name"),
                "email": data.get("email"),
                "avatar_url": data.get("thumbnail", {}).get("picture_url") if isinstance(data.get("thumbnail"), dict) else None,
                "permissions": ["read", "write"],
                "metadata": {
                    "site_id": data.get("site_id"),
                    "country": data.get("country_id"),
                    "seller_level": data.get("seller_reputation", {}).get("level_id") if data.get("seller_reputation") else None,
                },
            }
    except Exception as e:
        return {"valid": False, "error": str(e)}


# ============================================================
# TROCAS DE TOKEN OAuth
# ============================================================

async def _facebook_exchange_token(cfg: dict, code: str, redirect_uri: str) -> dict:
    async with httpx.AsyncClient(timeout=15.0) as c:
        r = await c.get(cfg["token_url"], params={
            "client_id": cfg["app_id"],
            "client_secret": cfg["app_secret"],
            "redirect_uri": redirect_uri,
            "code": code,
        })
        r.raise_for_status()
        token_data = r.json()
        access_token = token_data["access_token"]
        
        # Buscar info do usuário
        user_r = await c.get(
            "https://graph.facebook.com/me",
            params={"access_token": access_token, "fields": "id,name,email,picture"},
        )
        user = user_r.json()
        
        return {
            "access_token": access_token,
            "account_id": user.get("id"),
            "account_name": user.get("name"),
            "account_email": user.get("email"),
            "avatar_url": user.get("picture", {}).get("data", {}).get("url") if isinstance(user.get("picture"), dict) else None,
            "permissions": cfg["scope"].split(","),
        }


async def _google_exchange_token(cfg: dict, code: str, redirect_uri: str) -> dict:
    async with httpx.AsyncClient(timeout=15.0) as c:
        r = await c.post(cfg["token_url"], data={
            "client_id": cfg["client_id"],
            "client_secret": cfg["client_secret"],
            "redirect_uri": redirect_uri,
            "code": code,
            "grant_type": "authorization_code",
        })
        r.raise_for_status()
        token_data = r.json()
        
        access_token = token_data["access_token"]
        expires_in = token_data.get("expires_in", 3600)
        
        # Buscar perfil
        user_r = await c.get(
            "https://www.googleapis.com/oauth2/v3/userinfo",
            headers={"Authorization": f"Bearer {access_token}"},
        )
        user = user_r.json()
        
        return {
            "access_token": access_token,
            "refresh_token": token_data.get("refresh_token"),
            "token_expires_at": datetime.utcnow() + timedelta(seconds=expires_in),
            "account_id": user.get("sub"),
            "account_name": user.get("name"),
            "account_email": user.get("email"),
            "avatar_url": user.get("picture"),
            "permissions": cfg["scope"].split(),
        }


async def _ml_exchange_token(cfg: dict, code: str, redirect_uri: str) -> dict:
    async with httpx.AsyncClient(timeout=15.0) as c:
        r = await c.post(cfg["token_url"], data={
            "grant_type": "authorization_code",
            "client_id": cfg["client_id"],
            "client_secret": cfg["client_secret"],
            "code": code,
            "redirect_uri": redirect_uri,
        })
        r.raise_for_status()
        token_data = r.json()
        
        access_token = token_data["access_token"]
        
        # Buscar perfil
        user_r = await c.get(
            "https://api.mercadolibre.com/users/me",
            headers={"Authorization": f"Bearer {access_token}"},
        )
        user = user_r.json()
        
        expires_in = token_data.get("expires_in", 21600)
        
        return {
            "access_token": access_token,
            "refresh_token": token_data.get("refresh_token"),
            "token_expires_at": datetime.utcnow() + timedelta(seconds=expires_in),
            "account_id": str(user.get("id")),
            "account_name": user.get("nickname"),
            "account_email": user.get("email"),
            "permissions": ["read", "write"],
            "metadata": {"site_id": user.get("site_id")},
        }


# ============================================================
# ENDPOINTS - Dados das Plataformas
# ============================================================

@router.get("/facebook/data")
async def get_facebook_data():
    """Buscar dados reais do Facebook"""
    integ = await get_integration("facebook")
    
    if not integ or not integ.access_token:
        raise HTTPException(400, "Facebook não conectado")
    
    try:
        async with httpx.AsyncClient(timeout=15.0) as c:
            # Buscar páginas
            pages_r = await c.get(
                "https://graph.facebook.com/me/accounts",
                params={
                    "access_token": integ.access_token,
                    "fields": "id,name,fan_count,followers_count,category",
                }
            )
            
            pages = pages_r.json().get("data", []) if pages_r.status_code == 200 else []
            
            result = {
                "account_name": integ.account_name,
                "pages": pages,
                "total_followers": sum(p.get("fan_count", 0) for p in pages),
            }
            
            # Atualizar last_sync
            await save_integration("facebook", {"last_sync": datetime.utcnow()})
            
            return result
            
    except Exception as e:
        logger.error(f"Facebook data error: {e}")
        raise HTTPException(500, str(e))


@router.get("/google/locations")
async def get_google_locations():
    """Buscar localizações do Google Meu Negócio"""
    integ = await get_integration("google")
    
    if not integ or not integ.access_token:
        raise HTTPException(400, "Google não conectado")
    
    try:
        async with httpx.AsyncClient(timeout=15.0) as c:
            # Buscar contas de negócio
            accounts_r = await c.get(
                "https://mybusinessaccountmanagement.googleapis.com/v1/accounts",
                headers={"Authorization": f"Bearer {integ.access_token}"},
            )
            
            if accounts_r.status_code == 401:
                await save_integration("google", {"status": "token_expired"})
                raise HTTPException(401, "Token expirado, reconecte")
            
            accounts = accounts_r.json().get("accounts", [])
            
            all_locations = []
            for account in accounts[:3]:
                account_name = account.get("name")
                locs_r = await c.get(
                    f"https://mybusinessbusinessinformation.googleapis.com/v1/{account_name}/locations",
                    headers={"Authorization": f"Bearer {integ.access_token}"},
                    params={"readMask": "name,title,phoneNumbers,storefrontAddress"},
                )
                
                if locs_r.status_code == 200:
                    locs = locs_r.json().get("locations", [])
                    all_locations.extend(locs)
            
            await save_integration("google", {"last_sync": datetime.utcnow()})
            
            return {
                "accounts": accounts,
                "locations": all_locations,
                "total": len(all_locations),
            }
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Google locations error: {e}")
        raise HTTPException(500, str(e))


@router.get("/mercadolivre/data")
async def get_ml_data():
    """Buscar dados do Mercado Livre"""
    integ = await get_integration("mercadolivre")
    
    if not integ or not integ.access_token:
        raise HTTPException(400, "Mercado Livre não conectado")
    
    try:
        async with httpx.AsyncClient(timeout=15.0) as c:
            user_id = integ.account_id
            
            # Anúncios ativos
            items_r = await c.get(
                f"https://api.mercadolibre.com/users/{user_id}/items/search",
                headers={"Authorization": f"Bearer {integ.access_token}"},
                params={"status": "active", "limit": 10},
            )
            
            items_data = items_r.json() if items_r.status_code == 200 else {}
            
            # Reputação do vendedor
            rep_r = await c.get(
                f"https://api.mercadolibre.com/users/{user_id}",
                headers={"Authorization": f"Bearer {integ.access_token}"},
            )
            rep_data = rep_r.json() if rep_r.status_code == 200 else {}
            
            await save_integration("mercadolivre", {"last_sync": datetime.utcnow()})
            
            return {
                "account_name": integ.account_name,
                "active_items": items_data.get("paging", {}).get("total", 0),
                "items": items_data.get("results", [])[:5],
                "reputation": rep_data.get("seller_reputation", {}),
                "metrics": rep_data.get("status", {}),
            }
            
    except Exception as e:
        logger.error(f"ML data error: {e}")
        raise HTTPException(500, str(e))


@router.get("/logs")
async def get_integration_logs(limit: int = 20):
    """Histórico de ações das integrações"""
    async with AsyncSessionLocal() as s:
        from sqlalchemy import desc
        r = await s.execute(
            select(IntegrationLog)
            .order_by(desc(IntegrationLog.created_at))
            .limit(limit)
        )
        logs = r.scalars().all()
    
    return [
        {
            "platform": l.platform,
            "action": l.action,
            "status": l.status,
            "message": l.message,
            "created_at": l.created_at.isoformat(),
        }
        for l in logs
    ]


@router.post("/{platform}/sync")
async def sync_platform(platform: str):
    """Forçar sincronização de uma plataforma"""
    integ = await get_integration(platform)
    
    if not integ or integ.status != "connected":
        raise HTTPException(400, f"{platform} não está conectado")
    
    await save_integration(platform, {"last_sync": datetime.utcnow()})
    await log_action(platform, "sync", "success", "Sincronização manual")
    
    return {"success": True, "message": f"{platform} sincronizado", "synced_at": datetime.utcnow().isoformat()}