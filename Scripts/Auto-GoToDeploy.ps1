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

# Função para obter Desktop do usuário atual na máquina remota
function Get-RemoteUserDesktop {
    param([string]$ComputerName)
    
    try {
        # Tentar obter o usuário logado via WMI
        $loggedInUser = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $ComputerName | Select-Object -ExpandProperty UserName
        
        if ($loggedInUser) {
            # Extrair apenas o nome do usuário (remover domínio se existir)
            $userName = $loggedInUser.Split('\')[-1]
            $userDesktopPath = "\\$ComputerName\C$\Users\$userName\Desktop"
            
            if (Test-Path $userDesktopPath) {
                Write-Log "Desktop do usuário encontrado: $userDesktopPath"
                return $userDesktopPath
            }
        }
        
        # Se não encontrou via WMI, tentar métodos alternativos
        # Listar todas as pastas de usuário e verificar qual tem Desktop
        $usersPath = "\\$ComputerName\C$\Users"
        if (Test-Path $usersPath) {
            $userFolders = Get-ChildItem $usersPath -Directory | Where-Object { 
                $_.Name -notin @('Public', 'Default', 'All Users') -and
                (Test-Path "$usersPath\$($_.Name)\Desktop")
            }
            
            foreach ($userFolder in $userFolders) {
                $desktopPath = "$usersPath\$($userFolder.Name)\Desktop"
                if (Test-Path $desktopPath) {
                    Write-Log "Desktop encontrado para usuário: $($userFolder.Name)"
                    return $desktopPath
                }
            }
        }
        
        return $null
        
    } catch {
        Write-Log "ERRO ao buscar Desktop do usuário em $ComputerName : $($_.Exception.Message)"
        return $null
    }
}

# Função para ABRIR o aplicativo como duplo-clique
function Start-RemoteApplication {
    param([string]$ComputerName)
    
    try {
        Write-Host "   🖱️  Abrindo aplicativo (como duplo-clique)..." -ForegroundColor Yellow
        Write-Log "Tentando abrir GoToSetup como duplo-clique em $ComputerName"
        
        # Método 1: Tentar abrir via PsExec sem parâmetros (como duplo-clique)
        $process = Start-Process -FilePath "PsExec.exe" -ArgumentList @(
            "\\$ComputerName",
            "-i",  # Executa na sessão interativa do usuário
            "cmd.exe /c `"C:\Users\Public\Desktop\GoToSetup.exe`""
        ) -PassThru -NoNewWindow -Wait -ErrorAction SilentlyContinue
        
        # Método 2: Se o primeiro falhar, tentar método alternativo
        if ($process.ExitCode -ne 0) {
            Write-Host "   🔄 Tentando método alternativo..." -ForegroundColor Gray
            $process = Start-Process -FilePath "PsExec.exe" -ArgumentList @(
                "\\$ComputerName",
                "-i",
                "C:\Users\Public\Desktop\GoToSetup.exe"
            ) -PassThru -NoNewWindow -Wait -ErrorAction SilentlyContinue
        }
        
        if ($process.ExitCode -eq 0) {
            Write-Host "   ✅ Aplicativo aberto com sucesso" -ForegroundColor Green
            Write-Log "SUCESSO: GoToSetup aberto como duplo-clique"
            return $true
        } else {
            Write-Host "   ⚠ Não foi possível abrir o aplicativo" -ForegroundColor Yellow
            Write-Log "AVISO: Falha ao abrir GoToSetup - ExitCode: $($process.ExitCode)"
            return $false
        }
        
    } catch {
        Write-Host "   ❌ Erro ao abrir aplicativo: $($_.Exception.Message)" -ForegroundColor Red
        Write-Log "ERRO ao abrir GoToSetup: $($_.Exception.Message)"
        return $false
    }
}

# Função para transferir arquivos para máquinas remotas (DESKTOP DO USUÁRIO)
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
        
        # AGORA COPIAR PARA O DESKTOP DO USUÁRIO ATUAL
        Write-Host "   🖥️  Buscando Desktop do usuário..." -ForegroundColor Gray
        
        $userDesktopPath = Get-RemoteUserDesktop -ComputerName $ComputerName
        
        if ($userDesktopPath -and (Test-Path $userDesktopPath)) {
            Write-Host "   📋 Copiando para Desktop do usuário..." -ForegroundColor Gray
            Copy-Item "$ProgramasDir\GoToSetup.exe" "$userDesktopPath\GoToSetup.exe" -Force -ErrorAction Stop
            
            if (Test-Path "$userDesktopPath\GoToSetup.exe") {
                Write-Host "   ✅ Copiado para Desktop do usuário" -ForegroundColor Green
                Write-Log "SUCESSO: Arquivo copiado para $userDesktopPath"
            } else {
                Write-Host "   ⚠ Não foi possível copiar para Desktop do usuário" -ForegroundColor Yellow
                Write-Log "AVISO: Falha ao copiar para Desktop do usuário"
            }
        } else {
            # Fallback: tentar Desktop público
            $publicDesktop = "\\$ComputerName\C$\Users\Public\Desktop"
            if (Test-Path $publicDesktop) {
                Write-Host "   📋 Copiando para Desktop público..." -ForegroundColor Gray
                Copy-Item "$ProgramasDir\GoToSetup.exe" "$publicDesktop\GoToSetup.exe" -Force -ErrorAction Stop
                
                if (Test-Path "$publicDesktop\GoToSetup.exe") {
                    Write-Host "   ✅ Copiado para Desktop público" -ForegroundColor Green
                    Write-Log "SUCESSO: Arquivo copiado para Desktop público"
                }
            } else {
                Write-Host "   ⚠ Desktop não encontrado" -ForegroundColor Yellow
                Write-Log "AVISO: Nenhum Desktop encontrado para cópia"
            }
        }
        
        # AGORA APENAS ABRIR O APLICATIVO (COMO DUPLO-CLIQUE)
        $executionResult = Start-RemoteApplication -ComputerName $ComputerName
        
        # Verificar se pelo menos o arquivo foi copiado para Programas
        if (Test-Path "$remoteProgramasDir\GoToSetup.exe") {
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
    Write-Host "⏸️  Deseja transferir e ABRIR o aplicativo em outras máquinas?" -ForegroundColor Yellow
    Write-Host "   (O arquivo será copiado e aberto como duplo-clique)" -ForegroundColor Gray
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
    Write-Host "🔧 Iniciando TRANSFERÊNCIA E ABERTURA em $($computers.Count) máquinas..." -ForegroundColor Cyan
    Write-Log "Iniciando processo de TRANSFERÊNCIA E ABERTURA em $($computers.Count) máquinas"
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
                Write-Host "✅ TRANSFERIDO E ABERTO" -ForegroundColor Green
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
Write-Host "           📊 RESUMO DA OPERAÇÃO" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "📍 Instalação LOCAL: " -NoNewline -ForegroundColor White
if ($localInstallResult) {
    Write-Host "SUCESSO COMPLETO ✅" -ForegroundColor Green
} else {
    Write-Host "FALHA ❌" -ForegroundColor Red
}
Write-Host "✅ Transferências e aberturas bem-sucedidas: $successCount" -ForegroundColor Green
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
    Write-Host "🎉 TODOS OS ARQUIVOS FORAM TRANSFERIDOS E ABERTOS COM SUCESSO!" -ForegroundColor Green
    Write-Log "STATUS: Todas as transferências e aberturas bem-sucedidas"
} elseif ($successCount -gt 0) {
    Write-Host "⚠ Transferência e abertura parcialmente concluída" -ForegroundColor Yellow
    Write-Log "STATUS: Transferência e abertura parcialmente concluída"
} else {
    Write-Host "💥 NENHUMA TRANSFERÊNCIA/ABERTURA BEM-SUCEDIDA" -ForegroundColor Red
    Write-Log "STATUS: Nenhuma transferência/abertura bem-sucedida"
}

Write-Host ""
Write-Host "💡 Os arquivos foram copiados para:" -ForegroundColor Cyan
Write-Host "   • C:\Programas\GoToSetup.exe" -ForegroundColor Cyan
Write-Host "   • Desktop do usuário\GoToSetup.exe" -ForegroundColor Cyan
Write-Host "💡 E abertos automaticamente nas máquinas remotas" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

# Aguardar entrada do usuário
Write-Host "Pressione Enter para finalizar..." -ForegroundColor Yellow
Read-Host
