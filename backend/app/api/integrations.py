"""
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
        url = (f"{c['auth_url']}?client_id={c['app_id']}"
               f"&redirect_uri={redirect}&scope={c['scope']}&response_type=code")
    elif p == "google":
        url = (f"{c['auth_url']}?client_id={c['client_id']}"
               f"&redirect_uri={redirect}&scope={c['scope']}"
               f"&response_type=code&access_type=offline&prompt=consent")
    elif p == "mercadolivre":
        url = (f"{c['auth_url']}?client_id={c['client_id']}"
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
        raise HTTPException(400, f"Token invalido: {result.get('error', 'Erro')}")

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
                     f"Conectado: {result.get('account_name', 'desconhecido')}")

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
                    f"https://mybusinessbusinessinformation.googleapis.com/v1/{acc['name']}/locations",
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
