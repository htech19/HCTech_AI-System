#!/usr/bin/env python3
"""
HC Tech AI System v2.1
Automacao completa para adicionar modulo de Integracoes
"""

import os
import re
import sys
import json
import shutil
from pathlib import Path
from datetime import datetime

# ============================================================
# CONFIGURACAO
# ============================================================

ROOT = Path(__file__).parent
BACKEND = ROOT / "backend"
FRONTEND = ROOT / "frontend"
SRC = FRONTEND / "src"

# Cores ANSI
G = "\033[92m"   # Verde
Y = "\033[93m"   # Amarelo
R = "\033[91m"   # Vermelho
C = "\033[96m"   # Ciano
B = "\033[1m"    # Bold
DIM = "\033[2m"  # Dim
E = "\033[0m"    # Reset


def ok(msg):    print(f"  {G}✓{E} {msg}")
def warn(msg):  print(f"  {Y}⚠{E} {msg}")
def erro(msg):  print(f"  {R}✗{E} {msg}")
def info(msg):  print(f"  {C}→{E} {msg}")
def step(n, msg): print(f"\n{C}{B}[{n}]{E} {B}{msg}{E}")


def backup_file(path: Path) -> Path:
    """Criar backup antes de modificar"""
    if path.exists():
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        bak = path.with_suffix(f".bak_{ts}")
        shutil.copy2(path, bak)
        return bak
    return None


def write_clean(path: Path, content: str):
    """Escrever arquivo sem BOM"""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(content.encode("utf-8"))


def read_file(path: Path) -> str:
    """Ler arquivo removendo BOM se existir"""
    content = path.read_bytes()
    if content.startswith(b"\xef\xbb\xbf"):
        content = content[3:]
    return content.decode("utf-8")


def check_exists(path: Path, name: str) -> bool:
    """Verificar se arquivo existe"""
    if not path.exists():
        erro(f"{name} nao encontrado: {path}")
        return False
    return True


# ============================================================
# PASSO 1 - Criar arquivo de integracoes no backend
# ============================================================

