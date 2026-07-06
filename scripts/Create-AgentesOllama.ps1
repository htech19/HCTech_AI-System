Write-Host "Iniciando a criacao dos agentes personalizados no Ollama..." -ForegroundColor Cyan

# Definindo o caminho da pasta onde estao os Modelfiles
$modelfileDir = "skills\treinamento-modelos-ollama\modelfiles"

# Lista de agentes a serem criados com base nos Modelfiles existentes
$agentes = @(
    @{ Name = "hc-desenvolvedor"; File = "Modelfile.hc-desenvolvedor" },
    @{ Name = "hc-analista"; File = "Modelfile.hc-analista" },
    @{ Name = "hc-tester"; File = "Modelfile.hc-tester" },
    @{ Name = "hc-scrum-master"; File = "Modelfile.hc-scrum-master" },
    @{ Name = "hc-product-owner"; File = "Modelfile.hc-product-owner" }
)

foreach ($agente in $agentes) {
    $filePath = Join-Path $modelfileDir $agente.File
    if (Test-Path $filePath) {
        Write-Host "Criando agente: $($agente.Name) usando $filePath..." -ForegroundColor Yellow
        ollama create $agente.Name -f $filePath
    } else {
        Write-Host "Aviso: Modelfile nao encontrado em $filePath" -ForegroundColor Red
    }
}

Write-Host "Processo concluido!" -ForegroundColor Green
