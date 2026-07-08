@echo off
title HC Tech AI System v2.1 - Instalador
color 0A

echo.
echo  ============================================
echo    HC TECH AI SYSTEM v2.1 - INSTALADOR
echo  ============================================
echo.
echo  Este instalador vai configurar o sistema completo
echo  nesta maquina (Git, Python, Node.js, Ollama, dependencias).
echo.
echo  Pode levar alguns minutos na primeira vez.
echo.
pause

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Instalar-HCTechAI.ps1"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo  ============================================
    echo    ERRO NA INSTALACAO - veja o log acima
    echo  ============================================
    echo.
    pause
    exit /b 1
)

echo.
echo  ============================================
echo    INSTALACAO CONCLUIDA
echo  ============================================
echo.
pause