def criar_backend_integrations():
    step(1, "Criando backend/app/api/integrations.py")

    dest = BACKEND / "app" / "api" / "integrations.py"

    if dest.exists():
        warn("integrations.py ja existe - fazendo backup e substituindo")
        backup_file(dest)

    content = '''"""
API de Integracoes - Facebook, Google, Instagram, Mercado Livre
HC Tech AI System v2.1
"""

import os
import json
import httpx
import asyncio
from datetime import datetime, timedelta
from typing import Optional
from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import HTMLResponse
from sqlalchemy import select, String, Text, Boolean, DateTime, Integer, JSON, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column
from pydantic import BaseModel
from loguru import logger

from app.database import AsyncSessionLocal, Base, engine

router = APIRouter()


# ============================================================
# MODELOS
# ============================================================

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
    meta_data: Mapped[dict] = mapped_column(JSON, default=dict)
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
# HELPERS
# ============================================================

REDIRECT_BASE = os.getenv("OAUTH_REDIRECT_BASE", "http://localhost:8000")

PLATFORM_DEFAULTS = [
    {"platform": "facebook",     "name": "Facebook"},
    {"platform": "instagram",    "name": "Instagram Business"},
    {"platform": "google",       "name": "Google Meu Negocio"},
    {"platform": "maps",         "name": "Google Maps"},
    {"platform": "mercadolivre", "name": "Mercado Livre"},
]


async def init_tables():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    async with AsyncSessionLocal() as s:
        for p in PLATFORM_DEFAULTS:
            r = await s.execute(select(Integration).where(Integration.platform == p["platform"]))
            if not r.scalar_one_or_none():
                s.add(Integration(**p))
        await s.commit()


async def get_integration(platform: str) -> Optional[Integration]:
    async with AsyncSessionLocal() as s:
        r = await s.execute(select(Integration).where(Integration.platform == platform))
        return r.scalar_one_or_none()


async def save_integration(platform: str, data: dict):
    async with AsyncSessionLocal() as s:
        r = await s.execute(select(Integration).where(Integration.platform == platform))
        integ = r.scalar_one_or_none()
        if not integ:
            integ = Integration(platform=platform, name=data.get("name", platform))
            s.add(integ)
        for key, value in data.items():
            if hasattr(integ, key):
                setattr(integ, key, value)
        integ.updated_at = datetime.utcnow()
        await s.commit()


async def log_action(platform: str, action: str, status: str, message: str = ""):
    async with AsyncSessionLocal() as s:
        s.add(IntegrationLog(platform=platform, action=action, status=status, message=message))
        await s.commit()


def is_token_valid(integ) -> bool:
    if not integ or not integ.access_token:
        return False
    if integ.token_expires_at and integ.token_expires_at < datetime.utcnow():
        return False
    return True


def get_oauth_config():
    return {
        "facebook": {
            "app_id":     os.getenv("FACEBOOK_APP_ID", ""),
            "app_secret": os.getenv("FACEBOOK_APP_SECRET", ""),
            "scope":      "pages_show_list,pages_read_engagement,pages_manage_posts,instagram_basic",
            "auth_url":   "https://www.facebook.com/v18.0/dialog/oauth",
            "token_url":  "https://graph.facebook.com/v18.0/oauth/access_token",
        },
        "google": {
            "client_id":     os.getenv("GOOGLE_CLIENT_ID", ""),
            "client_secret": os.getenv("GOOGLE_CLIENT_SECRET", ""),
            "scope":         "https://www.googleapis.com/auth/business.manage https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/userinfo.profile",
            "auth_url":      "https://accounts.google.com/o/oauth2/v2/auth",
            "token_url":     "https://oauth2.googleapis.com/token",
        },
        "mercadolivre": {
            "client_id":     os.getenv("ML_CLIENT_ID", ""),
            "client_secret": os.getenv("ML_CLIENT_SECRET", ""),
            "auth_url":      "https://auth.mercadolivre.com.br/authorization",
            "token_url":     "https://api.mercadolibre.com/oauth/token",
        },
    }


# ============================================================
# ENDPOINTS
# ============================================================

@router.get("")
async def list_integrations():
    await init_tables()
    async with AsyncSessionLocal() as s:
        r = await s.execute(select(Integration).order_by(Integration.id))
        items = r.scalars().all()
    return [
        {
            "id": i.id, "platform": i.platform, "name": i.name,
            "status": i.status, "account_name": i.account_name,
            "account_email": i.account_email, "avatar_url": i.avatar_url,
            "permissions": i.permissions or [], "token_valid": is_token_valid(i),
            "connected_at": i.connected_at.isoformat() if i.connected_at else None,
            "last_sync":    i.last_sync.isoformat()    if i.last_sync    else None,
            "meta_data": i.meta_data or {},
        }
        for i in items
    ]


@router.get("/logs")
async def get_logs(limit: int = 30):
    async with AsyncSessionLocal() as s:
        from sqlalchemy import desc
        r = await s.execute(
            select(IntegrationLog).order_by(desc(IntegrationLog.created_at)).limit(limit)
        )
        logs = r.scalars().all()
    return [
        {"platform": l.platform, "action": l.action, "status": l.status,
         "message": l.message, "created_at": l.created_at.isoformat()}
        for l in logs
    ]


@router.get("/{platform}/status")
async def platform_status(platform: str):
    i = await get_integration(platform)
    if not i:
        return {"platform": platform, "status": "disconnected", "connected": False}
    return {
        "platform": platform, "status": i.status,
        "connected": i.status == "connected",
        "account_name": i.account_name, "token_valid": is_token_valid(i),
    }


@router.get("/{platform}/oauth-url")
async def get_oauth_url(platform: str):
    cfg = get_oauth_config()
    p = platform if platform != "maps" else "google"
    if p not in cfg:
        raise HTTPException(400, f"OAuth nao configurado para {platform}")

    c = cfg[p]
    key = "app_id" if p == "facebook" else "client_id"
    if not c.get(key):
        raise HTTPException(400, {
            "error": "credentials_missing",
            "message": f"Configure {key.upper()} no .env",
            "env_vars": _required_env(p),
        })

    redirect = f"{REDIRECT_BASE}/api/integrations/{platform}/callback"

    if p == "facebook":
        url = (f"{c[\'auth_url\']}?client_id={c[\'app_id\']}"
               f"&redirect_uri={redirect}&scope={c[\'scope\']}&response_type=code")
    elif p == "google":
        url = (f"{c[\'auth_url\']}?client_id={c[\'client_id\']}"
               f"&redirect_uri={redirect}&scope={c[\'scope\']}"
               f"&response_type=code&access_type=offline&prompt=consent")
    elif p == "mercadolivre":
        url = (f"{c[\'auth_url\']}?client_id={c[\'client_id\']}"
               f"&redirect_uri={redirect}&response_type=code")
    else:
        raise HTTPException(400, "Plataforma nao suportada")

    return {"oauth_url": url, "platform": platform}


def _required_env(platform):
    m = {
        "facebook":     ["FACEBOOK_APP_ID", "FACEBOOK_APP_SECRET"],
        "google":       ["GOOGLE_CLIENT_ID", "GOOGLE_CLIENT_SECRET"],
        "mercadolivre": ["ML_CLIENT_ID", "ML_CLIENT_SECRET"],
    }
    return m.get(platform, [])


class TokenConfig(BaseModel):
    access_token: str
    account_id:   Optional[str] = None
    account_name: Optional[str] = None


@router.post("/{platform}/configure")
async def configure_token(platform: str, config: TokenConfig):
    validators = {
        "facebook":     _validate_facebook,
        "instagram":    _validate_facebook,
        "google":       _validate_google,
        "maps":         _validate_google,
        "mercadolivre": _validate_ml,
    }
    fn = validators.get(platform)
    if not fn:
        raise HTTPException(400, f"Plataforma {platform} nao suportada")

    result = await fn(config.access_token)
    if not result.get("valid"):
        raise HTTPException(400, f"Token invalido: {result.get(\'error\', \'Erro\')}")

    await save_integration(platform, {
        "status":       "connected",
        "access_token": config.access_token,
        "account_id":   config.account_id   or result.get("account_id"),
        "account_name": config.account_name or result.get("account_name"),
        "account_email": result.get("email"),
        "avatar_url":   result.get("avatar_url"),
        "permissions":  result.get("permissions", []),
        "meta_data":    result.get("metadata", {}),
        "connected_at": datetime.utcnow(),
        "last_sync":    datetime.utcnow(),
    })
    await log_action(platform, "configure", "success",
                     f"Conectado: {result.get(\'account_name\', \'desconhecido\')}")

    return {"success": True, "platform": platform,
            "account_name": result.get("account_name"),
            "message": f"Plataforma {platform} conectada com sucesso!"}


@router.delete("/{platform}/disconnect")
async def disconnect(platform: str):
    await save_integration(platform, {
        "status": "disconnected", "access_token": None,
        "refresh_token": None, "account_id": None,
        "account_name": None, "account_email": None,
    })
    await log_action(platform, "disconnect", "success")
    return {"success": True, "message": f"{platform} desconectado"}


@router.post("/{platform}/sync")
async def sync(platform: str):
    i = await get_integration(platform)
    if not i or i.status != "connected":
        raise HTTPException(400, f"{platform} nao esta conectado")
    await save_integration(platform, {"last_sync": datetime.utcnow()})
    await log_action(platform, "sync", "success")
    return {"success": True, "synced_at": datetime.utcnow().isoformat()}


# ============================================================
# VALIDADORES
# ============================================================

async def _validate_facebook(token: str) -> dict:
    try:
        async with httpx.AsyncClient(timeout=10.0) as c:
            r = await c.get("https://graph.facebook.com/me",
                            params={"access_token": token, "fields": "id,name,email,picture"})
            if r.status_code != 200:
                return {"valid": False, "error": r.json().get("error", {}).get("message", "Token invalido")}
            d = r.json()
            pages_r = await c.get("https://graph.facebook.com/me/accounts",
                                  params={"access_token": token, "fields": "id,name,fan_count"})
            pages = pages_r.json().get("data", []) if pages_r.status_code == 200 else []
            pic = d.get("picture")
            avatar = pic.get("data", {}).get("url") if isinstance(pic, dict) else None
            return {
                "valid": True, "account_id": d.get("id"),
                "account_name": d.get("name"), "email": d.get("email"),
                "avatar_url": avatar,
                "permissions": ["pages_show_list", "pages_read_engagement"],
                "metadata": {"pages": [{"id": p["id"], "name": p["name"]} for p in pages[:5]],
                             "pages_count": len(pages)},
            }
    except Exception as e:
        return {"valid": False, "error": str(e)}


async def _validate_google(token: str) -> dict:
    try:
        async with httpx.AsyncClient(timeout=10.0) as c:
            r = await c.get("https://www.googleapis.com/oauth2/v3/userinfo",
                            headers={"Authorization": f"Bearer {token}"})
            if r.status_code != 200:
                return {"valid": False, "error": "Token Google invalido"}
            d = r.json()
            return {
                "valid": True, "account_id": d.get("sub"),
                "account_name": d.get("name"), "email": d.get("email"),
                "avatar_url": d.get("picture"),
                "permissions": ["business.manage"],
                "metadata": {"locale": d.get("locale", "pt-BR")},
            }
    except Exception as e:
        return {"valid": False, "error": str(e)}


async def _validate_ml(token: str) -> dict:
    try:
        async with httpx.AsyncClient(timeout=10.0) as c:
            r = await c.get("https://api.mercadolibre.com/users/me",
                            headers={"Authorization": f"Bearer {token}"})
            if r.status_code != 200:
                return {"valid": False, "error": "Token Mercado Livre invalido"}
            d = r.json()
            thumb = d.get("thumbnail")
            avatar = thumb.get("picture_url") if isinstance(thumb, dict) else None
            return {
                "valid": True, "account_id": str(d.get("id")),
                "account_name": d.get("nickname") or d.get("first_name"),
                "email": d.get("email"), "avatar_url": avatar,
                "permissions": ["read", "write"],
                "metadata": {"site_id": d.get("site_id"),
                             "seller_level": (d.get("seller_reputation") or {}).get("level_id")},
            }
    except Exception as e:
        return {"valid": False, "error": str(e)}


# ============================================================
# DADOS DAS PLATAFORMAS
# ============================================================

@router.get("/facebook/data")
async def facebook_data():
    i = await get_integration("facebook")
    if not i or not i.access_token:
        raise HTTPException(400, "Facebook nao conectado")
    try:
        async with httpx.AsyncClient(timeout=15.0) as c:
            r = await c.get("https://graph.facebook.com/me/accounts",
                            params={"access_token": i.access_token,
                                    "fields": "id,name,fan_count,followers_count,category"})
            pages = r.json().get("data", []) if r.status_code == 200 else []
        await save_integration("facebook", {"last_sync": datetime.utcnow()})
        return {"account_name": i.account_name, "pages": pages,
                "total_followers": sum(p.get("fan_count", 0) for p in pages)}
    except Exception as e:
        raise HTTPException(500, str(e))


@router.get("/google/locations")
async def google_locations():
    i = await get_integration("google")
    if not i or not i.access_token:
        raise HTTPException(400, "Google nao conectado")
    try:
        async with httpx.AsyncClient(timeout=15.0) as c:
            r = await c.get(
                "https://mybusinessaccountmanagement.googleapis.com/v1/accounts",
                headers={"Authorization": f"Bearer {i.access_token}"})
            if r.status_code == 401:
                await save_integration("google", {"status": "token_expired"})
                raise HTTPException(401, "Token expirado, reconecte")
            accounts = r.json().get("accounts", [])
            locations = []
            for acc in accounts[:3]:
                lr = await c.get(
                    f"https://mybusinessbusinessinformation.googleapis.com/v1/{acc[\'name\']}/locations",
                    headers={"Authorization": f"Bearer {i.access_token}"},
                    params={"readMask": "name,title,phoneNumbers,storefrontAddress"})
                if lr.status_code == 200:
                    locations.extend(lr.json().get("locations", []))
        await save_integration("google", {"last_sync": datetime.utcnow()})
        return {"accounts": accounts, "locations": locations, "total": len(locations)}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(500, str(e))


@router.get("/mercadolivre/data")
async def ml_data():
    i = await get_integration("mercadolivre")
    if not i or not i.access_token:
        raise HTTPException(400, "Mercado Livre nao conectado")
    try:
        async with httpx.AsyncClient(timeout=15.0) as c:
            items_r = await c.get(
                f"https://api.mercadolibre.com/users/{i.account_id}/items/search",
                headers={"Authorization": f"Bearer {i.access_token}"},
                params={"status": "active", "limit": 10})
            user_r = await c.get(
                f"https://api.mercadolibre.com/users/{i.account_id}",
                headers={"Authorization": f"Bearer {i.access_token}"})
        items_data = items_r.json() if items_r.status_code == 200 else {}
        user_data  = user_r.json()  if user_r.status_code  == 200 else {}
        await save_integration("mercadolivre", {"last_sync": datetime.utcnow()})
        return {
            "account_name": i.account_name,
            "active_items": items_data.get("paging", {}).get("total", 0),
            "items":        items_data.get("results", [])[:5],
            "reputation":   user_data.get("seller_reputation", {}),
        }
    except Exception as e:
        raise HTTPException(500, str(e))


# ============================================================
# OAUTH CALLBACK
# ============================================================

@router.get("/{platform}/callback")
async def oauth_callback(platform: str, request: Request):
    code  = request.query_params.get("code")
    error = request.query_params.get("error")

    if error or not code:
        return HTMLResponse(_html("error", platform, error or "Codigo nao recebido"))

    try:
        cfg = get_oauth_config()
        p   = platform if platform != "maps" else "google"
        c   = cfg.get(p, {})
        redirect = f"{REDIRECT_BASE}/api/integrations/{platform}/callback"

        if p == "facebook":
            td = await _fb_exchange(c, code, redirect)
        elif p == "google":
            td = await _google_exchange(c, code, redirect)
        elif p == "mercadolivre":
            td = await _ml_exchange(c, code, redirect)
        else:
            raise ValueError("Plataforma nao suportada")

        await save_integration(platform, {**td, "status": "connected",
                                          "connected_at": datetime.utcnow(),
                                          "last_sync": datetime.utcnow()})
        await log_action(platform, "oauth", "success", td.get("account_name", ""))
        return HTMLResponse(_html("success", platform, td.get("account_name", "Conectado")))
    except Exception as e:
        await log_action(platform, "oauth", "error", str(e))
        return HTMLResponse(_html("error", platform, str(e)))


async def _fb_exchange(c, code, redirect):
    async with httpx.AsyncClient(timeout=15.0) as h:
        r = await h.get(c["token_url"], params={
            "client_id": c["app_id"], "client_secret": c["app_secret"],
            "redirect_uri": redirect, "code": code})
        r.raise_for_status()
        token = r.json()["access_token"]
        u = (await h.get("https://graph.facebook.com/me",
                          params={"access_token": token, "fields": "id,name,email"})).json()
        return {"access_token": token, "account_id": u.get("id"),
                "account_name": u.get("name"), "account_email": u.get("email"),
                "permissions": c.get("scope", "").split(",")}


async def _google_exchange(c, code, redirect):
    async with httpx.AsyncClient(timeout=15.0) as h:
        r = await h.post(c["token_url"], data={
            "client_id": c["client_id"], "client_secret": c["client_secret"],
            "redirect_uri": redirect, "code": code, "grant_type": "authorization_code"})
        r.raise_for_status()
        td = r.json()
        token = td["access_token"]
        u = (await h.get("https://www.googleapis.com/oauth2/v3/userinfo",
                          headers={"Authorization": f"Bearer {token}"})).json()
        return {"access_token": token, "refresh_token": td.get("refresh_token"),
                "token_expires_at": datetime.utcnow() + timedelta(seconds=td.get("expires_in", 3600)),
                "account_id": u.get("sub"), "account_name": u.get("name"),
                "account_email": u.get("email"), "avatar_url": u.get("picture")}


async def _ml_exchange(c, code, redirect):
    async with httpx.AsyncClient(timeout=15.0) as h:
        r = await h.post(c["token_url"], data={
            "grant_type": "authorization_code", "client_id": c["client_id"],
            "client_secret": c["client_secret"], "code": code, "redirect_uri": redirect})
        r.raise_for_status()
        td = r.json()
        token = td["access_token"]
        u = (await h.get("https://api.mercadolibre.com/users/me",
                          headers={"Authorization": f"Bearer {token}"})).json()
        return {"access_token": token, "refresh_token": td.get("refresh_token"),
                "token_expires_at": datetime.utcnow() + timedelta(seconds=td.get("expires_in", 21600)),
                "account_id": str(u.get("id")), "account_name": u.get("nickname"),
                "account_email": u.get("email")}


def _html(status, platform, message):
    icon  = "OK" if status == "success" else "ERRO"
    color = "#22c55e" if status == "success" else "#ef4444"
    return f"""<!DOCTYPE html><html lang="pt-BR"><head><meta charset="UTF-8">
<title>HC Tech - {icon}</title>
<style>body{{font-family:sans-serif;background:#0f172a;color:#f1f5f9;display:flex;
align-items:center;justify-content:center;min-height:100vh;margin:0}}
.c{{background:#1e293b;border:1px solid #334155;border-radius:16px;padding:40px;
text-align:center;max-width:380px;width:90%}}
h1{{color:{color};font-size:18px;margin:16px 0 8px}}
p{{color:#94a3b8;font-size:13px;margin-bottom:24px}}
.btn{{background:{color};color:#fff;border:none;padding:12px 24px;
border-radius:8px;font-size:14px;cursor:pointer;font-weight:600}}</style></head>
<body><div class="c">
<div style="font-size:52px">{"OK" if status == "success" else "X"}</div>
<h1>{"Conectado!" if status == "success" else "Erro na Conexao"}</h1>
<p><b style="color:#60a5fa;text-transform:capitalize">{platform}</b><br>{message}</p>
<button class="btn" onclick="window.opener&&window.opener.postMessage(
{{type:'{status}',platform:'{platform}'}},'*');window.close()">
Fechar</button></div>
<script>setTimeout(()=>{{if(window.opener)window.opener.postMessage(
{{type:'{status}',platform:'{platform}'}},'*');window.close()}},2500)</script>
</body></html>"""
'''

    write_clean(dest, content)
    ok(f"integrations.py criado ({len(content)} bytes)")
    return True


