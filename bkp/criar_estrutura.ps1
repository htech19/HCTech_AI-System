# ==============================================================================
# Script de Automação de Infraestrutura de Código - HC Tech AI System v2.1
# Autor: DevOps Engineering
# Descrição: Criação automatizada da árvore de diretórios e arquivos estruturais.
# ==============================================================================

# Força o encoding UTF-8 para evitar problemas com caracteres especiais no terminal
$OutputEncoding = [System.Text.Encoding]::UTF8

# Define o diretório raiz com base no local de execução do script
$RootPath = $PSScriptRoot
if ([string]::IsNullOrEmpty($RootPath)) {
    $RootPath = Get-Location
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host " Inicializando estrutura para: HC Tech AI System v2.1" -ForegroundColor Cyan
Write-Host " Diretorio Raiz: $RootPath" -ForegroundColor Yellow
Write-Host "======================================================================" -ForegroundColor Cyan

# 1. Lista de pastas puras (que não possuem arquivos listados diretamente na árvore)
$Directories = @(
    "data",
    "logs",
    "scripts",
    "docs",
    "frontend/src/components",
    "frontend/src/lib"
)

# 2. Lista de todos os arquivos estruturais com seus caminhos relativos
$Files = @(
    "setup.ps1",
    "iniciar.ps1",
    ".env",
    "backend/requirements.txt",
    "backend/app/main.py",
    "backend/app/config.py",
    "backend/app/database.py",
    "backend/app/api/__init__.py",
    "backend/app/api/ai.py",
    "backend/app/api/agents.py",
    "backend/app/api/tasks.py",
    "backend/app/api/seo.py",
    "backend/app/api/social.py",
    "backend/app/api/maps.py",
    "backend/app/api/knowledge.py",
    "backend/app/api/reports.py",
    "backend/app/api/metrics.py",
    "backend/app/api/automation.py",
    "backend/app/api/auth.py",
    "backend/app/agents/__init__.py",
    "backend/app/agents/base_agent.py",
    "backend/app/services/__init__.py",
    "backend/app/services/ai_service.py",
    "backend/app/services/scheduler_service.py",
    "backend/app/models/__init__.py",
    "backend/app/utils/__init__.py",
    "frontend/package.json",
    "frontend/src/app/layout.tsx"
)

# --- Execução: Criação de Pastas Puras ---
Write-Host "`n[+] Verificando e criando diretorios vazios..." -ForegroundColor Magenta
foreach ($Dir in $Directories) {
    $FullDirLength = Join-Path -Path $RootPath -ChildPath $Dir
    if (-not (Test-Path -Path $FullDirLength)) {
        New-Item -ItemType Directory -Path $FullDirLength -Force | Out-Null
        Write-Host "  [CRIADO] Pasta: $Dir" -ForegroundColor Green
    } else {
        Write-Host "  [EXISTE] Pasta: $Dir" -ForegroundColor DarkGray
    }
}

# --- Execução: Criação de Arquivos (e subpastas implícitas) ---
Write-Host "`n[+] Verificando e criando arquivos estruturais..." -ForegroundColor Magenta
foreach ($File in $Files) {
    $FullFilePath = Join-Path -Path $RootPath -ChildPath $File
    $ParentDir = Split-Path -Path $FullFilePath -Parent

    # Garante que a pasta pai do arquivo exista antes de criá-lo
    if (-not (Test-Path -Path $ParentDir)) {
        New-Item -ItemType Directory -Path $ParentDir -Force | Out-Null
    }

    # Cria o arquivo se ele não existir
    if (-not (Test-Path -Path $FullFilePath)) {
        New-Item -ItemType File -Path $FullFilePath -Force | Out-Null
        Write-Host "  [CRIADO] Arquivo: $File" -ForegroundColor Green
    } else {
        Write-Host "  [EXISTE] Arquivo: $File" -ForegroundColor DarkGray
    }
}

Write-Host "`n======================================================================" -ForegroundColor Cyan
Write-Host " Estrutura implantada com sucesso! Pronto para insercao de codigo." -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan