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