# ============================================================
# PASSO 2 - Atualizar backend/app/main.py
# ============================================================

def atualizar_main_py():
    step(2, "Atualizando backend/app/main.py")

    path = BACKEND / "app" / "main.py"
    if not check_exists(path, "main.py"):
        return False

    backup_file(path)
    content = read_file(path)
    changed = False

    # --- Import ---
    import_line = "from app.api.integrations import router as integrations_router"

    if import_line not in content:
        # Inserir após o último import de router
        pattern = r'(from app\.api\.\w+ import router as \w+_router\n)(?!from app\.api\.)'
        last_import = list(re.finditer(r'from app\.api\.\w+ import router as \w+_router', content))

        if last_import:
            pos = last_import[-1].end()
            content = content[:pos] + "\n" + import_line + content[pos:]
            changed = True
            ok("Import adicionado")
        else:
            warn("Nao encontrou imports de router - adicionando manualmente")
            content = import_line + "\n" + content
            changed = True
    else:
        info("Import ja existe")

    # --- include_router ---
    router_line = 'app.include_router(integrations_router, prefix="/api/integrations", tags=["Integrations"])'

    if router_line not in content:
        # Inserir após o último include_router
        last_router = list(re.finditer(r'app\.include_router\([^)]+\)', content))

        if last_router:
            pos = last_router[-1].end()
            content = content[:pos] + "\n" + router_line + content[pos:]
            changed = True
            ok("include_router adicionado")
        else:
            warn("Nao encontrou include_router - adicionando antes do @app.get")
            idx = content.find("@app.get")
            if idx > -1:
                content = content[:idx] + router_line + "\n\n" + content[idx:]
                changed = True
    else:
        info("include_router ja existe")

    if changed:
        write_clean(path, content)
        ok("main.py atualizado")
    else:
        ok("main.py ja estava atualizado")

    return True


