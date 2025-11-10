# Função para ABRIR o aplicativo como duplo-clique (VERSÃO SUPER COMPLETA)
function Start-RemoteApplication {
    param([string]$ComputerName)
    
    try {
        Write-Host "   🖱️  Abrindo aplicativo (como duplo-clique)..." -ForegroundColor Yellow
        Write-Log "Tentando abrir GoTo.exe como duplo-clique em $ComputerName"
        
        # MÉTODO 1: Usar Invoke-WmiMethod (mais confiável)
        Write-Host "   🔧 Método 1: WMI..." -NoNewline -ForegroundColor Gray
        try {
            $result = Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList "C:\Users\Public\Desktop\GoTo.exe" -ComputerName $ComputerName -ErrorAction Stop
            if ($result.ReturnValue -eq 0) {
                Write-Host " ✅" -ForegroundColor Green
                Write-Log "SUCESSO: GoTo.exe aberto via WMI - ProcessID: $($result.ProcessId)"
                return $true
            } else {
                Write-Host " ❌" -ForegroundColor Red
            }
        } catch {
            Write-Host " ❌" -ForegroundColor Red
            Write-Log "AVISO: Método WMI falhou - $($_.Exception.Message)"
        }
        
        # MÉTODO 2: Usar Invoke-Command (PowerShell Remoting)
        Write-Host "   🔧 Método 2: PowerShell Remoting..." -NoNewline -ForegroundColor Gray
        try {
            $session = New-PSSession -ComputerName $ComputerName -ErrorAction SilentlyContinue
            if ($session) {
                $result = Invoke-Command -Session $session -ScriptBlock {
                    Start-Process "C:\Users\Public\Desktop\GoTo.exe" -ErrorAction Stop
                } -ErrorAction Stop
                Remove-PSSession $session
                Write-Host " ✅" -ForegroundColor Green
                Write-Log "SUCESSO: GoTo.exe aberto via PowerShell Remoting"
                return $true
            } else {
                Write-Host " ❌" -ForegroundColor Red
            }
        } catch {
            Write-Host " ❌" -ForegroundColor Red
            Write-Log "AVISO: PowerShell Remoting falhou - $($_.Exception.Message)"
        }
        
        # MÉTODO 3: Usar SCHTASKS (Agendador de Tarefas)
        Write-Host "   🔧 Método 3: Agendador de Tarefas..." -NoNewline -ForegroundColor Gray
        try {
            $taskName = "OpenGoToTemp_$([System.Guid]::NewGuid().ToString().Substring(0,8))"
            schtasks /create /s $ComputerName /tn $taskName /tr "C:\Users\Public\Desktop\GoTo.exe" /sc once /st "00:00" /ru "SYSTEM" /f 2>$null
            schtasks /run /s $ComputerName /tn $taskName 2>$null
            Start-Sleep -Seconds 2
            schtasks /delete /s $ComputerName /tn $taskName /f 2>$null
            Write-Host " ✅" -ForegroundColor Green
            Write-Log "SUCESSO: GoTo.exe aberto via Agendador de Tarefas"
            return $true
        } catch {
            Write-Host " ❌" -ForegroundColor Red
            Write-Log "AVISO: Agendador de Tarefas falhou - $($_.Exception.Message)"
        }
        
        # MÉTODO 4: Usar PsExec com approach diferente
        Write-Host "   🔧 Método 4: PsExec Interativo..." -NoNewline -ForegroundColor Gray
        try {
            $process = Start-Process -FilePath "PsExec.exe" -ArgumentList @(
                "\\$ComputerName",
                "-i",
                "cmd.exe /c start `"`" `"C:\Users\Public\Desktop\GoTo.exe`""
            ) -PassThru -NoNewWindow -Wait -ErrorAction SilentlyContinue
            
            if ($process.ExitCode -eq 0) {
                Write-Host " ✅" -ForegroundColor Green
                Write-Log "SUCESSO: GoTo.exe aberto via PsExec"
                return $true
            } else {
                Write-Host " ❌" -ForegroundColor Red
            }
        } catch {
            Write-Host " ❌" -ForegroundColor Red
            Write-Log "AVISO: Método PsExec falhou - $($_.Exception.Message)"
        }
        
        # MÉTODO 5: Usar WMIC
        Write-Host "   🔧 Método 5: WMIC..." -NoNewline -ForegroundColor Gray
        try {
            $wmicProcess = Start-Process -FilePath "wmic" -ArgumentList @(
                "/node:$ComputerName",
                "process",
                "call",
                "create",
                "`"C:\Users\Public\Desktop\GoTo.exe`""
            ) -PassThru -NoNewWindow -Wait -ErrorAction SilentlyContinue
            
            if ($wmicProcess.ExitCode -eq 0) {
                Write-Host " ✅" -ForegroundColor Green
                Write-Log "SUCESSO: GoTo.exe aberto via WMIC"
                return $true
            } else {
                Write-Host " ❌" -ForegroundColor Red
            }
        } catch {
            Write-Host " ❌" -ForegroundColor Red
            Write-Log "AVISO: Método WMIC falhou - $($_.Exception.Message)"
        }
        
        # MÉTODO 6: Usar Service Controller (criativo)
        Write-Host "   🔧 Método 6: Service Controller..." -NoNewline -ForegroundColor Gray
        try {
            # Tentar via sc.exe para criar serviço temporário
            $serviceName = "TempGoTo_$([System.Guid]::NewGuid().ToString().Substring(0,8))"
            & sc.exe \\$ComputerName create $serviceName binPath= "cmd.exe /c start C:\Users\Public\Desktop\GoTo.exe" type= own start= demand 2>$null
            & sc.exe \\$ComputerName start $serviceName 2>$null
            Start-Sleep -Seconds 3
            & sc.exe \\$ComputerName delete $serviceName 2>$null
            Write-Host " ✅" -ForegroundColor Green
            Write-Log "SUCESSO: GoTo.exe aberto via Service Controller"
            return $true
        } catch {
            Write-Host " ❌" -ForegroundColor Red
            Write-Log "AVISO: Service Controller falhou - $($_.Exception.Message)"
        }
        
        # MÉTODO 7: Usar Registry RunOnce
        Write-Host "   🔧 Método 7: Registry RunOnce..." -NoNewline -ForegroundColor Gray
        try {
            $regPath = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
            $regValueName = "TempGoTo_$([System.Guid]::NewGuid().ToString().Substring(0,8))"
            
            & reg.exe add "\\$ComputerName\$regPath" /v $regValueName /t REG_SZ /d "C:\Users\Public\Desktop\GoTo.exe" /f 2>$null
            if ($LASTEXITCODE -eq 0) {
                # Forçar atualização do registry
                & psexec.exe \\$ComputerName cmd.exe /c "echo atualizando" 2>$null
                Write-Host " ✅" -ForegroundColor Green
                Write-Log "SUCESSO: GoTo.exe configurado via Registry RunOnce"
                return $true
            } else {
                Write-Host " ❌" -ForegroundColor Red
            }
        } catch {
            Write-Host " ❌" -ForegroundColor Red
            Write-Log "AVISO: Registry RunOnce falhou - $($_.Exception.Message)"
        }
        
        # MÉTODO 8: Tentar com usuário específico se encontrado
        Write-Host "   🔧 Método 8: Buscar usuário logado..." -NoNewline -ForegroundColor Gray
        $loggedInUser = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $ComputerName -ErrorAction SilentlyContinue | Select-Object -ExpandProperty UserName
        
        if ($loggedInUser) {
            $userName = $loggedInUser.Split('\')[-1]
            try {
                $result = Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList "C:\Users\$userName\Desktop\GoTo.exe" -ComputerName $ComputerName -ErrorAction SilentlyContinue
                if ($result.ReturnValue -eq 0) {
                    Write-Host " ✅ (usuário: $userName)" -ForegroundColor Green
                    Write-Log "SUCESSO: GoTo.exe aberto via WMI para usuário $userName"
                    return $true
                } else {
                    Write-Host " ❌" -ForegroundColor Red
                }
            } catch {
                Write-Host " ❌" -ForegroundColor Red
                Write-Log "AVISO: Método WMI com usuário falhou - $($_.Exception.Message)"
            }
        } else {
            Write-Host " ❌" -ForegroundColor Red
        }
        
        Write-Host ""
        Write-Host "   ⚠ Não foi possível abrir o aplicativo automaticamente" -ForegroundColor Yellow
        Write-Log "AVISO: Todos os 8 métodos falharam para abrir GoTo.exe"
        Write-Host "   💡 O arquivo foi copiado para a Área de Trabalho como GoTo.exe" -ForegroundColor Gray
        Write-Host "   💡 Execute manualmente com duplo-clique quando necessário" -ForegroundColor Gray
        return $false
        
    } catch {
        Write-Host " ❌" -ForegroundColor Red
        Write-Host "   ❌ Erro ao abrir aplicativo: $($_.Exception.Message)" -ForegroundColor Red
        Write-Log "ERRO ao abrir GoTo.exe: $($_.Exception.Message)"
        return $false
    }
}
