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