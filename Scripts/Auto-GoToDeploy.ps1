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

# Função para verificar se o GoTo está instalado
function Test-GoToInstalled {
    $installPaths = @(
        "C:\Program Files\GoTo\*",
        "C:\Program Files (x86)\GoTo\*",
        "$env:LOCALAPPDATA\GoTo\*",
        "$env:PROGRAMFILES\GoTo\*",
        "$env:PROGRAMFILES(X86)\GoTo\*"
    )
    
    foreach ($path in $installPaths) {
        if (Test-Path $path) {
            Write-Log "GoTo encontrado em: $path"
            return $true
        }
    }
    return $false
}

# Função para encontrar e executar o GoTo Meeting
function Start-GoToMeeting {
    Write-Host "🚀 Iniciando GoTo Meeting..." -ForegroundColor Yellow
    Write-Log "Tentando iniciar GoTo Meeting"
    
    # Lista de possíveis caminhos do executável
    $gotoPaths = @(
        "C:\Program Files\GoTo\G2M\G2MStart.exe",
        "C:\Program Files (x86)\GoTo\G2M\G2MStart.exe",
        "$env:PROGRAMFILES\GoTo\G2M\G2MStart.exe",
        "$env:PROGRAMFILES(X86)\GoTo\G2M\G2MStart.exe",
        "$env:LOCALAPPDATA\GoTo\G2M\G2MStart.exe"
    )
    
    # Buscar em todos os caminhos possíveis
    foreach ($path in $gotoPaths) {
        if (Test-Path $path) {
            try {
                Write-Host "   📍 Executando: $path" -ForegroundColor Gray
                Write-Log "Executando GoTo: $path"
                
                # Executar diretamente sem confirmações
                Start-Process -FilePath $path -ErrorAction Stop
                Write-Host "   ✅ GoTo Meeting iniciado com sucesso!" -ForegroundColor Green
                Write-Log "SUCESSO: GoTo Meeting iniciado"
                return $true
            } catch {
                Write-Host "   ❌ Erro ao iniciar: $($_.Exception.Message)" -ForegroundColor Red
                Write-Log "ERRO ao iniciar GoTo: $($_.Exception.Message)"
            }
        }
    }
    
    Write-Host "   ❌ Não foi possível iniciar o GoTo Meeting automaticamente" -ForegroundColor Red
    Write-Log "FALHA: Não foi possível iniciar GoTo Meeting automaticamente"
    return $false
}

# Função para instalar localmente
function Install-GoToLocal {
    Write-Host ""
    Write-Host "🔧 INSTALANDO GOTO LOCALMENTE..." -ForegroundColor Cyan
    Write-Log "Iniciando instalação local do GoTo"
    
    $localSetup = "$ProgramasDir\GoToSetup.exe"
    
    if (-not (Test-Path $localSetup)) {
        Write-Host "❌ Arquivo de instalação não encontrado: $localSetup" -ForegroundColor Red
        Write-Log "ERRO: Arquivo de instalação local não encontrado"
        return $false
    }
    
    try {
        Write-Host "📦 Executando instalação local SILENCIOSA..." -ForegroundColor Yellow
        Write-Log "Executando instalação local: $localSetup /S"
        
        # Executar instalação local completamente silenciosa
        $process = Start-Process -FilePath $localSetup -ArgumentList "/S" -Wait -PassThru -NoNewWindow
        
        Write-Log "Instalação local finalizada com código: $($process.ExitCode)"
        
        # Aguardar um pouco mais para a instalação completar totalmente
        Write-Host "   ⏳ Aguardando finalização da instalação..." -ForegroundColor Gray
        Start-Sleep -Seconds 15
        
        # Verificar se foi instalado com sucesso
        $isInstalled = Test-GoToInstalled
        
        if ($process.ExitCode -eq 0 -or $isInstalled) {
            Write-Host "✅ GoTo instalado com SUCESSO nesta máquina" -ForegroundColor Green
            Write-Log "SUCESSO: Instalação local concluída"
            
            # Aguardar mais um pouco para o sistema registrar tudo
            Start-Sleep -Seconds 5
            
            # AGORA EXECUTA O GOTO AUTOMATICAMENTE
            Write-Host ""
            Write-Host "🔍 INICIANDO GOTO AUTOMATICAMENTE..." -ForegroundColor Cyan
            $executionResult = Start-GoToMeeting
            
            if ($executionResult) {
                Write-Host "🎉 CONFIRMADO: GoTo Meeting instalado e executado com sucesso!" -ForegroundColor Green
                Write-Log "CONFIRMAÇÃO: GoTo instalado e executado com sucesso"
            } else {
                Write-Host "⚠ INSTALADO mas não foi possível executar automaticamente" -ForegroundColor Yellow
                Write-Host "   💡 Tente abrir manualmente o GoTo Meeting" -ForegroundColor Gray
                Write-Log "AVISO: GoTo instalado mas não executado automaticamente"
            }
            
            return $true
        } else {
            Write-Host "❌ Falha na instalação local. Código: $($process.ExitCode)" -ForegroundColor Red
            Write-Log "FALHA: Instalação local - Código: $($process.ExitCode)"
            return $false
        }
    } catch {
        Write-Host "💥 ERRO na instalação local: $($_.Exception.Message)" -ForegroundColor Red
        Write-Log "ERRO na instalação local: $($_.Exception.Message)"
        return $false
    }
}

