<#
    Instalar-HCTechAI.ps1
    Instalador completo do HC Tech AI System v2.1 para maquina Windows 10/11 (25H2) limpa.
    Instala pre-requisitos via winget (Git, Python 3.12, Node.js LTS, Ollama),
    clona o repositorio, instala dependencias, cria .env padrao, baixa o modelo
    Ollama padrao e deixa pronto para rodar com iniciar_completo.bat.

    Uso:
        .\Instalar-HCTechAI.ps1
        .\Instalar-HCTechAI.ps1 -DestinoPath "D:\Projetos\HCTechAI"
        .\Instalar-HCTechAI.ps1 -PularOllama
        .\Instalar-HCTechAI.ps1 -IniciarAoFinal
#>

param(
    [string]$DestinoPath = (Join-Path (Get-Location).Path "HCTech_AI-System"),
    [string]$RepoUrl = "https://github.com/htech19/HCTech_AI-System.git",
    [string]$OllamaModel = "llama3.2:3b",
    [switch]$PularOllama,
    [switch]$IniciarAoFinal
)

$ErrorActionPreference = "Stop"
$LogFile = Join-Path $env:TEMP ("instalar-hctechai_{0:yyyyMMdd_HHmmss}.log" -f (Get-Date))
$FalhasCriticas = 0

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] [$Level] $Message"
    Write-Host $line
    Add-Content -Path $LogFile -Value $line -Encoding ASCII
}

function Test-CommandExists {
    param([string]$Command)
    $null = Get-Command $Command -ErrorAction SilentlyContinue
    return $?
}

function Install-ViaWinget {
    param([string]$Nome, [string]$WingetId, [string]$Comando)

    if (Test-CommandExists $Comando) {
        Write-Log "$Nome ja instalado, pulando."
        return $true
    }

    if (-not (Test-CommandExists "winget")) {
        Write-Log "winget nao disponivel neste sistema. Instale $Nome manualmente." "ERROR"
        return $false
    }

    Write-Log "Instalando $Nome via winget ($WingetId)..."
    try {
        winget install --id $WingetId -e --accept-source-agreements --accept-package-agreements --silent
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne -1978335189) {
            throw "winget retornou codigo $LASTEXITCODE"
        }
        Write-Log "$Nome instalado com sucesso."
        return $true
    } catch {
        Write-Log "Falha ao instalar $Nome : $($_.Exception.Message)" "ERROR"
        return $false
    }
}

Write-Log "=== Inicio da instalacao do HC Tech AI System v2.1 ==="
Write-Log "Destino: $DestinoPath"

# ===== 1. Verificar sistema operacional =====
$osInfo = Get-CimInstance Win32_OperatingSystem
Write-Log "Sistema operacional detectado: $($osInfo.Caption) (build $($osInfo.BuildNumber))"

# ===== 2. Pre-requisitos via winget =====
Write-Log "--- Verificando pre-requisitos ---"

$gitOk = Install-ViaWinget -Nome "Git" -WingetId "Git.Git" -Comando "git"
if (-not $gitOk) { $FalhasCriticas++ }

$pythonOk = Install-ViaWinget -Nome "Python 3.12" -WingetId "Python.Python.3.12" -Comando "python"
if (-not $pythonOk) { $FalhasCriticas++ }

$nodeOk = Install-ViaWinget -Nome "Node.js LTS" -WingetId "OpenJS.NodeJS.LTS" -Comando "node"
if (-not $nodeOk) { $FalhasCriticas++ }

if (-not $PularOllama) {
    $ollamaOk = Install-ViaWinget -Nome "Ollama" -WingetId "Ollama.Ollama" -Comando "ollama"
    if (-not $ollamaOk) { Write-Log "Ollama nao instalado - IA local ficara indisponivel ate instalar manualmente." "WARN" }
}

if ($FalhasCriticas -gt 0) {
    Write-Log "Pre-requisitos criticos (Git/Python/Node) ausentes. Abortando." "ERROR"
    Write-Log "Reabra o PowerShell (para atualizar o PATH) e rode o script novamente." "ERROR"
    exit 1
}

# Recarregar PATH da sessao atual (winget pode ter alterado o PATH do sistema)
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# ===== 3. Clonar ou atualizar o repositorio =====
Write-Log "--- Repositorio ---"

