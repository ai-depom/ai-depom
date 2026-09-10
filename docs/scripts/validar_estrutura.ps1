# ============================================
# AI-DEPOM - VALIDAÇÃO DA ESTRUTURA DO PROJETO
# (NÃO MODIFICA NADA - APENAS RELATÓRIO)
# ============================================

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "🔍 AI-DEPOM - VALIDAÇÃO DA ESTRUTURA" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# --------------------------------------------
# 1. VERIFICAR SE ESTÁ NO REPOSITÓRIO GIT
# --------------------------------------------
Write-Host "📌 1. VERIFICANDO REPOSITÓRIO GIT" -ForegroundColor Yellow
Write-Host "--------------------------------------------"

if (Test-Path ".git") {
    Write-Host "   ✅ Repositório Git encontrado" -ForegroundColor Green

    $remote = git remote get-url origin 2>$null
    if ($remote) {
        Write-Host "   🔗 Remote: $remote" -ForegroundColor White
    } else {
        Write-Host "   ⚠️ Nenhum remote configurado" -ForegroundColor Yellow
    }

    $branch = git branch --show-current 2>$null
    if ($branch) {
        Write-Host "   🌿 Branch atual: $branch" -ForegroundColor White
    }

    $status = git status --short 2>$null
    if ($status) {
        Write-Host "   📝 Arquivos modificados/não commitados:" -ForegroundColor Yellow
        $status | ForEach-Object { Write-Host "      $_" -ForegroundColor Gray }
    } else {
        Write-Host "   ✅ Nenhuma modificação pendente" -ForegroundColor Green
    }
} else {
    Write-Host "   ❌ Não é um repositório Git" -ForegroundColor Red
    Write-Host "   💡 Rode: git clone https://github.com/ai-depom/ai-depom.git" -ForegroundColor Yellow
}
Write-Host ""

# --------------------------------------------
# 2. LISTAR TODOS OS ARQUIVOS HTML
# --------------------------------------------
Write-Host "📌 2. ARQUIVOS HTML ENCONTRADOS" -ForegroundColor Yellow
Write-Host "--------------------------------------------"

$htmlFiles = Get-ChildItem -Path "." -Recurse -Filter "*.html" -File |
    Where-Object { $_.FullName -notmatch "\\node_modules\\" -and $_.FullName -notmatch "\\backup" }

