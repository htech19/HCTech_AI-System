<#
    Validar-Sync.ps1
    Compara o estado local do repositorio com o GitHub (origin/main).
    Mostra: commits locais nao enviados, commits remotos nao baixados,
    arquivos modificados/nao rastreados, e se a arvore de trabalho esta limpa.
    Nao altera nada - apenas diagnostico.
#>

param(
    [string]$Branch = "main"
)

$ErrorActionPreference = "Stop"

function Write-Secao {
    param([string]$Titulo)
    Write-Host ""
    Write-Host "=== $Titulo ===" -ForegroundColor Cyan
}

if (-not (Test-Path -LiteralPath ".git")) {
    Write-Host "Nao e um repositorio Git. Rode este script na raiz do projeto." -ForegroundColor Red
    exit 1
}

Write-Secao "Atualizando referencias remotas (git fetch)"
git fetch origin 2>&1 | ForEach-Object { Write-Host $_ }

Write-Secao "Branch atual"
$branchAtual = git rev-parse --abbrev-ref HEAD
Write-Host "Branch: $branchAtual"
if ($branchAtual -ne $Branch) {
    Write-Host "Aviso: branch atual difere do parametro esperado ($Branch)." -ForegroundColor Yellow
}

Write-Secao "Commits locais x remoto"
$local = git rev-parse HEAD
$remoto = git rev-parse "origin/$Branch"
Write-Host "Local:  $local"
Write-Host "Remoto: $remoto"

if ($local -eq $remoto) {
    Write-Host "Local e remoto estao IDENTICOS." -ForegroundColor Green
} else {
    $ahead = git rev-list --count "origin/$Branch..HEAD"
    $behind = git rev-list --count "HEAD..origin/$Branch"

    if ([int]$ahead -gt 0) {
        Write-Host "Voce esta $ahead commit(s) A FRENTE do remoto (precisa fazer 'git push'):" -ForegroundColor Yellow
        git log "origin/$Branch..HEAD" --oneline
    }
    if ([int]$behind -gt 0) {
        Write-Host "Voce esta $behind commit(s) ATRAS do remoto (precisa fazer 'git pull'):" -ForegroundColor Yellow
        git log "HEAD..origin/$Branch" --oneline
    }
}

Write-Secao "Arquivos modificados / nao rastreados localmente"
$status = git status --porcelain
if ([string]::IsNullOrWhiteSpace($status)) {
    Write-Host "Arvore de trabalho limpa - nada pendente de commit." -ForegroundColor Green
} else {
    Write-Host "Existem alteracoes locais nao commitadas:" -ForegroundColor Yellow
    git status --short
}

Write-Secao "Resumo"
$tudoOk = ($local -eq $remoto) -and [string]::IsNullOrWhiteSpace($status)
if ($tudoOk) {
    Write-Host "SINCRONIZADO: local e GitHub estao identicos, sem pendencias." -ForegroundColor Green
} else {
    Write-Host "NAO SINCRONIZADO: veja as secoes acima para o que falta enviar/baixar/commitar." -ForegroundColor Red
}