if (Test-Path (Join-Path $DestinoPath ".git")) {
    Write-Log "Repositorio ja existe em $DestinoPath, atualizando (git pull)..."
    try {
        Set-Location -LiteralPath $DestinoPath
        git pull
        Write-Log "Repositorio atualizado."
    } catch {
        Write-Log "Falha ao atualizar repositorio: $($_.Exception.Message)" "ERROR"
        exit 1
    }
} else {
    Write-Log "Clonando repositorio para $DestinoPath..."
    try {
        git clone $RepoUrl $DestinoPath
        if ($LASTEXITCODE -ne 0) { throw "git clone retornou codigo $LASTEXITCODE" }
        Write-Log "Repositorio clonado."
    } catch {
        Write-Log "Falha ao clonar repositorio: $($_.Exception.Message)" "ERROR"
        exit 1
    }
}

Set-Location -LiteralPath $DestinoPath

# ===== 4. Dependencias Python (backend) =====
Write-Log "--- Backend (Python/FastAPI) ---"
try {
    Set-Location -LiteralPath (Join-Path $DestinoPath "backend")
    python -m pip install --upgrade pip --quiet
    python -m pip install -r requirements.txt --quiet
    if ($LASTEXITCODE -ne 0) { throw "pip install retornou codigo $LASTEXITCODE" }
    Write-Log "Dependencias Python instaladas."
} catch {
    Write-Log "Falha ao instalar dependencias Python: $($_.Exception.Message)" "ERROR"
    exit 1
}

# ===== 5. Dependencias Node (frontend) =====
Write-Log "--- Frontend (Next.js) ---"
try {
    Set-Location -LiteralPath (Join-Path $DestinoPath "frontend")
    npm install --silent
    if ($LASTEXITCODE -ne 0) { throw "npm install retornou codigo $LASTEXITCODE" }
    Write-Log "Dependencias npm instaladas."
} catch {
    Write-Log "Falha ao instalar dependencias npm: $($_.Exception.Message)" "ERROR"
    exit 1
}

Set-Location -LiteralPath $DestinoPath

# ===== 6. Pasta de dados =====
$dataPath = Join-Path $DestinoPath "data"
if (-not (Test-Path -LiteralPath $dataPath)) {
    New-Item -ItemType Directory -Path $dataPath -Force | Out-Null
    Write-Log "Pasta 'data' criada."
}

# ===== 7. Arquivo .env padrao =====
$envPath = Join-Path $DestinoPath ".env"
if (-not (Test-Path -LiteralPath $envPath)) {
    Write-Log "Criando .env padrao..."
    $envContent = @'
OLLAMA_API_URL=http://localhost:11434
OLLAMA_MODEL=llama3.2:3b
OLLAMA_TIMEOUT=120

OPENAI_API_KEY=
OPENAI_MODEL=gpt-4o-mini

ANTHROPIC_API_KEY=
ANTHROPIC_MODEL=claude-3-haiku-20240307

DEFAULT_AI_PROVIDER=ollama

DATABASE_URL=sqlite+aiosqlite:///./data/hctech.db
SECRET_KEY=change-me-in-production

BACKEND_PORT=8000
FRONTEND_PORT=3000

NEXT_PUBLIC_BACKEND_URL=http://localhost:8000
'@
    Set-Content -Path $envPath -Value $envContent -Encoding ASCII -NoNewline
    Write-Log ".env criado com valores padrao. Edite para adicionar OPENAI_API_KEY/ANTHROPIC_API_KEY se quiser usar IA em nuvem."
} else {
    Write-Log ".env ja existe, mantido sem alteracoes." "WARN"
}

# ===== 8. Modelo Ollama padrao =====
if (-not $PularOllama) {
    Write-Log "--- Modelo Ollama ---"
    if (Test-CommandExists "ollama") {
        try {
            Write-Log "Baixando modelo $OllamaModel (pode demorar alguns minutos)..."
            ollama pull $OllamaModel
            if ($LASTEXITCODE -ne 0) { throw "ollama pull retornou codigo $LASTEXITCODE" }
            Write-Log "Modelo $OllamaModel disponivel."
        } catch {
            Write-Log "Falha ao baixar modelo Ollama: $($_.Exception.Message)" "WARN"
        }
    } else {
        Write-Log "Ollama nao encontrado no PATH. Pulando download do modelo." "WARN"
    }
}

# ===== 9. Resumo =====
Write-Log "=== Instalacao concluida com sucesso ==="
Write-Log "Projeto em: $DestinoPath"
Write-Log "Para iniciar o sistema:"
Write-Log "  cd `"$DestinoPath`""
Write-Log "  .\iniciar_completo.bat"
Write-Log "Interface web: http://localhost:3000"
Write-Log "API:           http://localhost:8000"
Write-Log "Log completo em: $LogFile"

if ($IniciarAoFinal) {
    Write-Log "Iniciando o sistema automaticamente (-IniciarAoFinal)..."
    Set-Location -LiteralPath $DestinoPath
    & ".\iniciar_completo.bat"
}
