@echo off
setlocal enabledelayedexpansion

echo ============================================
echo 🚀 ALTERANDO NOME DO PROJETO PARA AI-DEPOM
echo ============================================
echo.

REM ============================================
REM PASSO 1: FAZER BACKUP
REM ============================================
echo 📁 Criando backup...
set BACKUP_DIR=backup_renomear_%date:~6,4%%date:~3,2%%date:~0,2%_%time:~0,2%%time:~3,2%
set BACKUP_DIR=%BACKUP_DIR: =0%
mkdir "%BACKUP_DIR%" 2>nul
copy *.html "%BACKUP_DIR%\" >nul 2>&1
echo ✅ Backup criado em: %BACKUP_DIR%
echo.

REM ============================================
REM PASSO 2: ALTERAR NOME NOS ARQUIVOS HTML
REM ============================================
echo 📝 Alterando nome do projeto nos arquivos HTML...
echo.

REM Lista de arquivos para alterar
set FILES=index.html 01-apresentacao.html 02-login.html 03-dashboard.html 04-cadastro-usuario.html 05-cadastro-suspeito.html 06-consulta.html 07-relatorios.html configuracoes.html

for %%f in (%FILES%) do (
    if exist "%%f" (
        echo 🔄 Processando: %%f
        
        REM Substituir "PCivil Sistema" por "AI-DEPOM"
        powershell -Command "(Get-Content '%%f' -Raw) -replace 'PCivil Sistema', 'AI-DEPOM' | Set-Content '%%f' -NoNewline"
        
        REM Substituir "PCivil" por "AI-DEPOM"
        powershell -Command "(Get-Content '%%f' -Raw) -replace 'PCivil', 'AI-DEPOM' | Set-Content '%%f' -NoNewline"
        
        REM Substituir "Polícia Civil" por "AI-DEPOM"
        powershell -Command "(Get-Content '%%f' -Raw) -replace 'Polícia Civil', 'AI-DEPOM' | Set-Content '%%f' -NoNewline"
        
        REM Substituir "Policia Civil" por "AI-DEPOM"
        powershell -Command "(Get-Content '%%f' -Raw) -replace 'Policia Civil', 'AI-DEPOM' | Set-Content '%%f' -NoNewline"
        
        REM Substituir "Sistema de Gestão da Polícia Civil" por "Sistema AI-DEPOM"
        powershell -Command "(Get-Content '%%f' -Raw) -replace 'Sistema de Gestão da Polícia Civil', 'Sistema AI-DEPOM' | Set-Content '%%f' -NoNewline"
        
        REM Substituir "Sistema de Gestao da Policia Civil" por "Sistema AI-DEPOM"
        powershell -Command "(Get-Content '%%f' -Raw) -replace 'Sistema de Gestao da Policia Civil', 'Sistema AI-DEPOM' | Set-Content '%%f' -NoNewline"
        
        REM Substituir "Gestão Integrada da Polícia Civil" por "Gestão Integrada AI-DEPOM"
        powershell -Command "(Get-Content '%%f' -Raw) -replace 'Gestão Integrada da Polícia Civil', 'Gestão Integrada AI-DEPOM' | Set-Content '%%f' -NoNewline"
        
        REM Substituir "Gestao Integrada da Policia Civil" por "Gestão Integrada AI-DEPOM"
        powershell -Command "(Get-Content '%%f' -Raw) -replace 'Gestao Integrada da Policia Civil', 'Gestão Integrada AI-DEPOM' | Set-Content '%%f' -NoNewline"
        
        REM Substituir "Polícia Civil do Estado" por "AI-DEPOM"
        powershell -Command "(Get-Content '%%f' -Raw) -replace 'Polícia Civil do Estado', 'AI-DEPOM' | Set-Content '%%f' -NoNewline"
        
        REM Substituir "Policia Civil do Estado" por "AI-DEPOM"
        powershell -Command "(Get-Content '%%f' -Raw) -replace 'Policia Civil do Estado', 'AI-DEPOM' | Set-Content '%%f' -NoNewline"
        
        REM Substituir "Sistema PCivil" por "AI-DEPOM"
        powershell -Command "(Get-Content '%%f' -Raw) -replace 'Sistema PCivil', 'AI-DEPOM' | Set-Content '%%f' -NoNewline"
        
        echo ✅ %%f atualizado!
    )
)

echo.
echo ============================================
echo 📤 ENVIANDO PARA O GITHUB
echo ============================================
echo.

git add .
git commit -m "🏷️ Alterando nome do projeto para AI-DEPOM"
git push

echo.
echo ============================================
echo ✅ PROJETO RENOMEADO COM SUCESSO!
echo ============================================
echo.
echo 📋 Nome antigo: PCivil Sistema / Polícia Civil
echo 📋 Nome novo:   AI-DEPOM
echo.
echo 📁 Backup criado em: %BACKUP_DIR%
echo.
pause
