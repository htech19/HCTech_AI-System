<#
    Sync-ToGitHub.ps1
    Sincroniza uma pasta local para um novo repositorio remoto no GitHub.
    Requisitos: Git instalado, GitHub CLI (gh) instalado e autenticado (gh auth login).
    Uso:
        .\Sync-ToGitHub.ps1
        .\Sync-ToGitHub.ps1 -LocalPath "C:\pasta" -RepoName "meu-repo" -Visibility private
#>

param(
    [string]$LocalPath = "C:\Users\hunlock\Documents\LOJA\Agente_Sistemas\Arena IA - Claude Sonnet",
    [string]$RepoName  = "arena-ia-claude-sonnet",
    [ValidateSet("private","public")]
    [string]$Visibility = "private",
    [string]$CommitMessage = "Sync inicial do projeto"
)

$ErrorActionPreference = "Stop"
$LogFile = Join-Path $env:TEMP ("sync-to-github_{0:yyyyMMdd_HHmmss}.log" -f (Get-Date))

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

function Exit-WithError {
    param([string]$Message)
    Write-Log -Message $Message -Level "ERROR"
    Write-Log -Message "Log completo em: $LogFile" -Level "INFO"
    exit 1
}

Write-Log "=== Inicio da sincronizacao ==="
Write-Log "Pasta local: $LocalPath"
Write-Log "Nome do repositorio: $RepoName"
Write-Log "Visibilidade: $Visibility"

if (-not (Test-Path -LiteralPath $LocalPath)) {
    Exit-WithError "Pasta local nao encontrada: $LocalPath"
}

if (-not (Test-CommandExists "git")) {
    Exit-WithError "Git nao encontrado no PATH. Instale o Git antes de continuar."
}

if (-not (Test-CommandExists "gh")) {
    Exit-WithError "GitHub CLI (gh) nao encontrado no PATH. Instale em https://cli.github.com"
}

try {
    $authCheck = gh auth status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Exit-WithError "GitHub CLI nao autenticado. Execute: gh auth login"
    }
    Write-Log "Autenticacao gh confirmada."
} catch {
    Exit-WithError "Falha ao verificar autenticacao do gh: $($_.Exception.Message)"
}

try {
    Set-Location -LiteralPath $LocalPath
    Write-Log "Diretorio de trabalho definido: $LocalPath"
} catch {
    Exit-WithError "Falha ao acessar a pasta local: $($_.Exception.Message)"
}

try {
    if (-not (Test-Path -LiteralPath ".git")) {
        git init | Out-Null
        Write-Log "Repositorio git inicializado."
    } else {
        Write-Log "Repositorio git ja existente na pasta, reaproveitando."
    }
} catch {
    Exit-WithError "Falha no git init: $($_.Exception.Message)"
}

try {
    git branch -M main 2>$null
    Write-Log "Branch principal definida como main."
} catch {
    Write-Log "Aviso: falha ao renomear branch (pode ja estar correta)." "WARN"
}

if (-not (Test-Path -LiteralPath ".gitignore")) {
    try {
        @"
node_modules/
.env
.env.local
*.log
dist/
build/
.DS_Store
Thumbs.db
"@ | Out-File -FilePath ".gitignore" -Encoding ASCII
        Write-Log "Arquivo .gitignore criado com regras padrao."
    } catch {
        Write-Log "Aviso: falha ao criar .gitignore: $($_.Exception.Message)" "WARN"
    }
} else {
    Write-Log ".gitignore ja existente, mantido sem alteracoes."
}

try {
    git add -A
    Write-Log "Arquivos adicionados ao stage."
} catch {
    Exit-WithError "Falha no git add: $($_.Exception.Message)"
}

try {
    $statusOutput = git status --porcelain
    if ([string]::IsNullOrWhiteSpace($statusOutput)) {
        Write-Log "Nenhuma alteracao para commit." "WARN"
    } else {
        git commit -m "$CommitMessage" | Out-Null
        Write-Log "Commit criado: $CommitMessage"
    }
} catch {
    Exit-WithError "Falha no git commit: $($_.Exception.Message)"
}

$remoteExists = git remote 2>$null | Select-String -Pattern "^origin$" -Quiet

if ($remoteExists) {
    Write-Log "Remote 'origin' ja configurado. Tentando push direto."
    try {
        git push -u origin main
        Write-Log "Push concluido com sucesso via remote existente."
    } catch {
        Exit-WithError "Falha no push com remote existente: $($_.Exception.Message)"
    }
} else {
    try {
        Write-Log "Criando repositorio remoto no GitHub via gh CLI..."
        $visFlag = "--$Visibility"
        gh repo create $RepoName $visFlag --source=. --remote=origin --push
        if ($LASTEXITCODE -ne 0) {
            Exit-WithError "Falha ao criar/push repositorio via gh repo create."
        }
        Write-Log "Repositorio '$RepoName' criado e sincronizado com sucesso ($Visibility)."
    } catch {
        Exit-WithError "Falha ao criar repositorio no GitHub: $($_.Exception.Message)"
    }
}

Write-Log "=== Sincronizacao concluida com sucesso ==="
Write-Log "Log completo em: $LogFile"
