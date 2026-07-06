# iniciar_frontend.ps1
# Resolve o problema de ExecutionPolicy e inicia o frontend

$root = "C:\Users\hunlock\Documents\LOJA\Agente_Sistemas\Arena IA - Claude Sonnet"
$frontendPath = "$root\frontend"

Clear-Host
Write-Host @"
╔══════════════════════════════════════════╗
║   HC TECH AI - Iniciando Frontend        ║
╚══════════════════════════════════════════╝
"@ -ForegroundColor Cyan

# ============================================================
# FIX: Execution Policy
# ============================================================
Write-Host "[1] Configurando politica de scripts..." -ForegroundColor Yellow

try {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Write-Host "  OK RemoteSigned aplicado (CurrentUser)" -ForegroundColor Green
} catch {
    Write-Host "  Tentando Bypass..." -ForegroundColor Yellow
    try {
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
        Write-Host "  OK Bypass aplicado (Process)" -ForegroundColor Green
    } catch {
        Write-Host "  Usando cmd.exe como alternativa..." -ForegroundColor Yellow
    }
}

# Verificar atual
$policy = Get-ExecutionPolicy -Scope CurrentUser
Write-Host "  Politica atual: $policy" -ForegroundColor Cyan

# ============================================================
# Verificar se node_modules existe
# ============================================================
Write-Host "`n[2] Verificando dependencias frontend..." -ForegroundColor Yellow

if (-not (Test-Path "$frontendPath\node_modules")) {
    Write-Host "  node_modules nao encontrado, instalando..." -ForegroundColor Yellow
    
    # Usar cmd.exe para contornar restricao de .ps1
    $installResult = cmd /c "cd /d `"$frontendPath`" && npm install 2>&1"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  OK Dependencias instaladas" -ForegroundColor Green
    } else {
        Write-Host "  Erro na instalacao:" -ForegroundColor Red
        Write-Host $installResult -ForegroundColor Red
    }
} else {
    Write-Host "  OK node_modules existe" -ForegroundColor Green
}

# ============================================================
# Verificar porta 3000
# ============================================================
Write-Host "`n[3] Verificando porta 3000..." -ForegroundColor Yellow

function Test-Port($port) {
    try {
        $t = New-Object System.Net.Sockets.TcpClient
        $t.Connect("localhost", $port)
        $t.Close()
        return $true
    } catch { return $false }
}

if (Test-Port 3000) {
    Write-Host "  OK Frontend ja rodando na porta 3000" -ForegroundColor Green
    Start-Process "http://localhost:3000"
    exit 0
}

# ============================================================
# METODO 1: Via cmd.exe (contorna restricao de .ps1)
# ============================================================
Write-Host "`n[4] Iniciando Next.js via cmd.exe..." -ForegroundColor Yellow

# Criar script batch temporario
$batContent = @"
@echo off
cd /d "$frontendPath"
echo Iniciando HC Tech AI Frontend...
echo Aguarde o servidor iniciar...
npm run dev
pause
"@

$batFile = "$env:TEMP\hctech_frontend.bat"
$batContent | Out-File -FilePath $batFile -Encoding ASCII

Write-Host "  Abrindo terminal do frontend..." -ForegroundColor Yellow
Start-Process "cmd.exe" -ArgumentList "/k `"$batFile`"" -WindowStyle Normal

# Aguardar frontend subir
Write-Host "  Aguardando frontend iniciar..." -NoNewline -ForegroundColor Yellow
$timeout = 60
$elapsed = 0

while (-not (Test-Port 3000) -and $elapsed -lt $timeout) {
    Start-Sleep -Seconds 2
    $elapsed += 2
    Write-Host "." -NoNewline -ForegroundColor Yellow
}

if (Test-Port 3000) {
    Write-Host " OK!" -ForegroundColor Green
} else {
    Write-Host " (ainda iniciando...)" -ForegroundColor Yellow
}

# ============================================================
# STATUS FINAL
# ============================================================
$backendOk = Test-Port 8000
$frontendOk = Test-Port 3000
$ollamaOk = Test-Port 11434

Write-Host @"

╔═══════════════════════════════════════════════════════╗
║           HC TECH AI SYSTEM v2.1                      ║
╠═══════════════════════════════════════════════════════╣
║                                                       ║
║  Backend:   $(if($backendOk){"✅ http://localhost:8000         "}else{"❌ Nao iniciado            "})║
║  Frontend:  $(if($frontendOk){"✅ http://localhost:3000         "}else{"⏳ Iniciando...            "})║
║  Ollama:    $(if($ollamaOk){"✅ http://localhost:11434        "}else{"❌ Nao iniciado            "})║
║  API Docs:  http://localhost:8000/docs        ║
║                                                       ║
║  Modelos disponiveis:                                 ║
║  🦙 llama3.2:3b  (padrao)                            ║
║  🤖 mistral:7b                                       ║
║  💻 deepseek-coder:6.7b                              ║
║  🧠 qwen2.5:7b                                       ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

if ($frontendOk -or $backendOk) {
    Write-Host "Abrindo navegador..." -ForegroundColor Green
    Start-Sleep -Seconds 2
    Start-Process "http://localhost:3000"
}