# ============================================================
# PASSO 3 - Criar IntegrationsPage.tsx
# ============================================================

def criar_integrations_page():
    step(3, "Criando frontend/src/components/pages/IntegrationsPage.tsx")

    dest = SRC / "components" / "pages" / "IntegrationsPage.tsx"

    if dest.exists():
        warn("IntegrationsPage.tsx ja existe - fazendo backup")
        backup_file(dest)

    content = '''"use client"
import { useState, useEffect } from "react"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { motion, AnimatePresence } from "framer-motion"
import toast from "react-hot-toast"
import { api } from "@/lib/api"

interface Integration {
  id: number
  platform: string
  name: string
  status: "connected" | "disconnected" | "error" | "token_expired"
  account_name?: string
  account_email?: string
  avatar_url?: string
  permissions: string[]
  connected_at?: string
  last_sync?: string
  token_valid: boolean
  meta_data?: Record<string, any>
}

interface PlatformCfg {
  id: string
  name: string
  description: string
  icon: string
  color: string
  bg: string
  border: string
  badge: string
  features: string[]
  tokenGuide: string
  tokenUrl: string
  envVars: string[]
  steps: string[]
}

const PLATFORMS: PlatformCfg[] = [
  {
    id: "facebook", name: "Facebook", icon: "📘",
    description: "Paginas, posts e metricas de engajamento",
    color: "text-blue-400", bg: "bg-blue-500/10",
    border: "border-blue-500/30", badge: "bg-blue-500/20 text-blue-300",
    features: ["Posts automaticos", "Metricas", "Mensagens", "Insights"],
    tokenGuide: "Meta for Developers → Explorador de API do Graph → Gerar Token",
    tokenUrl: "https://developers.facebook.com/tools/explorer/",
    envVars: ["FACEBOOK_APP_ID", "FACEBOOK_APP_SECRET"],
    steps: [
      "Acesse developers.facebook.com e faca login",
      "Crie um App → Tipo: Business",
      "Va em Ferramentas → Explorador de API do Graph",
      "Selecione seu App e clique em Gerar Token de Acesso",
      "Marque: pages_show_list, pages_read_engagement",
      "Copie o token e cole no campo abaixo",
    ],
  },
  {
    id: "instagram", name: "Instagram Business", icon: "📸",
    description: "Posts, stories, reels e analytics",
    color: "text-pink-400", bg: "bg-pink-500/10",
    border: "border-pink-500/30", badge: "bg-pink-500/20 text-pink-300",
    features: ["Posts e Stories", "Reels", "Hashtags", "Analytics"],
    tokenGuide: "Usa o mesmo token do Facebook (Graph API). Precisa conta Business.",
    tokenUrl: "https://developers.facebook.com/tools/explorer/",
    envVars: ["FACEBOOK_APP_ID", "FACEBOOK_APP_SECRET"],
    steps: [
      "Vincule sua conta Instagram a uma Pagina do Facebook",
      "Acesse developers.facebook.com",
      "No Explorador de API, adicione permissao: instagram_basic",
      "Adicione: instagram_content_publish para publicar",
      "Gere o token e cole abaixo",
    ],
  },
  {
    id: "google", name: "Google Meu Negocio", icon: "🏢",
    description: "Perfil, avaliacoes e insights locais",
    color: "text-green-400", bg: "bg-green-500/10",
    border: "border-green-500/30", badge: "bg-green-500/20 text-green-300",
    features: ["Perfil do negocio", "Avaliacoes", "Posts", "Insights"],
    tokenGuide: "Google Cloud Console → APIs → Business Profile → Credenciais OAuth 2.0",
    tokenUrl: "https://console.cloud.google.com/",
    envVars: ["GOOGLE_CLIENT_ID", "GOOGLE_CLIENT_SECRET"],
    steps: [
      "Acesse console.cloud.google.com",
      "Crie um projeto novo",
      "Va em APIs e Servicos → Ativar APIs",
      "Ative: Business Profile API",
      "Crie credenciais: OAuth 2.0 → App da Web",
      "Adicione URI de redirecionamento: http://localhost:8000/api/integrations/google/callback",
      "Copie Client ID e Secret para o .env",
      "Use o botao OAuth para autorizar",
    ],
  },
  {
    id: "maps", name: "Google Maps", icon: "🗺️",
    description: "Localizacao, rotas e visibilidade no Maps",
    color: "text-red-400", bg: "bg-red-500/10",
    border: "border-red-500/30", badge: "bg-red-500/20 text-red-300",
    features: ["Posicao no Maps", "Rotas", "Fotos", "Q&A"],
    tokenGuide: "Google Cloud Console → APIs → Maps → Criar chave de API",
    tokenUrl: "https://console.cloud.google.com/google/maps-apis/",
    envVars: ["GOOGLE_MAPS_API_KEY"],
    steps: [
      "Acesse console.cloud.google.com",
      "APIs e Servicos → Ativar APIs",
      "Ative: Maps JavaScript API e Places API",
      "Credenciais → Criar Chave de API",
      "Copie a chave e adicione no .env como GOOGLE_MAPS_API_KEY",
      "Para conectar aqui, use o token OAuth do Google Meu Negocio",
    ],
  },
  {
    id: "mercadolivre", name: "Mercado Livre", icon: "🛒",
    description: "Anuncios, vendas e reputacao de vendedor",
    color: "text-yellow-400", bg: "bg-yellow-500/10",
    border: "border-yellow-500/30", badge: "bg-yellow-500/20 text-yellow-300",
    features: ["Anuncios", "Vendas", "Reputacao", "Mensagens"],
    tokenGuide: "Mercado Livre Developers → Criar App → Credenciais",
    tokenUrl: "https://developers.mercadolivre.com.br/",
    envVars: ["ML_CLIENT_ID", "ML_CLIENT_SECRET"],
    steps: [
      "Acesse developers.mercadolivre.com.br",
      "Faca login com sua conta do Mercado Livre",
      "Clique em Criar aplicativo",
      "Preencha os dados e salve",
      "Copie Client ID e Secret para o .env",
      "Adicione a URI: http://localhost:8000/api/integrations/mercadolivre/callback",
      "Use o botao OAuth para conectar",
    ],
  },
]

const getIntegrations = () => api.get("/integrations").then(r => r.data as Integration[])
const getLogs        = () => api.get("/integrations/logs").then(r => r.data)
const getOAuthUrl    = (p: string) => api.get(`/integrations/${p}/oauth-url`).then(r => r.data)

function StatusDot({ status }: { status: string }) {
  const c = status === "connected" ? "bg-green-400 shadow-green-400/50"
          : status === "token_expired" ? "bg-orange-400"
          : status === "error" ? "bg-red-400"
          : "bg-slate-600"
  return <span className={`inline-block w-2 h-2 rounded-full ${c} ${status==="connected"?"shadow-sm animate-pulse":""}`} />
}

function StatusBadge({ status }: { status: string }) {
  const cfg = {
    connected:     { label: "Conectado",    cls: "bg-green-500/20 text-green-400 border-green-500/30" },
    disconnected:  { label: "Desconectado", cls: "bg-slate-700 text-slate-400 border-slate-600" },
    error:         { label: "Erro",         cls: "bg-red-500/20 text-red-400 border-red-500/30" },
    token_expired: { label: "Expirado",     cls: "bg-orange-500/20 text-orange-400 border-orange-500/30" },
  }
  const s = cfg[status as keyof typeof cfg] || cfg.disconnected
  return <span className={`text-xs px-2 py-0.5 rounded-full border font-medium ${s.cls}`}>{s.label}</span>
}

function Modal({ children, onClose, wide = false }: {
  children: React.ReactNode; onClose: () => void; wide?: boolean
}) {
  return (
    <motion.div initial={{opacity:0}} animate={{opacity:1}} exit={{opacity:0}}
      className="fixed inset-0 bg-black/70 backdrop-blur-sm z-50 flex items-center justify-center p-4"
      onClick={onClose}>
      <motion.div initial={{opacity:0,scale:0.95,y:20}} animate={{opacity:1,scale:1,y:0}}
        exit={{opacity:0,scale:0.95}}
        className={`bg-slate-900 border border-slate-700 rounded-2xl shadow-2xl overflow-hidden max-h-[90vh] overflow-y-auto ${wide?"w-full max-w-2xl":"w-full max-w-md"}`}
        onClick={e=>e.stopPropagation()}>
        {children}
      </motion.div>
    </motion.div>
  )
}

export default function IntegrationsPage() {
  const qc = useQueryClient()
  const [modal, setModal] = useState<{type:"config"|"guide"|"details"; platform: PlatformCfg}|null>(null)
  const [token, setToken] = useState("")
  const [showToken, setShowToken] = useState(false)
  const [tab, setTab] = useState<"grid"|"logs">("grid")

  const { data: integrations = [], isLoading } = useQuery({
    queryKey: ["integrations"],
    queryFn: getIntegrations,
    refetchInterval: 30000,
  })
  const { data: logs = [] } = useQuery({
    queryKey: ["int-logs"],
    queryFn: getLogs,
    enabled: tab === "logs",
    refetchInterval: 10000,
  })

  useEffect(() => {
    const fn = (e: MessageEvent) => {
      if (e.data?.type === "success") {
        toast.success(`✅ ${e.data.platform} conectado!`)
        qc.invalidateQueries({ queryKey: ["integrations"] })
        setModal(null)
      } else if (e.data?.type === "error") {
        toast.error(`Erro: ${e.data.message || "Falha na conexao"}`)
      }
    }
    window.addEventListener("message", fn)
    return () => window.removeEventListener("message", fn)
  }, [qc])

  const disconnectMut = useMutation({
    mutationFn: (p: string) => api.delete(`/integrations/${p}/disconnect`).then(r => r.data),
    onSuccess: () => { qc.invalidateQueries({queryKey:["integrations"]}); toast.success("Desconectado"); setModal(null) },
  })
  const syncMut = useMutation({
    mutationFn: (p: string) => api.post(`/integrations/${p}/sync`).then(r => r.data),
    onSuccess: (_, p) => { qc.invalidateQueries({queryKey:["integrations"]}); toast.success(`${p} sincronizado!`) },
  })
  const configMut = useMutation({
    mutationFn: ({ p, t }: { p: string; t: string }) =>
      api.post(`/integrations/${p}/configure`, { access_token: t }).then(r => r.data),
    onSuccess: (d) => {
      qc.invalidateQueries({queryKey:["integrations"]})
      toast.success(d.message || "Conectado!")
      setModal(null); setToken("")
    },
    onError: (e: any) => toast.error(e.message || "Token invalido"),
  })

  const handleOAuth = async (p: PlatformCfg) => {
    try {
      const { oauth_url } = await getOAuthUrl(p.id)
      const popup = window.open(oauth_url, "oauth", "width=620,height=720,scrollbars=yes")
      if (!popup) toast.error("Popup bloqueado! Permita popups para este site.")
    } catch (e: any) {
      const d = e.response?.data?.detail
      if (typeof d === "object" && d?.error === "credentials_missing") {
        toast.error(`Configure ${d.env_vars?.join(" e ")} no .env`)
        setModal({ type: "guide", platform: p })
      } else {
        toast.error(e.message || "Erro ao gerar URL")
      }
    }
  }

  const getStatus = (id: string) => (integrations as Integration[]).find(i => i.platform === id)
  const connected = (integrations as Integration[]).filter(i => i.status === "connected").length

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h2 className="text-xl font-bold text-white">🔗 Integracoes</h2>
          <p className="text-xs text-slate-400">{connected}/{PLATFORMS.length} plataformas conectadas</p>
        </div>
        <div className="flex gap-2">
          {(["grid","logs"] as const).map(t => (
            <button key={t} onClick={() => setTab(t)}
              className={`px-4 py-2 rounded-lg text-xs font-medium transition-colors ${
                tab===t ? "bg-blue-600 text-white" : "bg-slate-800 text-slate-400 hover:text-white"}`}>
              {t === "grid" ? "🔌 Plataformas" : "📋 Logs"}
            </button>
          ))}
        </div>
      </div>

      {/* Status bar */}
      <div className="grid grid-cols-2 sm:grid-cols-5 gap-2">
        {PLATFORMS.map(p => {
          const s = getStatus(p.id)
          const ok = s?.status === "connected"
          return (
            <div key={p.id} className={`flex items-center gap-2 px-3 py-2 rounded-lg border text-xs ${ok ? `${p.bg} ${p.border}` : "bg-slate-900 border-slate-800"}`}>
              <span className="text-base">{p.icon}</span>
              <div className="min-w-0">
                <p className={`font-semibold truncate ${ok ? p.color : "text-slate-400"}`}>{p.name.split(" ")[0]}</p>
                <div className="flex items-center gap-1">
                  <StatusDot status={s?.status || "disconnected"} />
                  <span className={ok ? "text-green-400" : "text-slate-600"}>{ok ? "Online" : "Offline"}</span>
                </div>
              </div>
            </div>
          )
        })}
      </div>

      {/* Content */}
      {tab === "grid" ? (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
          {PLATFORMS.map((p, i) => {
            const s = getStatus(p.id)
            const ok = s?.status === "connected"
            const exp = s?.status === "token_expired"
            return (
              <motion.div key={p.id} initial={{opacity:0,y:20}} animate={{opacity:1,y:0}} transition={{delay:i*0.05}}
                className={`bg-slate-900 rounded-xl border overflow-hidden hover:border-slate-600 transition-all ${ok ? p.border : "border-slate-800"}`}>

                {/* Top */}
                <div className={`p-4 flex items-start gap-3 ${ok ? p.bg : ""}`}>
                  <div className={`w-12 h-12 rounded-xl flex items-center justify-center text-2xl flex-shrink-0 ${p.bg} border ${p.border}`}>{p.icon}</div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 flex-wrap mb-0.5">
                      <h3 className="text-sm font-bold text-white">{p.name}</h3>
                      <StatusBadge status={s?.status || "disconnected"} />
                    </div>
                    <p className="text-xs text-slate-400">{p.description}</p>
                    {ok && s?.account_name && (
                      <div className="flex items-center gap-1.5 mt-1.5">
                        {s.avatar_url && (
                          <img src={s.avatar_url} alt="" className="w-4 h-4 rounded-full object-cover"
                            onError={e => { (e.target as HTMLImageElement).style.display = "none" }} />
                        )}
                        <span className={`text-xs font-medium ${p.color} truncate`}>{s.account_name}</span>
                      </div>
                    )}
                  </div>
                </div>

                {/* Features */}
                <div className="px-4 py-3 border-t border-slate-800">
                  <div className="flex flex-wrap gap-1 mb-3">
                    {p.features.map(f => (
                      <span key={f} className={`text-xs px-2 py-0.5 rounded-full border ${ok ? `${p.badge} ${p.border}` : "bg-slate-800 text-slate-600 border-slate-700"}`}>{f}</span>
                    ))}
                  </div>

                  {ok && s?.last_sync && (
                    <p className="text-xs text-slate-600 mb-3">
                      🔄 {new Date(s.last_sync).toLocaleString("pt-BR", {timeStyle:"short",dateStyle:"short"})}
                    </p>
                  )}

                  {/* Buttons */}
                  {ok ? (
                    <div className="flex gap-2">
                      <button onClick={() => setModal({type:"details", platform:p})}
                        className={`flex-1 py-2 text-xs font-medium rounded-lg border ${p.bg} ${p.color} ${p.border} hover:opacity-80 transition-opacity`}>
                        📊 Detalhes
                      </button>
                      <button onClick={() => syncMut.mutate(p.id)} disabled={syncMut.isPending}
                        className="px-3 py-2 text-xs text-slate-400 border border-slate-700 rounded-lg hover:bg-slate-800 transition-colors" title="Sincronizar">
                        🔄
                      </button>
                      <button onClick={() => { if(confirm(`Desconectar ${p.name}?`)) disconnectMut.mutate(p.id) }}
                        className="px-3 py-2 text-xs text-red-400 border border-red-500/30 rounded-lg hover:bg-red-500/10 transition-colors" title="Desconectar">
                        ✕
                      </button>
                    </div>
                  ) : (
                    <div className="space-y-2">
                      <div className="flex gap-2">
                        <button onClick={() => { setModal({type:"config", platform:p}); setToken("") }}
                          className={`flex-1 py-2 text-xs font-medium rounded-lg border ${p.bg} ${p.color} ${p.border} hover:opacity-80`}>
                          🔑 Token Manual
                        </button>
                        <button onClick={() => handleOAuth(p)}
                          className="flex-1 py-2 text-xs font-medium rounded-lg bg-slate-800 border border-slate-700 text-slate-300 hover:bg-slate-700 transition-colors">
                          🔐 OAuth
                        </button>
                      </div>
                      <button onClick={() => setModal({type:"guide", platform:p})}
                        className="w-full text-xs text-slate-600 hover:text-slate-400 py-1 transition-colors">
                        📖 Como obter credenciais →
                      </button>
                    </div>
                  )}
                  {exp && <p className="text-xs text-orange-400 mt-2 text-center">⚠️ Token expirado — reconecte</p>}
                </div>
              </motion.div>
            )
          })}
        </div>
      ) : (
        /* LOGS */
        <div className="bg-slate-900 border border-slate-800 rounded-xl overflow-hidden">
          <div className="p-4 border-b border-slate-800 flex items-center justify-between">
            <h3 className="text-sm font-semibold text-white">📋 Historico de Integracoes</h3>
            <button onClick={() => qc.invalidateQueries({queryKey:["int-logs"]})}
              className="text-xs text-slate-400 hover:text-white">🔄 Atualizar</button>
          </div>
          <div className="divide-y divide-slate-800 max-h-[500px] overflow-y-auto">
            {(logs as any[]).length === 0
              ? <p className="text-xs text-slate-600 text-center py-10">Nenhum log ainda</p>
              : (logs as any[]).map((l, i) => {
                  const pc = PLATFORMS.find(p => p.id === l.platform)
                  return (
                    <div key={i} className="flex items-center gap-3 p-3 hover:bg-slate-800/30 transition-colors">
                      <span className="text-xl flex-shrink-0">{pc?.icon || "🔌"}</span>
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2 flex-wrap">
                          <span className="text-xs font-medium text-white capitalize">{l.platform}</span>
                          <span className="text-xs text-slate-500">{l.action}</span>
                          <span className={`text-xs px-1.5 py-0.5 rounded ${l.status==="success"?"bg-green-500/20 text-green-400":"bg-red-500/20 text-red-400"}`}>
                            {l.status}
                          </span>
                        </div>
                        {l.message && <p className="text-xs text-slate-400 truncate">{l.message}</p>}
                      </div>
                      <span className="text-xs text-slate-600 flex-shrink-0">
                        {new Date(l.created_at).toLocaleString("pt-BR",{timeStyle:"short",dateStyle:"short"})}
                      </span>
                    </div>
                  )
                })}
          </div>
        </div>
      )}

      {/* MODAIS */}
      <AnimatePresence>
        {modal?.type === "config" && (
          <Modal onClose={() => { setModal(null); setToken("") }}>
            <div className="p-6">
              <div className="flex items-center gap-3 mb-5">
                <span className="text-3xl">{modal.platform.icon}</span>
                <div>
                  <h3 className="text-base font-bold text-white">Conectar {modal.platform.name}</h3>
                  <p className="text-xs text-slate-400">Cole seu access token abaixo</p>
                </div>
              </div>
              <div className="space-y-4">
                <div>
                  <label className="text-xs font-medium text-slate-300 block mb-1.5">🔑 Access Token</label>
                  <div className="relative">
                    <input type={showToken?"text":"password"} value={token}
                      onChange={e=>setToken(e.target.value)}
                      placeholder="Cole seu token aqui..."
                      className="w-full bg-slate-800 border border-slate-700 rounded-lg px-3 py-2.5 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-blue-500 pr-10"/>
                    <button onClick={()=>setShowToken(!showToken)}
                      className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-white text-sm">
                      {showToken?"🙈":"👁️"}
                    </button>
                  </div>
                </div>
                <div className={`p-3 rounded-lg border ${modal.platform.bg} ${modal.platform.border}`}>
                  <p className="text-xs font-medium text-slate-300 mb-1">📖 Como obter:</p>
                  <p className="text-xs text-slate-400 mb-2">{modal.platform.tokenGuide}</p>
                  <a href={modal.platform.tokenUrl} target="_blank" rel="noopener noreferrer"
                    className={`text-xs font-medium ${modal.platform.color} hover:underline`}>
                    Abrir {modal.platform.name} Developers →
                  </a>
                </div>
                <div className="p-3 bg-slate-800 rounded-lg">
                  <p className="text-xs text-slate-400 mb-2">⚙️ Variaveis no <code className="text-blue-400">.env</code>:</p>
                  {modal.platform.envVars.map(v => (
                    <code key={v} className="block text-xs text-green-400 font-mono">{v}=sua_chave</code>
                  ))}
                </div>
                <div className="flex gap-2 pt-1">
                  <button onClick={()=>{setModal(null);setToken("")}}
                    className="flex-1 py-2.5 text-sm text-slate-400 border border-slate-700 rounded-lg hover:bg-slate-800">
                    Cancelar
                  </button>
                  <button onClick={()=>configMut.mutate({p:modal.platform.id,t:token})}
                    disabled={!token.trim()||configMut.isPending}
                    className={`flex-1 py-2.5 text-sm font-medium text-white rounded-lg border disabled:opacity-50 transition-all ${modal.platform.bg} ${modal.platform.border} hover:opacity-80`}>
                    {configMut.isPending?"🔄 Validando...":"✅ Conectar"}
                  </button>
                </div>
              </div>
            </div>
          </Modal>
        )}

        {modal?.type === "guide" && (
          <Modal onClose={()=>setModal(null)}>
            <div className="p-6">
              <div className="flex items-center gap-3 mb-5">
                <span className="text-3xl">{modal.platform.icon}</span>
                <div>
                  <h3 className="text-base font-bold text-white">📖 {modal.platform.name}</h3>
                  <p className="text-xs text-slate-400">Guia de configuracao</p>
                </div>
              </div>
              <div className="space-y-2 mb-4">
                {modal.platform.steps.map((s,i) => (
                  <div key={i} className="flex gap-3 items-start">
                    <div className={`w-5 h-5 rounded-full flex items-center justify-center text-xs font-bold flex-shrink-0 mt-0.5 ${modal.platform.bg} ${modal.platform.color} border ${modal.platform.border}`}>
                      {i+1}
                    </div>
                    <p className="text-xs text-slate-300 leading-relaxed">{s}</p>
                  </div>
                ))}
              </div>
              <div className="bg-slate-800 rounded-lg p-3 mb-4">
                <p className="text-xs text-slate-400 mb-1">📄 No arquivo <code className="text-blue-400">.env</code>:</p>
                {modal.platform.envVars.map(v => (
                  <code key={v} className="block text-xs text-green-400 font-mono">{v}=sua_chave</code>
                ))}
              </div>
              <div className="flex gap-2">
                <a href={modal.platform.tokenUrl} target="_blank" rel="noopener noreferrer"
                  className="flex-1 py-2.5 text-xs text-center text-slate-300 border border-slate-700 rounded-lg hover:bg-slate-800 transition-colors">
                  📚 Documentacao
                </a>
                <button onClick={()=>setModal({type:"config",platform:modal.platform})}
                  className={`flex-1 py-2.5 text-xs font-medium rounded-lg border ${modal.platform.bg} ${modal.platform.color} ${modal.platform.border} hover:opacity-80`}>
                  🔑 Tenho meu Token
                </button>
              </div>
            </div>
          </Modal>
        )}

        {modal?.type === "details" && (
          <Modal onClose={()=>setModal(null)} wide>
            <DetailsPanel
              platform={modal.platform}
              integ={(integrations as Integration[]).find(i=>i.platform===modal.platform.id)}
              onDisconnect={()=>disconnectMut.mutate(modal.platform.id)}
              onSync={()=>syncMut.mutate(modal.platform.id)}
            />
          </Modal>
        )}
      </AnimatePresence>
    </div>
  )
}

function DetailsPanel({ platform, integ, onDisconnect, onSync }: {
  platform: PlatformCfg; integ?: Integration; onDisconnect: ()=>void; onSync: ()=>void
}) {
  const { data, isLoading } = useQuery({
    queryKey: ["int-data", platform.id],
    queryFn: async () => {
      if (platform.id === "facebook") return api.get("/integrations/facebook/data").then(r=>r.data).catch(()=>null)
      if (platform.id === "google" || platform.id === "maps") return api.get("/integrations/google/locations").then(r=>r.data).catch(()=>null)
      if (platform.id === "mercadolivre") return api.get("/integrations/mercadolivre/data").then(r=>r.data).catch(()=>null)
      return null
    },
    enabled: integ?.status === "connected",
  })

  return (
    <div>
      <div className={`p-6 ${platform.bg} border-b border-slate-800`}>
        <div className="flex items-start gap-4">
          <div className={`w-14 h-14 rounded-xl flex items-center justify-center text-3xl border ${platform.border} ${platform.bg}`}>{platform.icon}</div>
          <div className="flex-1">
            <h3 className="text-lg font-bold text-white">{platform.name}</h3>
            <p className={`text-sm font-medium ${platform.color}`}>{integ?.account_name||"—"}</p>
            <p className="text-xs text-slate-400">{integ?.account_email||""}</p>
          </div>
          <StatusBadge status={integ?.status||"disconnected"} />
        </div>
      </div>
      <div className="p-6 space-y-4">
        <div className="grid grid-cols-2 gap-3">
          <div className="bg-slate-800 rounded-lg p-3">
            <p className="text-xs text-slate-400">Conectado em</p>
            <p className="text-sm font-medium text-white">{integ?.connected_at ? new Date(integ.connected_at).toLocaleDateString("pt-BR") : "—"}</p>
          </div>
          <div className="bg-slate-800 rounded-lg p-3">
            <p className="text-xs text-slate-400">Ultima sync</p>
            <p className="text-sm font-medium text-white">{integ?.last_sync ? new Date(integ.last_sync).toLocaleString("pt-BR",{timeStyle:"short",dateStyle:"short"}) : "—"}</p>
          </div>
        </div>

        {isLoading && <p className="text-xs text-slate-400 text-center py-4 animate-pulse">🔄 Carregando dados...</p>}

        {data && (
          <div className="bg-slate-800 rounded-lg p-4 space-y-2">
            <p className="text-xs font-semibold text-slate-300 uppercase tracking-wider mb-3">Dados da Plataforma</p>
            {platform.id === "facebook" && <>
              <div className="flex justify-between text-sm"><span className="text-slate-400">Paginas</span><span className="text-white font-medium">{data.pages?.length||0}</span></div>
              <div className="flex justify-between text-sm"><span className="text-slate-400">Total Seguidores</span><span className="text-white font-medium">{data.total_followers?.toLocaleString()||0}</span></div>
              {data.pages?.map((p:any)=>(
                <div key={p.id} className="flex justify-between text-xs pt-1 border-t border-slate-700">
                  <span className="text-slate-400">{p.name}</span>
                  <span className="text-blue-400">{p.fan_count?.toLocaleString()} fas</span>
                </div>
              ))}
            </>}
            {(platform.id === "google"||platform.id === "maps") && <>
              <div className="flex justify-between text-sm"><span className="text-slate-400">Locais</span><span className="text-white font-medium">{data.total||0}</span></div>
              {data.locations?.map((l:any,i:number)=>(
                <div key={i} className="text-xs pt-1 border-t border-slate-700"><p className="text-white">{l.title||l.name}</p></div>
              ))}
            </>}
            {platform.id === "mercadolivre" && <>
              <div className="flex justify-between text-sm"><span className="text-slate-400">Anuncios Ativos</span><span className="text-white font-medium">{data.active_items||0}</span></div>
              {data.reputation?.level_id && (
                <div className="flex justify-between text-sm"><span className="text-slate-400">Nivel Vendedor</span><span className="text-yellow-400 font-medium capitalize">{data.reputation.level_id}</span></div>
              )}
            </>}
          </div>
        )}

        <div className="flex gap-2 pt-2 border-t border-slate-800">
          <button onClick={onSync} className="flex-1 py-2 text-xs text-blue-400 border border-blue-500/30 rounded-lg hover:bg-blue-500/10 transition-colors">🔄 Sincronizar</button>
          <button onClick={()=>{if(confirm(`Desconectar ${platform.name}?`))onDisconnect()}} className="flex-1 py-2 text-xs text-red-400 border border-red-500/30 rounded-lg hover:bg-red-500/10 transition-colors">✕ Desconectar</button>
        </div>
      </div>
    </div>
  )
}
'''

    write_clean(dest, content)
    ok(f"IntegrationsPage.tsx criado ({len(content):,} bytes)")
    return True


