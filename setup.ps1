<#
.SYNOPSIS
  Setup do knowledge-wiki-onze na sua maquina.
  Instala o comando /wiki no Claude Code e configura o git.

.EXAMPLE
  .\setup.ps1
#>

$RepoUrl  = "https://github.com/vctorAgto/knowledge-wiki-onze.git"
$RepoName = "knowledge-wiki-onze"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Onze Work - Setup Wiki" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ── 1. NOME DO USUARIO ───────────────────────────────────
$gitName  = git config --global user.name  2>$null
$gitEmail = git config --global user.email 2>$null

if (-not $gitName) {
  $gitName = Read-Host "Seu nome (ex: Victor Pecuch)"
  git config --global user.name $gitName
  Write-Host "  git name configurado: $gitName" -ForegroundColor Green
} else {
  Write-Host "  git name: $gitName" -ForegroundColor Green
}

if (-not $gitEmail) {
  $gitEmail = Read-Host "Seu email (ex: vpecuch@onze.work)"
  git config --global user.email $gitEmail
  Write-Host "  git email configurado: $gitEmail" -ForegroundColor Green
} else {
  Write-Host "  git email: $gitEmail" -ForegroundColor Green
}

Write-Host ""

# ── 2. CLONAR O REPO ─────────────────────────────────────
$candidates = @(
  (Join-Path $HOME "Documents\projects-vscode\$RepoName"),
  (Join-Path $HOME "projetos\$RepoName"),
  (Join-Path $HOME $RepoName)
)

$repoPath = $null
foreach ($c in $candidates) {
  if (Test-Path (Join-Path $c ".git")) {
    $repoPath = $c
    Write-Host "  Repo encontrado em: $repoPath" -ForegroundColor Green
    Push-Location $repoPath
    git pull --quiet origin main
    Pop-Location
    break
  }
}

if (-not $repoPath) {
  $repoPath = $candidates[0]
  $parent   = Split-Path $repoPath -Parent
  if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Force $parent | Out-Null }
  Write-Host "  Clonando repositorio em: $repoPath" -ForegroundColor Cyan
  git clone --quiet $RepoUrl $repoPath
  Write-Host "  Repo clonado com sucesso" -ForegroundColor Green
}

Write-Host ""

# ── 3. INSTALAR COMANDO /wiki ─────────────────────────────
$claudeCmd = Join-Path $HOME ".claude\commands"
if (-not (Test-Path $claudeCmd)) {
  New-Item -ItemType Directory -Force $claudeCmd | Out-Null
}

$wikiSrc = Join-Path $repoPath "wiki-command.md"
$wikiDst = Join-Path $claudeCmd "wiki.md"

if (-not (Test-Path $wikiSrc)) {
  Write-Host "  Criando comando /wiki..." -ForegroundColor Cyan
  @'
Documenta essa sessao no wiki da Onze Work para o cliente: $ARGUMENTS

Siga exatamente esses passos:

1. Identifica o nome do projeto principal desenvolvido nessa sessao (slug em kebab-case, ex: erp-integracao, lead-distribuicao)

2. Verifica se o repo ja esta clonado. Procure em:
   - C:\Users\[usuario]\Documents\projects-vscode\knowledge-wiki-onze
   - C:\projetos\knowledge-wiki-onze
   - ~/knowledge-wiki-onze
   Se nao encontrar, clona: https://github.com/vctorAgto/knowledge-wiki-onze.git
   Depois de clonar ou encontrar, faz git pull para garantir que esta atualizado.

3. Garante que as pastas existem:
   docs/clientes/$ARGUMENTS/
   docs/clientes/$ARGUMENTS/projetos/

4. Se a pasta docs/clientes/$ARGUMENTS/ NAO existia antes, cria o arquivo:
   docs/clientes/$ARGUMENTS/_category_.json
   com o conteudo:
   {
     "label": "[Nome do Cliente em Titulo Case]",
     "position": 99,
     "collapsible": true,
     "collapsed": false
   }

5. Se a pasta docs/clientes/$ARGUMENTS/projetos/ NAO existia antes, cria o arquivo:
   docs/clientes/$ARGUMENTS/projetos/_category_.json
   com o conteudo:
   {
     "label": "Projetos",
     "position": 1,
     "collapsible": true,
     "collapsed": false
   }

6. Cria ou abre o arquivo:
   docs/clientes/$ARGUMENTS/projetos/[nome-do-projeto].md

7. Se o arquivo e novo, comeca com esse cabecalho:
   ---
   title: [Nome do Projeto em Titulo Case]
   description: [Uma linha descrevendo o projeto]
   tags: [$ARGUMENTS]
   ---

   # [Nome do Projeto]

8. Pega o nome do autor com: git config user.name
   Se falhar, usa o email do usuario atual da sessao.

9. Adiciona a seguinte secao ao FINAL do arquivo (nunca edita o que ja existe):

   ## [DATA-HOJE-YYYY-MM-DD] - [Nome do Autor]

   ### O que foi solicitado
   [Resumo em bullets do que foi pedido nessa sessao]

   ### O que foi feito
   [Resumo em bullets do que foi implementado/resolvido]

10. Commita e faz push:
    git add docs/clientes/$ARGUMENTS/
    git commit -m "docs($ARGUMENTS): documenta sessao [nome-do-projeto]"
    git push origin main

Regras importantes:
- NUNCA apaga ou edita secoes existentes no arquivo
- Cada /wiki adiciona UMA nova secao ## no final
- Usa bullets (-) nos resumos, sem paragrafos longos
- O slug do projeto deve ser consistente entre sessoes do mesmo projeto
- O push aciona o GitHub Actions que atualiza o site em ~2 minutos
'@ | Out-File -FilePath $wikiDst -Encoding utf8
} else {
  Get-Content $wikiSrc -Raw | Out-File -FilePath $wikiDst -Encoding utf8
}

Write-Host "  Comando /wiki instalado em: $wikiDst" -ForegroundColor Green
Write-Host ""

# ── 4. INSTRUCOES FINAIS ──────────────────────────────────
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Setup concluido!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Como usar:" -ForegroundColor Yellow
Write-Host "    No Claude Code, ao final de qualquer sessao:" -ForegroundColor White
Write-Host "    /wiki prime-results" -ForegroundColor Cyan
Write-Host "    /wiki icasa" -ForegroundColor Cyan
Write-Host "    /wiki [nome-do-cliente]" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Para ver o historico:" -ForegroundColor Yellow
$relScript = Join-Path $repoPath "relatorio-sessoes.ps1"
Write-Host "    $relScript" -ForegroundColor Cyan
Write-Host ""