# Função para transferir arquivos para máquinas remotas (ÁREA DE TRABALHO)
function Transfer-FilesToRemote {
    param([string]$ComputerName)
    
    try {
        Write-Log "Iniciando transferência de arquivos para: $ComputerName"
        
        # Criar pasta Programas na máquina remota
        $remoteProgramasDir = "\\$ComputerName\C$\Programas"
        
        Write-Host "   📁 Criando pasta Programas..." -ForegroundColor Gray
        New-Item -Path $remoteProgramasDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
        
        # Copiar arquivo para pasta Programas
        Write-Host "   📤 Copiando para Programas..." -ForegroundColor Gray
        Copy-Item "$ProgramasDir\GoToSetup.exe" "$remoteProgramasDir\GoToSetup.exe" -Force -ErrorAction Stop
        
        # AGORA COPIAR PARA A ÁREA DE TRABALHO
        Write-Host "   🖥️  Copiando para Área de Trabalho..." -ForegroundColor Gray
        
        # Encontrar a pasta Desktop/Área de Trabalho
        $desktopPaths = @(
            "\\$ComputerName\C$\Users\Public\Desktop",
            "\\$ComputerName\C$\Users\*\Desktop",
            "\\$ComputerName\C$\Documents and Settings\All Users\Desktop"
        )
        
        $desktopFound = $false
        
        foreach ($desktopPath in $desktopPaths) {
            $resolvedPaths = Get-ChildItem -Path $desktopPath -ErrorAction SilentlyContinue
            foreach ($path in $resolvedPaths) {
                if (Test-Path $path.FullName) {
                    $desktopDir = $path.FullName
                    Copy-Item "$ProgramasDir\GoToSetup.exe" "$desktopDir\GoToSetup.exe" -Force -ErrorAction SilentlyContinue
                    
                    if (Test-Path "$desktopDir\GoToSetup.exe") {
                        Write-Host "   ✅ Copiado para Área de Trabalho" -ForegroundColor Green
                        Write-Log "SUCESSO: Arquivo copiado para Área de Trabalho em $ComputerName"
                        $desktopFound = $true
                        break
                    }
                }
            }
            if ($desktopFound) { break }
        }
        
        # Verificar se pelo menos o arquivo foi copiado para Programas
        if (Test-Path "$remoteProgramasDir\GoToSetup.exe") {
            if (-not $desktopFound) {
                Write-Host "   ⚠ Copiado apenas para Programas" -ForegroundColor Yellow
                Write-Log "AVISO: Arquivo copiado apenas para Programas em $ComputerName"
            }
            Write-Log "SUCESSO: Arquivo transferido para $ComputerName"
            return $true
        } else {
            Write-Host "   ❌ Falha na transferência" -ForegroundColor Red
            Write-Log "FALHA: Arquivo não encontrado após transferência em $ComputerName"
            return $false
        }
        
    } catch {
        Write-Host "   ❌ Erro na transferência: $($_.Exception.Message)" -ForegroundColor Red
        Write-Log "ERRO na transferência para $ComputerName : $($_.Exception.Message)"
        return $false
    }
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

    # 3. INSTALAÇÃO LOCAL PRIMEIRO
    $localInstallResult = Install-GoToLocal
    
    Write-Host ""
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "📍 RESULTADO DA INSTALAÇÃO LOCAL: " -NoNewline -ForegroundColor Cyan
    if ($localInstallResult) {
        Write-Host "SUCESSO COMPLETO ✅" -ForegroundColor Green
        Write-Host "   ✓ GoTo instalado silenciosamente" -ForegroundColor Green
        Write-Host "   ✓ GoTo executado automaticamente" -ForegroundColor Green
    } else {
        Write-Host "FALHA ❌" -ForegroundColor Red
    }
    Write-Host "===============================================" -ForegroundColor Cyan
    
    # Perguntar se deseja continuar com transferência remota
    Write-Host ""
    Write-Host "⏸️  Deseja transferir o instalador para outras máquinas?" -ForegroundColor Yellow
    Write-Host "   (O arquivo será copiado para C:\Programas\ e Área de Trabalho)" -ForegroundColor Gray
    $continuar = Read-Host "Digite 'S' para continuar ou 'N' para parar (S/N)"
    
    if ($continuar -notmatch '^[Ss]$') {
        Write-Host "Transferência remota cancelada pelo usuário" -ForegroundColor Yellow
        Write-Log "Transferência remota cancelada pelo usuário"
        Write-Host ""
        Write-Host "Pressione Enter para finalizar..." -ForegroundColor Yellow
        Read-Host
        exit
    }

    # 4. CARREGAR MÁQUINAS
    Write-Host ""
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
    Write-Host "🔧 Iniciando TRANSFERÊNCIA para $($computers.Count) máquinas..." -ForegroundColor Cyan
    Write-Log "Iniciando processo de TRANSFERÊNCIA para $($computers.Count) máquinas"
    Write-Host ""

    # 5. TRANSFERÊNCIA REMOTA
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
            
            # Tentar transferência de arquivos
            $transferResult = Transfer-FilesToRemote -ComputerName $computer
            
            if ($transferResult) {
                Write-Host "✅ TRANSFERIDO" -ForegroundColor Green
                $successCount++
            } else {
                Write-Host "❌ FALHA" -ForegroundColor Red
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
}

# 6. RESUMO FINAL
Write-Host ""
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "           📊 RESUMO DA TRANSFERÊNCIA" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "📍 Instalação LOCAL: " -NoNewline -ForegroundColor White
if ($localInstallResult) {
    Write-Host "SUCESSO COMPLETO ✅" -ForegroundColor Green
} else {
    Write-Host "FALHA ❌" -ForegroundColor Red
}
Write-Host "✅ Transferências bem-sucedidas: $successCount" -ForegroundColor Green
Write-Host "📴 Máquinas offline: $offlineCount" -ForegroundColor Gray
Write-Host "❌ Erros/Falhas (remoto): $errorCount" -ForegroundColor Red
Write-Host "📊 Total de máquinas remotas: $($computers.Count)" -ForegroundColor White
Write-Host "📄 Log detalhado: $LogFile" -ForegroundColor Cyan

Write-Log "=== RESUMO FINAL ==="
Write-Log "Instalação Local: $(if ($localInstallResult) {'SUCESSO COMPLETO'} else {'FALHA'})"
Write-Log "Transferências Bem-sucedidas: $successCount"
Write-Log "Offline: $offlineCount"
Write-Log "Erros: $errorCount"
Write-Log "Total Máquinas Remotas: $($computers.Count)"

if ($successCount -eq $computers.Count) {
    Write-Host "🎉 TODOS OS ARQUIVOS FORAM TRANSFERIDOS COM SUCESSO!" -ForegroundColor Green
    Write-Log "STATUS: Todas as transferências bem-sucedidas"
} elseif ($successCount -gt 0) {
    Write-Host "⚠ Transferência parcialmente concluída" -ForegroundColor Yellow
    Write-Log "STATUS: Transferência parcialmente concluída"
} else {
    Write-Host "💥 NENHUMA TRANSFERÊNCIA BEM-SUCEDIDA" -ForegroundColor Red
    Write-Log "STATUS: Nenhuma transferência bem-sucedida"
}

Write-Host ""
Write-Host "💡 Os arquivos foram copiados para:" -ForegroundColor Cyan
Write-Host "   • C:\Programas\GoToSetup.exe" -ForegroundColor Cyan
Write-Host "   • Área de Trabalho\GoToSetup.exe" -ForegroundColor Cyan
Write-Host "💡 Nas máquinas remotas, execute manualmente o instalador quando necessário" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

# Aguardar entrada do usuário
Write-Host "Pressione Enter para finalizar..." -ForegroundColor Yellow
Read-Host