# ============================================================
# PASSO 4 - Atualizar page.tsx
# ============================================================

def atualizar_page_tsx():
    step(4, "Atualizando frontend/src/app/page.tsx")

    path = SRC / "app" / "page.tsx"
    if not check_exists(path, "page.tsx"):
        return False

    backup_file(path)
    content = read_file(path)
    changed = False

    # Import
    imp = 'import IntegrationsPage from "@/components/pages/IntegrationsPage"'
    if imp not in content:
        last_import = list(re.finditer(r'import \w+Page from "@/components/pages/\w+"', content))
        if last_import:
            pos = last_import[-1].end()
            content = content[:pos] + "\n" + imp + content[pos:]
            changed = True
            ok("Import IntegrationsPage adicionado")
        else:
            warn("Nao encontrou imports de pages - adicione manualmente")
    else:
        info("Import IntegrationsPage ja existe")

    # Entrada no objeto pages
    entry = "  integrations: IntegrationsPage,"
    if "integrations:" not in content:
        # Procurar o objeto pages
        m = re.search(r'(const pages[^=]*=\s*\{[^}]+)(settings:\s*\w+,?)', content, re.DOTALL)
        if m:
            pos = m.end()
            content = content[:pos] + "\n" + entry + content[pos:]
            changed = True
            ok("integrations: IntegrationsPage adicionado ao objeto pages")
        else:
            warn("Nao encontrou objeto pages - adicione manualmente: integrations: IntegrationsPage")
    else:
        info("integrations ja existe no objeto pages")

    if changed:
        write_clean(path, content)
        ok("page.tsx atualizado")
    else:
        ok("page.tsx ja estava atualizado")

    return True


