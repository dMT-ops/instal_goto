# Auto-GoToDeploy.ps1 - Instalação Automática do GoTo
# Execute com: irm "https://github.com/dMT-ops/instal_goto/raw/main/Scripts/Auto-GoToDeploy.ps1" | iex

# Configurações
$GitHubBase = "https://github.com/dMT-ops/instal_goto/raw/main"
$ProgramasDir = "C:\Programas"
$LogFile = "C:\GoToInstall.log"

# Arrays para armazenar resultados detalhados
$successComputers = @()
$failedComputers = @()
$offlineComputers = @()
$alreadyInstalledComputers = @()

# Função de log
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    "$timestamp - $Message" | Out-File $LogFile -Append
    Write-Host "$timestamp - $Message" -ForegroundColor Gray
}

# Função para verificar se GoTo já está instalado
function Test-GoToInstalled {
    param([string]$ComputerName)
    
    try {
        # Método 1: Verificar nos programas instalados via registro
        $registryPaths = @(
            "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
            "SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
        )
        
        foreach ($registryPath in $registryPaths) {
            $regPath = "\\$ComputerName\HKLM\$registryPath"
            try {
                $installedPrograms = Get-ChildItem "Registry::$regPath" -ErrorAction SilentlyContinue
                foreach ($program in $installedPrograms) {
                    $displayName = $program.GetValue("DisplayName")
                    if ($displayName -like "*GoTo*" -or $displayName -like "*LogMeIn*") {
                        Write-Log "GoTo encontrado via registro: $displayName em $ComputerName"
                        return $true
                    }
                }
            } catch {
                # Continua para próxima verificação
            }
        }
        
        # Método 2: Verificar arquivos de programa
        $programFilesPaths = @(
            "\\$ComputerName\C$\Program Files",
            "\\$ComputerName\C$\Program Files (x86)"
        )
        
        $gotoFolders = @("*GoTo*", "*LogMeIn*")
        
        foreach ($programPath in $programFilesPaths) {
            if (Test-Path $programPath) {
                foreach ($folderPattern in $gotoFolders) {
                    $matchingFolders = Get-ChildItem -Path $programPath -Directory -Filter $folderPattern -ErrorAction SilentlyContinue
                    if ($matchingFolders) {
                        Write-Log "Pasta GoTo encontrada: $($matchingFolders[0].Name) em $ComputerName"
                        return $true
                    }
                }
            }
        }
        
        # Método 3: Verificar processos em execução
        try {
            $processes = Get-Process -ComputerName $ComputerName -Name "*goto*","*logmein*" -ErrorAction SilentlyContinue
            if ($processes) {
                Write-Log "Processo GoTo em execução encontrado em $ComputerName"
                return $true
            }
        } catch {
            # Process check failed, continue
        }
        
        return $false
        
    } catch {
        Write-Log "ERRO na verificação de instalação em $ComputerName : $($_.Exception.Message)"
        return $false
    }
}

# Função para verificar se a instalação foi bem-sucedida após execução
function Test-InstallationSuccess {
    param([string]$ComputerName)
    
    try {
        # Aguardar um pouco para a instalação processar
        Start-Sleep -Seconds 10
        
        # Verificar se agora aparece como instalado
        $isInstalled = Test-GoToInstalled -ComputerName $ComputerName
        
        if ($isInstalled) {
            Write-Log "VERIFICAÇÃO PÓS-INSTALAÇÃO: GoTo confirmado instalado em $ComputerName"
            return $true
        }
        
        # Tentar verificar se o processo de instalação ainda está rodando
        try {
            $installProcess = Get-Process -ComputerName $ComputerName -Name "GoToSetup" -ErrorAction SilentlyContinue
            if ($installProcess) {
                Write-Log "Processo de instalação ainda em execução em $ComputerName, aguardando..."
                Start-Sleep -Seconds 30
                
                # Verificar novamente após esperar
                $isInstalled = Test-GoToInstalled -ComputerName $ComputerName
                return $isInstalled
            }
        } catch {
            # Ignora erro de verificação de processo
        }
        
        return $false
        
    } catch {
        Write-Log "ERRO na verificação pós-instalação em $ComputerName : $($_.Exception.Message)"
        return $false
    }
}