if ($htmlFiles.Count -eq 0) {
    Write-Host "   ⚠️ Nenhum arquivo HTML encontrado" -ForegroundColor Yellow
} else {
    Write-Host "   📊 Total: $($htmlFiles.Count) arquivo(s) HTML" -ForegroundColor White
    Write-Host ""
    $htmlFiles | ForEach-Object {
        $rel = $_.FullName.Replace((Get-Location).Path, "").TrimStart("\")
        $size = "{0:N2} KB" -f ($_.Length / 1KB)
        Write-Host "      📄 $rel ($size)" -ForegroundColor Gray
    }
}
Write-Host ""

# --------------------------------------------
# 3. VERIFICAR INDEX.HTML
# --------------------------------------------
Write-Host "📌 3. VERIFICAÇÃO DO index.html" -ForegroundColor Yellow
Write-Host "--------------------------------------------"

$indexFiles = $htmlFiles | Where-Object { $_.Name -eq "index.html" }

if ($indexFiles.Count -eq 0) {
    Write-Host "   ❌ Nenhum index.html encontrado!" -ForegroundColor Red
} elseif ($indexFiles.Count -eq 1) {
    Write-Host "   ✅ Apenas 1 index.html encontrado (correto)" -ForegroundColor Green
    $rel = $indexFiles[0].FullName.Replace((Get-Location).Path, "").TrimStart("\")
    Write-Host "      📄 Localização: $rel" -ForegroundColor White
} else {
    Write-Host "   ⚠️ MÚLTIPLOS index.html encontrados ($($indexFiles.Count)):" -ForegroundColor Yellow
    $indexFiles | ForEach-Object {
        $rel = $_.FullName.Replace((Get-Location).Path, "").TrimStart("\")
        Write-Host "      📄 $rel" -ForegroundColor Gray
    }
    Write-Host "   💡 Recomendação: mantenha apenas 1 na raiz" -ForegroundColor Yellow
}
Write-Host ""

# --------------------------------------------
# 4. VERIFICAR ESTRUTURA DE PASTAS ESPERADA
# --------------------------------------------
Write-Host "📌 4. ESTRUTURA DE PASTAS" -ForegroundColor Yellow
Write-Host "--------------------------------------------"

$pastasEsperadas = @(
    "frontend",
    "frontend\src",
    "frontend\src\pages",
    "backend",
    "backend\src",
    "database",
    "docs",
    ".github",
    ".github\workflows"
)

foreach ($p in $pastasEsperadas) {
    if (Test-Path $p) {
        $qtd = (Get-ChildItem -Path $p -Recurse -File -ErrorAction SilentlyContinue).Count
        Write-Host "   ✅ $p ($qtd arquivo(s))" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️ $p (não existe)" -ForegroundColor Yellow
    }
}
Write-Host ""

# --------------------------------------------
# 5. VERIFICAR SE AINDA HÁ "PCIVIL" / "POLÍCIA CIVIL"
# --------------------------------------------
Write-Host "📌 5. VERIFICANDO RESQUÍCIOS DE 'PCIVIL' / 'POLÍCIA CIVIL'" -ForegroundColor Yellow
Write-Host "--------------------------------------------"

$termos = @("PCivil", "Polícia Civil", "Policia Civil", "Sistema PCivil", "PCivil Sistema")
$encontrados = @()

$arquivosAnalisar = Get-ChildItem -Path "." -Recurse -Include *.html,*.js,*.css,*.md,*.txt,*.json,*.sql -File |
    Where-Object { $_.FullName -notmatch "\\node_modules\\" -and $_.FullName -notmatch "\\backup" -and $_.FullName -notmatch "\\.git\\" }

foreach ($arq in $arquivosAnalisar) {
    $conteudo = Get-Content $arq.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($conteudo) {
        foreach ($t in $termos) {
            if ($conteudo -match [regex]::Escape($t)) {
                $rel = $arq.FullName.Replace((Get-Location).Path, "").TrimStart("\")
                $encontrados += [PSCustomObject]@{
                    Arquivo = $rel
                    Termo   = $t
                }
            }
        }
    }
}

if ($encontrados.Count -eq 0) {
    Write-Host "   ✅ Nenhum resquício encontrado! Projeto 100% AI-DEPOM" -ForegroundColor Green
} else {
    Write-Host "   ⚠️ Resquícios encontrados em $($encontrados.Count) ocorrência(s):" -ForegroundColor Yellow
    $encontrados | ForEach-Object {
        Write-Host "      📄 $($_.Arquivo) → contém '$($_.Termo)'" -ForegroundColor Gray
    }
}
Write-Host ""

# --------------------------------------------
# 6. VERIFICAR ARQUIVOS DUPLICADOS
# --------------------------------------------
Write-Host "📌 6. ARQUIVOS DUPLICADOS" -ForegroundColor Yellow
Write-Host "--------------------------------------------"

$todosArquivos = Get-ChildItem -Path "." -Recurse -File |
    Where-Object { $_.FullName -notmatch "\\node_modules\\" -and $_.FullName -notmatch "\\.git\\" -and $_.FullName -notmatch "\\backup" }

$duplicados = $todosArquivos | Group-Object Name | Where-Object { $_.Count -gt 1 }

if ($duplicados.Count -eq 0) {
    Write-Host "   ✅ Nenhum arquivo duplicado encontrado" -ForegroundColor Green
} else {
    Write-Host "   ⚠️ Arquivos com nomes duplicados:" -ForegroundColor Yellow
    foreach ($d in $duplicados) {
        Write-Host "      📄 $($d.Name) ($($d.Count) ocorrências):" -ForegroundColor Gray
        $d.Group | ForEach-Object {
            $rel = $_.FullName.Replace((Get-Location).Path, "").TrimStart("\")
            Write-Host "         → $rel" -ForegroundColor DarkGray
        }
    }
}
Write-Host ""

# --------------------------------------------
# 7. RESUMO GERAL
# --------------------------------------------
Write-Host "📌 7. RESUMO GERAL" -ForegroundColor Yellow
Write-Host "--------------------------------------------"

$totalArquivos = (Get-ChildItem -Path "." -Recurse -File |
    Where-Object { $_.FullName -notmatch "\\node_modules\\" -and $_.FullName -notmatch "\\.git\\" }).Count

$totalPastas = (Get-ChildItem -Path "." -Recurse -Directory |
    Where-Object { $_.FullName -notmatch "\\node_modules\\" -and $_.FullName -notmatch "\\.git\\" }).Count

Write-Host "   📊 Total de arquivos: $totalArquivos" -ForegroundColor White
Write-Host "   📁 Total de pastas:   $totalPastas" -ForegroundColor White
Write-Host "   📄 Arquivos HTML:     $($htmlFiles.Count)" -ForegroundColor White
Write-Host "   🔍 Resquícios PCivil: $($encontrados.Count)" -ForegroundColor White
Write-Host "   📑 Duplicados:        $($duplicados.Count)" -ForegroundColor White
Write-Host ""

# --------------------------------------------
# 8. STATUS FINAL
# --------------------------------------------
Write-Host "============================================" -ForegroundColor Cyan

if ($encontrados.Count -eq 0 -and $indexFiles.Count -le 1 -and $duplicados.Count -eq 0) {
    Write-Host "✅ ESTRUTURA OK! Projeto pronto para uso." -ForegroundColor Green
} else {
    Write-Host "⚠️ ESTRUTURA COM PENDÊNCIAS. Verifique os itens acima." -ForegroundColor Yellow
}

Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "💡 Este script NÃO modificou nenhum arquivo." -ForegroundColor Gray
Write-Host "🔗 Repositório: https://github.com/ai-depom/ai-depom" -ForegroundColor Gray
Write-Host ""