# ============================================================
# PASSO 5 - Atualizar Sidebar.tsx
# ============================================================

def atualizar_sidebar():
    step(5, "Atualizando frontend/src/components/layout/Sidebar.tsx")

    path = SRC / "components" / "layout" / "Sidebar.tsx"
    if not check_exists(path, "Sidebar.tsx"):
        return False

    backup_file(path)
    content = read_file(path)

    entry = '  { id: "integrations", label: "🔗 Integracoes" },'

    if "integrations" not in content:
        # Inserir após maps
        m = re.search(r'(\{\s*id:\s*["\']maps["\'][^}]+\})', content, re.DOTALL)
        if m:
            pos = m.end()
            content = content[:pos] + "\n" + entry + content[pos:]
            write_clean(path, content)
            ok("Item Integracoes adicionado ao nav (apos Maps)")
        else:
            # Tentar inserir antes de knowledge
            m2 = re.search(r'(\{\s*id:\s*["\']knowledge["\'][^}]+\})', content, re.DOTALL)
            if m2:
                pos = m2.start()
                content = content[:pos] + entry + "\n  " + content[pos:]
                write_clean(path, content)
                ok("Item Integracoes adicionado ao nav (antes de Knowledge)")
            else:
                warn("Nao encontrou posicao para inserir - adicione manualmente no array nav")
    else:
        info("integrations ja existe no Sidebar")

    return True


