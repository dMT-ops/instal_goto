# Auto-GoToDeploy.ps1 - Instalação Automática do GoTo
# Execute com: irm "https://github.com/dMT-ops/instal_goto/raw/main/Scripts/Auto-GoToDeploy.ps1" | iex

# Configurações
$GitHubBase = "https://github.com/dMT-ops/instal_goto/raw/main"
$ToolsDir = "C:\Tools"
$ProgramasDir = "C:\Programas"
$LogFile = "C:\GoToInstall.log"

# Função de log
function Write-Log {
    param([string]$Message)
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message" | Out-File $LogFile -Append
}

# INÍCIO
Clear-Host
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "    🚀 INSTALADOR AUTOMÁTICO - GOTO MEETING" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

# 1. CRIAR PASTAS
Write-Host "📁 Preparando ambiente..." -ForegroundColor Yellow
New-Item -Path $ToolsDir, $ProgramasDir -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

# 2. DOWNLOAD PSExec
Write-Host "📥 Baixando PsExec..." -ForegroundColor Yellow
try {
    Invoke-WebRequest "$GitHubBase/Tools/PsExec.exe" -OutFile "$ToolsDir\PsExec.exe" -ErrorAction Stop
    Write-Host "   ✅ PsExec baixado" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Erro ao baixar PsExec: $($_.Exception.Message)" -ForegroundColor Red
    exit
}

# 3. DOWNLOAD GOTO
Write-Host "📥 Baixando GoTo Meeting..." -ForegroundColor Yellow
try {
    Invoke-WebRequest "$GitHubBase/Programas/GoToMeeting.exe" -OutFile "$ProgramasDir\GoToMeeting.exe" -ErrorAction Stop
    Write-Host "   ✅ GoTo Meeting baixado" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Erro ao baixar GoTo: $($_.Exception.Message)" -ForegroundColor Red
    exit
}

# 4. CARREGAR MÁQUINAS
Write-Host "📋 Obtendo lista de máquinas..." -ForegroundColor Yellow
try {
    $computers = (Invoke-WebRequest "$GitHubBase/Config/maquinas.txt").Content -split "`n" | Where-Object { $_ -and $_.Trim() }
    Write-Host "   ✅ $($computers.Count) máquinas encontradas" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Erro ao carregar lista de máquinas" -ForegroundColor Red
    exit
}

Write-Host ""
Write-Host "🔧 Iniciando instalação em $($computers.Count) máquinas..." -ForegroundColor Cyan
Write-Host ""

# 5. INSTALAÇÃO
$successCount = 0
$offlineCount = 0
$errorCount = 0

foreach ($computer in $computers) {
    $computer = $computer.Trim()
    Write-Host "⚡ $computer... " -NoNewline -ForegroundColor Yellow
    
    # Verificar se máquina está online
    if (Test-Connection -ComputerName $computer -Count 1 -Quiet -ErrorAction SilentlyContinue) {
        try {
            # Instalação silenciosa com PsExec
            $process = Start-Process -FilePath "$ToolsDir\PsExec.exe" -ArgumentList @(
                "\\$computer", "-s", "-h", "-d", "-c", "-f",
                "`"$ProgramasDir\GoToMeeting.exe`"", "/S"
            ) -PassThru -NoNewWindow -Wait -ErrorAction Stop
            
            if ($process.ExitCode -eq 0) {
                Write-Host "✅ INSTALADO" -ForegroundColor Green
                Write-Log "SUCESSO: $computer"
                $successCount++
            } else {
                Write-Host "❌ FALHA (Código: $($process.ExitCode))" -ForegroundColor Red
                Write-Log "FALHA: $computer - Código: $($process.ExitCode)"
                $errorCount++
            }
        } catch {
            Write-Host "💥 ERRO" -ForegroundColor Red
            Write-Log "ERRO: $computer - $($_.Exception.Message)"
            $errorCount++
        }
    } else {
        Write-Host "📴 OFFLINE" -ForegroundColor Gray
        Write-Log "OFFLINE: $computer"
        $offlineCount++
    }
}

# 6. RESUMO FINAL
Write-Host ""
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "           📊 RESUMO DA INSTALAÇÃO" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "✅ Instalado com sucesso: $successCount" -ForegroundColor Green
Write-Host "📴 Máquinas offline: $offlineCount" -ForegroundColor Gray
Write-Host "❌ Erros/Falhas: $errorCount" -ForegroundColor Red
Write-Host "📊 Total de máquinas: $($computers.Count)" -ForegroundColor White
Write-Host "📄 Log detalhado: $LogFile" -ForegroundColor Cyan

if ($successCount -eq $computers.Count) {
    Write-Host "🎉 TODAS AS MÁQUINAS FORAM INSTALADAS!" -ForegroundColor Green
} elseif ($successCount -gt 0) {
    Write-Host "⚠ Instalação parcialmente concluída" -ForegroundColor Yellow
} else {
    Write-Host "💥 NENHUMA INSTALAÇÃO BEM-SUCEDIDA" -ForegroundColor Red
}

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

# Aguardar entrada do usuário
Read-Host "Pressione Enter para sair"