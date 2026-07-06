@echo off
title HC Tech AI System v2.1
color 0B

echo.
echo ╔══════════════════════════════════════════╗
echo ║      HC TECH AI SYSTEM v2.1              ║
echo ║      Iniciando todos os servicos...      ║
echo ╚══════════════════════════════════════════╝
echo.

set ROOT=%~dp0
if "%ROOT:~-1%"=="\" set ROOT=%ROOT:~0,-1%

:: Verificar Ollama
echo [1] Verificando Ollama...
curl -s http://localhost:11434/api/tags >nul 2>&1
if %errorlevel%==0 (
    echo     OK Ollama ja rodando
) else (
    echo     Iniciando Ollama...
    start /min "" ollama serve
    timeout /t 3 /nobreak >nul
)

:: Backend Python (em nova janela)
echo.
echo [2] Iniciando Backend Python...
curl -s http://localhost:8000/api/health >nul 2>&1
if %errorlevel%==0 (
    echo     OK Backend ja rodando
) else (
    start "HC Tech Backend" cmd /k "cd /d "%ROOT%\backend" && python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload"
    echo     Aguardando backend...
    timeout /t 5 /nobreak >nul
)

:: Frontend Next.js (em nova janela)
echo.
echo [3] Iniciando Frontend Next.js...
curl -s http://localhost:3000 >nul 2>&1
if %errorlevel%==0 (
    echo     OK Frontend ja rodando
) else (
    start "HC Tech Frontend" cmd /k "cd /d "%ROOT%\frontend" && npm run dev"
    echo     Aguardando frontend ^(pode demorar 30s^)...
    timeout /t 15 /nobreak >nul
)

echo.
echo ╔══════════════════════════════════════════╗
echo ║  Sistema iniciando...                    ║
echo ║                                          ║
echo ║  Interface:  http://localhost:3000       ║
echo ║  API:        http://localhost:8000       ║
echo ║  Docs:       http://localhost:8000/docs  ║
echo ║  Ollama:     http://localhost:11434      ║
echo ╚══════════════════════════════════════════╝
echo.

:: Aguardar e abrir navegador
timeout /t 10 /nobreak >nul
start "" "http://localhost:3000"

echo Pressione qualquer tecla para sair deste script...
echo (As janelas do backend e frontend continuarao abertas)
pause >nul