# ============================================================
# PASSO 6 - Atualizar Header.tsx (adicionar integrations ao pageNames)
# ============================================================

def atualizar_header():
    step(6, "Atualizando frontend/src/components/layout/Header.tsx")

    path = SRC / "components" / "layout" / "Header.tsx"
    if not path.exists():
        warn("Header.tsx nao encontrado - pulando")
        return True

    backup_file(path)
    content = read_file(path)

    if "integrations:" not in content:
        entry = '  integrations: "🔗 Integracoes",'
        m = re.search(r'(settings:\s*["\][^"\']+["\'])', content)
        if m:
            pos = m.end()
            content = content[:pos] + "\n" + entry + content[pos:]
            write_clean(path, content)
            ok("integrations adicionado ao pageNames")
        else:
            warn("Nao encontrou pageNames - adicione manualmente")
    else:
        info("integrations ja existe no Header")

    return True


# ============================================================
# PASSO 7 - Atualizar .env
# ============================================================

def atualizar_env():
    step(7, "Atualizando .env com variaveis de integracoes")

    path = ROOT / ".env"
    if not path.exists():
        warn(".env nao encontrado - criando...")
        path.write_bytes(b"")

    content = read_file(path)

    new_vars = """
# ===== INTEGRACOES =====

# Facebook & Instagram (developers.facebook.com)
FACEBOOK_APP_ID=seu_app_id_aqui
FACEBOOK_APP_SECRET=seu_app_secret_aqui

# Google Meu Negocio + Maps (console.cloud.google.com)
GOOGLE_CLIENT_ID=seu_client_id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=seu_client_secret_aqui
GOOGLE_MAPS_API_KEY=sua_api_key_aqui

# Mercado Livre (developers.mercadolivre.com.br)
ML_CLIENT_ID=seu_client_id_aqui
ML_CLIENT_SECRET=seu_client_secret_aqui

# OAuth - URL base do backend
OAUTH_REDIRECT_BASE=http://localhost:8000
"""

    vars_to_check = [
        "FACEBOOK_APP_ID", "FACEBOOK_APP_SECRET",
        "GOOGLE_CLIENT_ID", "GOOGLE_CLIENT_SECRET", "GOOGLE_MAPS_API_KEY",
        "ML_CLIENT_ID", "ML_CLIENT_SECRET",
        "OAUTH_REDIRECT_BASE",
    ]

    missing = [v for v in vars_to_check if v not in content]

    if missing:
        content = content.rstrip() + "\n" + new_vars
        write_clean(path, content)
        ok(f".env atualizado ({len(missing)} variaveis adicionadas)")
        for v in missing:
            info(f"Adicionado: {v}")
    else:
        ok("Todas as variaveis ja existem no .env")

    return True