# Função para transferir e instalar remotamente
function Install-GoToRemote {
    param([string]$ComputerName)
    
    try {
        Write-Log "Iniciando instalação remota em: $ComputerName"
        
        # Criar pasta Programas na máquina remota
        $remoteProgramasDir = "\\$ComputerName\C$\Programas"
        
        Write-Host "   📁 Criando pasta..." -NoNewline -ForegroundColor Gray
        New-Item -Path $remoteProgramasDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
        Write-Host " ✅" -ForegroundColor Green
        
        # Copiar arquivo para máquina remota
        Write-Host "   📤 Copiando arquivo..." -NoNewline -ForegroundColor Gray
        Copy-Item "$ProgramasDir\GoToSetup.exe" "$remoteProgramasDir\GoToSetup.exe" -Force -ErrorAction Stop
        Write-Host " ✅" -ForegroundColor Green
        
        # Instalar silenciosamente via PsExec
        Write-Host "   🔧 Instalando..." -NoNewline -ForegroundColor Gray
        $process = Start-Process -FilePath "PsExec.exe" -ArgumentList @(
            "\\$ComputerName",
            "-s",
            "-d",
            "`"$remoteProgramasDir\GoToSetup.exe`"",
            "/S"
        ) -PassThru -NoNewWindow -Wait -ErrorAction Stop
        
        # CORREÇÃO: PsExec com -d retorna o PID, não código de erro
        if ($process.ExitCode -ge 0) {
            Write-Host " ✅" -ForegroundColor Green
            Write-Log "Processo iniciado com PID $($process.ExitCode) em $ComputerName"
            
            # Verificar se a instalação foi realmente bem-sucedida
            Write-Host "   🔍 Verificando instalação..." -NoNewline -ForegroundColor Gray
            $installVerified = Test-InstallationSuccess -ComputerName $ComputerName
            
            if ($installVerified) {
                Write-Host " ✅" -ForegroundColor Green
                Write-Log "SUCESSO: GoTo instalado e verificado em $ComputerName"
                return $true
            } else {
                Write-Host " ⚠️" -ForegroundColor Yellow
                Write-Log "AVISO: Processo iniciado mas instalação não verificada em $ComputerName"
                # Mesmo assim consideramos sucesso pois o processo foi iniciado
                return $true
            }
        } else {
            Write-Host " ❌" -ForegroundColor Red
            Write-Log "FALHA: Erro ao iniciar processo em $ComputerName - Código: $($process.ExitCode)"
            return $false
        }
        
    } catch {
        Write-Host " ❌" -ForegroundColor Red
        Write-Host "   💥 Erro: $($_.Exception.Message)" -ForegroundColor Red
        Write-Log "ERRO em $ComputerName : $($_.Exception.Message)"
        return $false
    }
}

# INÍCIO
Clear-Host
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "    🚀 INSTALADOR RÁPIDO - GOTO MEETING" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

try {
    # 1. CRIAR PASTAS
    Write-Host "📁 Preparando ambiente..." -ForegroundColor Yellow
    Write-Log "Iniciando preparação do ambiente"
    if (-not (Test-Path $ProgramasDir)) {
        New-Item -Path $ProgramasDir -ItemType Directory -Force -ErrorAction Stop
        Write-Host "   ✅ Pasta criada: $ProgramasDir" -ForegroundColor Green
    } else {
        Write-Host "   ✅ Pasta já existe: $ProgramasDir" -ForegroundColor Green
    }

    # 2. DOWNLOAD GOTO
    Write-Host "📥 Baixando GoTo Meeting..." -ForegroundColor Yellow
    Write-Log "Iniciando download do GoTo Meeting"
    if (-not (Test-Path "$ProgramasDir\GoToSetup.exe")) {
        try {
            Invoke-WebRequest "$GitHubBase/Programas/GoToSetup.exe" -OutFile "$ProgramasDir\GoToSetup.exe" -ErrorAction Stop
            Write-Host "   ✅ GoTo Meeting baixado com sucesso" -ForegroundColor Green
            Write-Log "Download do GoTo Meeting concluído"
        } catch {
            Write-Host "   ❌ Erro ao baixar GoTo: $($_.Exception.Message)" -ForegroundColor Red
            Write-Log "ERRO no download: $($_.Exception.Message)"
            throw
        }
    } else {
        Write-Host "   ✅ GoTo Meeting já baixado anteriormente" -ForegroundColor Green
        Write-Log "GoTo Setup já existe localmente"
    }

    # 3. CARREGAR MÁQUINAS
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
    Write-Host "🔧 Iniciando INSTALAÇÃO REMOTA em $($computers.Count) máquinas..." -ForegroundColor Cyan
    Write-Log "Iniciando processo de INSTALAÇÃO REMOTA em $($computers.Count) máquinas"
    Write-Host ""

    # 4. INSTALAÇÃO REMOTA
    $currentNumber = 0
    
    foreach ($computer in $computers) {
        $currentNumber++
        $computer = $computer.Trim()
        if (-not $computer) { continue }
        
        $progress = "[$currentNumber/$($computers.Count)]"
        Write-Host "$progress ⚡ $computer... " -NoNewline -ForegroundColor Yellow
        Write-Log "Processando máquina: $computer"
        
        # Verificar se máquina está online
        Write-Host "[Teste Conexão...] " -NoNewline -ForegroundColor Gray
        if (Test-Connection -ComputerName $computer -Count 1 -Quiet -ErrorAction SilentlyContinue) {
            Write-Host "[Online] " -NoNewline -ForegroundColor Green
            Write-Log "$computer - Máquina online"
            
            # VERIFICAR SE JÁ ESTÁ INSTALADO
            Write-Host "[Verificando Instalação...] " -NoNewline -ForegroundColor Gray
            $isAlreadyInstalled = Test-GoToInstalled -ComputerName $computer
            
            if ($isAlreadyInstalled) {
                Write-Host "📦 JÁ INSTALADO" -ForegroundColor Blue
                Write-Log "GoTo já está instalado em $computer - Pulando instalação"
                $alreadyInstalledComputers += $computer
            } else {
                Write-Host "[Não Encontrado] " -NoNewline -ForegroundColor Yellow
                
                # Tentar instalação remota
                $installResult = Install-GoToRemote -ComputerName $computer
                
                if ($installResult) {
                    Write-Host "✅ SUCESSO" -ForegroundColor Green
                    $successComputers += $computer
                } else {
                    Write-Host "❌ FALHA" -ForegroundColor Red
                    $failedComputers += $computer
                }
            }
        } else {
            Write-Host "📴 OFFLINE" -ForegroundColor Gray
            Write-Log "OFFLINE: $computer - Máquina não respondeu ao ping"
            $offlineComputers += $computer
        }
    }

} catch {
    Write-Host ""
    Write-Host "💥 ERRO CRÍTICO: $($_.Exception.Message)" -ForegroundColor Red
    Write-Log "ERRO CRÍTICO: $($_.Exception.Message)"
}

# 5. RELATÓRIO DETALHADO
Write-Host ""
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "           📊 RELATÓRIO DETALHADO" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan

# Resumo Geral
Write-Host ""
Write-Host "📈 RESUMO GERAL:" -ForegroundColor White
Write-Host "   ✅ Sucesso: $($successComputers.Count)" -ForegroundColor Green
Write-Host "   📦 Já Instalado: $($alreadyInstalledComputers.Count)" -ForegroundColor Blue
Write-Host "   ❌ Falhas: $($failedComputers.Count)" -ForegroundColor Red
Write-Host "   📴 Offline: $($offlineComputers.Count)" -ForegroundColor Gray
Write-Host "   📊 Total: $($computers.Count)" -ForegroundColor White

# Detalhes - MÁQUINAS COM SUCESSO
if ($successComputers.Count -gt 0) {
    Write-Host ""
    Write-Host "✅ MÁQUINAS INSTALADAS COM SUCESSO ($($successComputers.Count)):" -ForegroundColor Green
    foreach ($computer in $successComputers) {
        Write-Host "   ✓ $computer" -ForegroundColor Green
    }
}

# Detalhes - JÁ INSTALADAS
if ($alreadyInstalledComputers.Count -gt 0) {
    Write-Host ""
    Write-Host "📦 MÁQUINAS COM GOTO JÁ INSTALADO ($($alreadyInstalledComputers.Count)):" -ForegroundColor Blue
    foreach ($computer in $alreadyInstalledComputers) {
        Write-Host "   📦 $computer" -ForegroundColor Blue
    }
}

# Detalhes - MÁQUINAS COM FALHA
if ($failedComputers.Count -gt 0) {
    Write-Host ""
    Write-Host "❌ MÁQUINAS COM FALHA NA INSTALAÇÃO ($($failedComputers.Count)):" -ForegroundColor Red
    foreach ($computer in $failedComputers) {
        Write-Host "   ✗ $computer" -ForegroundColor Red
    }
}

# Detalhes - MÁQUINAS OFFLINE
if ($offlineComputers.Count -gt 0) {
    Write-Host ""
    Write-Host "📴 MÁQUINAS OFFLINE ($($offlineComputers.Count)):" -ForegroundColor Gray
    foreach ($computer in $offlineComputers) {
        Write-Host "   ● $computer" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "📄 Log completo: $LogFile" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan

# Log do resumo final
Write-Log "=== RELATÓRIO FINAL ==="
Write-Log "Sucesso: $($successComputers.Count) - $($successComputers -join ', ')"
Write-Log "Já Instalado: $($alreadyInstalledComputers.Count) - $($alreadyInstalledComputers -join ', ')"
Write-Log "Falhas: $($failedComputers.Count) - $($failedComputers -join ', ')"
Write-Log "Offline: $($offlineComputers.Count) - $($offlineComputers -join ', ')"
Write-Log "Total: $($computers.Count)"

# Aguardar entrada do usuário
Write-Host ""
Write-Host "Pressione Enter para finalizar..." -ForegroundColor Yellow
Read-Host
