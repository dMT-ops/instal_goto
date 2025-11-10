# 📋 Instalador Automático - GoTo Meeting

Script PowerShell para instalação automatizada do GoTo Meeting em múltiplas máquinas da rede.

## 🚀 Funcionalidades

- ✅ **Instalação local automática** do GoTo Meeting
- ✅ **Download automático** do instalador
- ✅ **Instalação silenciosa** sem interação do usuário
- ✅ **Distribuição em rede** para múltiplas máquinas
- ✅ **Log detalhado** de todas as operações
- ✅ **Verificação de conectividade** com as máquinas
- ✅ **Relatório final** com estatísticas de instalação

## 📁 Estrutura do Projeto

```
instal_goto/
├── Scripts/
│   └── Auto-GoToDeploy.ps1    # Script principal
├── Programas/
│   └── GoToSetup.exe          # Instalador do GoTo Meeting
└── Config/
    └── maquinas.txt           # Lista de máquinas da rede
```

## 🛠️ Pré-requisitos

- **Windows PowerShell** (versão 5.1 ou superior)
- **Acesso de administrador** na máquina local
- **PsExec** da Sysinternals instalado e EULA aceito
- **Conectividade de rede** com as máquinas alvo
- **Permissões administrativas** nas máquinas remotas

## ⚡ Como Usar

### 1. Preparação Inicial (Execute uma vez)

```powershell
# Aceitar EULA do PsExec
reg add "HKCU\Software\Sysinternals\PsExec" /v EulaAccepted /t REG_DWORD /d 1 /f
```

### 2. Execução do Script

```powershell
# Executar diretamente do GitHub
irm "https://github.com/dMT-ops/instal_goto/raw/main/Scripts/Auto-GoToDeploy.ps1" | iex
```

### 3. Execução Passo a Passo

```powershell
# 1. Executar como Administrador
# 2. O script irá automaticamente:
#    - Baixar o instalador do GoTo Meeting
#    - Instalar localmente na sua máquina
#    - Perguntar se deseja continuar com outras máquinas
#    - Instalar em todas as máquinas listadas no arquivo maquinas.txt
```

## 📋 Fluxo de Execução

1. **Preparação do Ambiente**
   - Cria pasta `C:\Programas`
   - Baixa o instalador do GoTo Meeting

2. **Instalação Local**
   - Instala silenciosamente na máquina local
   - Tenta executar automaticamente para confirmação

3. **Instalação Remota**
   - Lê lista de máquinas do `maquinas.txt`
   - Verifica conectividade com cada máquina
   - Instala usando PsExec remotamente
   - Registra resultados detalhados

4. **Relatório Final**
   - Mostra estatísticas completas
   - Gera log em `C:\GoToInstall.log`

## 📝 Configuração

### Arquivo maquinas.txt
Formato: uma máquina por linha
```
SERVIDOR01
WORKSTATION02
NOTEBOOK03
192.168.1.100
```

### Personalização
Edite as variáveis no início do script para customizar:
```powershell
$ProgramasDir = "C:\Programas"    # Pasta de instalação
$LogFile = "C:\GoToInstall.log"   # Arquivo de log
```

## 🔧 Solução de Problemas

### Erro Comum: "Máquina Offline"
- Verifique se a máquina está ligada e na rede
- Teste conectividade: `Test-Connection NOME_MAQUINA`

### Erro Comum: "Acesso Negado"
- Execute o PowerShell como Administrador
- Verifique permissões administrativas nas máquinas remotas

### Erro Comum: PsExec não encontrado
- Certifique-se que o PsExec está no PATH do sistema
- Ou ajuste o caminho no script

### Logs Detalhados
- Consulte `C:\GoToInstall.log` para troubleshooting
- Cada operação é registrada com timestamp

## 📊 Exemplo de Saída

```
===============================================
    🚀 INSTALADOR AUTOMÁTICO - GOTO MEETING
===============================================

📁 Preparando ambiente...
   ✅ Pasta criada: C:\Programas
📥 Baixando GoTo Meeting...
   ✅ GoTo Meeting baixado com sucesso

🔧 INSTALANDO GOTO LOCALMENTE...
📦 Executando instalação local SILENCIOSA...
   ⏳ Aguardando finalização da instalação...
✅ GoTo instalado com SUCESSO nesta máquina

📍 RESULTADO DA INSTALAÇÃO LOCAL: SUCESSO COMPLETO ✅
   ✓ GoTo instalado silenciosamente
   ✓ GoTo executado automaticamente

✅ Instalado com sucesso (remoto): 15
📴 Máquinas offline: 2
❌ Erros/Falhas (remoto): 1
📊 Total de máquinas remotas: 18
```

## ⚠️ Observações Importantes

- **Sempre execute como Administrador**
- **Firewall** pode bloquear conexões remotas
- **Antivírus** pode interferir na instalação
- **Teste primeiro em poucas máquinas** antes de deploy em massa

## 📄 Licença

Este projeto é para uso interno. Certifique-se de ter licenças válidas do GoTo Meeting.

## 🤝 Suporte

Em caso de problemas:
1. Verifique o arquivo de log: `C:\GoToInstall.log`
2. Confirme que o PsExec está configurado corretamente
3. Teste conectividade com as máquinas alvo
4. Execute em modo de debug se necessário

---

**Desenvolvido para automação de deployments em ambiente corporativo** 🚀