# ============================================================
# PASSO 8 - Verificacao final
# ============================================================

def verificacao_final():
    step(8, "Verificacao final")

    checks = [
        (BACKEND / "app" / "api" / "integrations.py",      "Backend integrations.py"),
        (SRC / "components" / "pages" / "IntegrationsPage.tsx", "Frontend IntegrationsPage.tsx"),
        (ROOT / ".env",                                        ".env atualizado"),
    ]

    all_ok = True
    for path, name in checks:
        if path.exists() and path.stat().st_size > 100:
            ok(f"{name} ({path.stat().st_size:,} bytes)")
        else:
            erro(f"{name} - PROBLEMA!")
            all_ok = False

    # Verificar imports no main.py
    main_content = read_file(BACKEND / "app" / "main.py")
    if "integrations_router" in main_content:
        ok("main.py contem integrations_router")
    else:
        erro("main.py NAO contem integrations_router!")
        all_ok = False

    # Verificar page.tsx
    page_content = read_file(SRC / "app" / "page.tsx")
    if "IntegrationsPage" in page_content:
        ok("page.tsx contem IntegrationsPage")
    else:
        erro("page.tsx NAO contem IntegrationsPage!")
        all_ok = False

    # Verificar sidebar
    sidebar_content = read_file(SRC / "components" / "layout" / "Sidebar.tsx")
    if "integrations" in sidebar_content:
        ok("Sidebar.tsx contem item integracoes")
    else:
        erro("Sidebar.tsx NAO contem item integracoes!")
        all_ok = False

    return all_ok


# ============================================================
# MAIN
# ============================================================

def main():
    print(f"""
{C}{B}╔══════════════════════════════════════════════════════════╗
║   HC TECH AI SYSTEM v2.1 - Modulo Integracoes           ║
║   Automacao completa de instalacao                      ║
╚══════════════════════════════════════════════════════════╝{E}
""")

    steps_fn = [
        criar_backend_integrations,
        atualizar_main_py,
        criar_integrations_page,
        atualizar_page_tsx,
        atualizar_sidebar,
        atualizar_header,
        atualizar_env,
    ]

    erros = 0
    for fn in steps_fn:
        try:
            result = fn()
            if result is False:
                erros += 1
        except Exception as e:
            erro(f"Excecao em {fn.__name__}: {e}")
            import traceback
            traceback.print_exc()
            erros += 1

    # Verificacao
    ok_final = verificacao_final()

    if erros == 0 and ok_final:
        print(f"""
{G}{B}╔══════════════════════════════════════════════════════════╗
║         MODULO INTEGRACOES INSTALADO!                   ║
╠══════════════════════════════════════════════════════════╣
║                                                          ║
║  Proximo passo:                                          ║
║  Reinicie o sistema com iniciar_completo.bat            ║
║                                                          ║
║  Acesse:  http://localhost:3000                          ║
║  Menu:    Integracoes (na sidebar)                      ║
║                                                          ║
║  Configure suas credenciais no .env:                    ║
║  FACEBOOK_APP_ID, GOOGLE_CLIENT_ID, ML_CLIENT_ID       ║
╚══════════════════════════════════════════════════════════╝{E}
""")
    else:
        print(f"""
{Y}{B}╔══════════════════════════════════════════════════════════╗
║  INSTALADO COM AVISOS ({erros} problemas)               ║
║  Verifique os erros acima e corrija manualmente.        ║
╚══════════════════════════════════════════════════════════╝{E}
""")


if __name__ == "__main__":
    main()