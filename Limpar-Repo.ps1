<#
    Limpar-Repo.ps1
    Remove do rastreamento do Git arquivos que nunca deveriam ter sido versionados
    (cache Python, build do Next.js, banco SQLite, pasta de backup antiga).
    NAO apaga os arquivos do disco, apenas para de rastrear no Git.
    Rode na raiz do projeto.
#>

$ErrorActionPreference = "Stop"

Write-Host "Removendo do rastreamento do Git (mantendo arquivos no disco)..." -ForegroundColor Yellow

git rm -r --cached "backend/app/__pycache__" 2>$null
git rm -r --cached "backend/app/api/__pycache__" 2>$null
git rm -r --cached "backend/app/services/__pycache__" 2>$null
git rm -r --cached "frontend/.next" 2>$null
git rm --cached "data/hctech.db" 2>$null
git rm -r --cached "bkp" 2>$null

Write-Host "Arquivos desrastreados. Substitua o .gitignore pelo corrigido e faca commit:" -ForegroundColor Green
Write-Host "  git add .gitignore" -ForegroundColor Cyan
Write-Host "  git add -A" -ForegroundColor Cyan
Write-Host "  git commit -m 'chore: remove cache, build e backup do rastreamento do git'" -ForegroundColor Cyan
Write-Host "  git push" -ForegroundColor Cyan
