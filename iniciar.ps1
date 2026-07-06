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