# Auto-GoToDeploy.ps1 - Instalação Automática do GoTo
# Execute com: irm "https://github.com/dMT-ops/instal_goto/raw/main/Scripts/Auto-GoToDeploy.ps1" | iex

# Configurações
$GitHubBase = "https://github.com/dMT-ops/instal_goto/raw/main"
$ProgramasDir = "C:\Programas"
$LogFile = "C:\GoToInstall.log"

# Função de log
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    "$timestamp - $Message" | Out-File $LogFile -Append
    Write-Host "$timestamp - $Message" -ForegroundColor Gray
}

# INÍCIO
Clear-Host
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "    🚀 INSTALADOR AUTOMÁTICO - GOTO MEETING" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

try {
    # 1. CRIAR PASTAS
    Write-Host "📁 Preparando ambiente..." -ForegroundColor Yellow
    Write-Log "Iniciando preparação do ambiente"
    New-Item -Path $ProgramasDir -ItemType Directory -Force -ErrorAction Stop
    Write-Host "   ✅ Pasta criada: $ProgramasDir" -ForegroundColor Green

    # 2. DOWNLOAD GOTO
    Write-Host "📥 Baixando GoTo Meeting..." -ForegroundColor Yellow
    Write-Log "Iniciando download do GoTo Meeting"
    try {
        Invoke-WebRequest "$GitHubBase/Programas/GoToSetup.exe" -OutFile "$ProgramasDir\GoToSetup.exe" -ErrorAction Stop
        Write-Host "   ✅ GoTo Meeting baixado com sucesso" -ForegroundColor Green
        Write-Log "Download do GoTo Meeting concluído"
    } catch {
        Write-Host "   ❌ Erro ao baixar GoTo: $($_.Exception.Message)" -ForegroundColor Red
        Write-Log "ERRO no download: $($_.Exception.Message)"
        throw
    }

    # 3. CARREGAR MÁQUINAS
    Write-Host "📋 Obtendo lista de máquinas..." -ForegroundColor Yellow
    Write-Log "Carregando lista de máquinas"
    try {
        $computers = (Invoke-WebRequest "$GitHubBase/Config/maquinas.txt").Content -split "`n" | Where-Object { $_ -and $_.Trim() }
        Write-Host "   ✅ $($computers.Count) máquinas encontradas" -ForegroundColor Green
        Write-Log "Lista de máquinas carregada: $($computers.Count) máquinas"
    } catch {
        Write-Host "   ❌ Erro ao carregar lista de máquinas: $($_.Exception.Message)" -ForegroundColor Red
        Write-Log "ERRO ao carregar máquinas: $($_.Exception.Message)"
        throw
    }

    Write-Host ""
    Write-Host "🔧 Iniciando instalação em $($computers.Count) máquinas..." -ForegroundColor Cyan
    Write-Log "Iniciando processo de instalação em $($computers.Count) máquinas"
    Write-Host ""

    # 4. INSTALAÇÃO (USANDO PSExec QUE VOCÊ JÁ TEM)
    $successCount = 0
    $offlineCount = 0
    $errorCount = 0

    foreach ($computer in $computers) {
        $computer = $computer.Trim()
        if (-not $computer) { continue }
        
        Write-Host "⚡ Processando $computer... " -NoNewline -ForegroundColor Yellow
        Write-Log "Processando máquina: $computer"
        
        # Verificar se máquina está online
        Write-Host "[Teste Conexão...] " -NoNewline -ForegroundColor Gray
        if (Test-Connection -ComputerName $computer -Count 2 -Quiet -ErrorAction SilentlyContinue) {
            Write-Host "[Online] " -NoNewline -ForegroundColor Green
            Write-Log "$computer - Máquina online"
            
            try {
                Write-Host "[Instalando...] " -NoNewline -ForegroundColor Gray
                Write-Log "$computer - Iniciando instalação com PsExec"
                
                # Instalação silenciosa com PsExec
                $process = Start-Process -FilePath "PsExec.exe" -ArgumentList @(
                    "\\$computer",
                    "-s",
                    "-h",
                    "-d",
                    "-c",
                    "-f",
                    "`"$ProgramasDir\GoToSetup.exe`"",
                    "/S"
                ) -PassThru -NoNewWindow -Wait -ErrorAction Stop
                
                Write-Log "$computer - PsExec finalizado com código: $($process.ExitCode)"
                
                if ($process.ExitCode -eq 0) {
                    Write-Host "✅ INSTALADO" -ForegroundColor Green
                    Write-Log "SUCESSO: $computer - GoTo instalado com sucesso"
                    $successCount++
                } else {
                    Write-Host "❌ FALHA (Código: $($process.ExitCode))" -ForegroundColor Red
                    Write-Log "FALHA: $computer - Código de saída: $($process.ExitCode)"
                    $errorCount++
                }
            } catch {
                Write-Host "💥 ERRO: $($_.Exception.Message)" -ForegroundColor Red
                Write-Log "ERRO: $computer - $($_.Exception.Message)"
                Write-Log "ERRO Detalhado: $($_.Exception.StackTrace)"
                $errorCount++
            }
        } else {
            Write-Host "📴 OFFLINE" -ForegroundColor Gray
            Write-Log "OFFLINE: $computer - Máquina não respondeu ao ping"
            $offlineCount++
        }
    }

} catch {
    Write-Host ""
    Write-Host "💥 ERRO CRÍTICO: $($_.Exception.Message)" -ForegroundColor Red
    Write-Log "ERRO CRÍTICO: $($_.Exception.Message)"
    Write-Log "STACK TRACE: $($_.Exception.StackTrace)"
}

# 5. RESUMO FINAL (SEMPRE EXECUTADO)
Write-Host ""
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "           📊 RESUMO DA INSTALAÇÃO" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "✅ Instalado com sucesso: $successCount" -ForegroundColor Green
Write-Host "📴 Máquinas offline: $offlineCount" -ForegroundColor Gray
Write-Host "❌ Erros/Falhas: $errorCount" -ForegroundColor Red
Write-Host "📊 Total de máquinas: $($computers.Count)" -ForegroundColor White
Write-Host "📄 Log detalhado: $LogFile" -ForegroundColor Cyan

Write-Log "=== RESUMO FINAL ==="
Write-Log "Sucessos: $successCount"
Write-Log "Offline: $offlineCount"
Write-Log "Erros: $errorCount"
Write-Log "Total: $($computers.Count)"

if ($successCount -eq $computers.Count) {
    Write-Host "🎉 TODAS AS MÁQUINAS FORAM INSTALADAS!" -ForegroundColor Green
    Write-Log "STATUS: Todas as máquinas instaladas com sucesso"
} elseif ($successCount -gt 0) {
    Write-Host "⚠ Instalação parcialmente concluída" -ForegroundColor Yellow
    Write-Log "STATUS: Instalação parcialmente concluída"
} else {
    Write-Host "💥 NENHUMA INSTALAÇÃO BEM-SUCEDIDA" -ForegroundColor Red
    Write-Log "STATUS: Nenhuma instalação bem-sucedida"
}

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

# Aguardar entrada do usuário (NUNCA FECHA SOZINHO)
Write-Host "Pressione Enter para finalizar..." -ForegroundColor Yellow
Read-Host
