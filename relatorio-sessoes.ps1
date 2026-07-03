<#
.SYNOPSIS
  Gera um dashboard HTML com o historico de sessoes Claude por cliente/projeto.

.PARAMETER RepoPath
  Caminho local do repositorio knowledge-wiki-onze.
  Se nao existir, faz clone automatico.

.PARAMETER Output
  Arquivo HTML de saida. Padrao: relatorio-sessoes.html na pasta do script.

.EXAMPLE
  .\relatorio-sessoes.ps1
  .\relatorio-sessoes.ps1 -RepoPath "C:\projetos\knowledge-wiki-onze" -Output "C:\relatorio.html"
#>
param(
  [string]$RepoPath = (Join-Path $PSScriptRoot "knowledge-wiki-onze"),
  [string]$Output   = (Join-Path $PSScriptRoot "relatorio-sessoes.html"),
  [string]$RepoUrl  = "https://github.com/vctorAgto/knowledge-wiki-onze.git"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

# ── 1. CLONAR / ATUALIZAR ─────────────────────────────────
if (-not (Test-Path (Join-Path $RepoPath ".git"))) {
  Write-Host "Clonando repositorio..." -ForegroundColor Cyan
  git clone --quiet $RepoUrl $RepoPath
} else {
  Write-Host "Atualizando repositorio..." -ForegroundColor Cyan
  Push-Location $RepoPath
  git pull --rebase --quiet origin main
  Pop-Location
}

$clientesDir = Join-Path $RepoPath "clientes"
if (-not (Test-Path $clientesDir)) {
  Write-Error "Diretorio 'clientes/' nao encontrado em $RepoPath"
  exit 1
}

# ── 2. HELPERS HTML ──────────────────────────────────────
function Escape-Html([string]$s) {
  $s -replace '&','&amp;' `
     -replace '<','&lt;'  `
     -replace '>','&gt;'  `
     -replace '"','&quot;'
}

function Render-Code([string]$s) {
  [regex]::Replace($s, '`([^`]+)`', {
    param($m)
    $inner = (Escape-Html $m.Groups[1].Value)
    "<code style=""font-family:var(--mono);font-size:10.5px;color:var(--lime);background:var(--lime-dim);padding:0 3px;border-radius:3px"">$inner</code>"
  })
}

function Block-To-Html([string]$block) {
  $lines   = @($block -split '\r?\n' | Where-Object { $_.Trim() -ne '' })
  $bullets = @($lines | Where-Object { $_ -match '^\s*[-*]' })
  if ($bullets.Count -gt 0) {
    $items = $bullets | ForEach-Object {
      $t = $_ -replace '^\s*[-*]\s*',''
      $t = Escape-Html $t
      $t = Render-Code $t
      "<li>$t</li>"
    }
    return "<ul class='d-list'>$($items -join '')</ul>"
  }
  $text = ($lines -join ' ').Trim()
  $text = Escape-Html $text
  $text = Render-Code $text
  return "<span class='d-text'>$text</span>"
}

# ── 3. PARSER DE MARKDOWN ────────────────────────────────
function Parse-Sessions {
  param([string]$Path)

  $utf8 = [System.Text.Encoding]::UTF8
  $raw  = [System.IO.File]::ReadAllText($Path, $utf8)
  $raw  = $raw.TrimStart([char]0xFEFF)
  # Remove frontmatter
  $raw = [regex]::Replace($raw, '(?s)^---.*?---\s*', '')

  $out     = New-Object 'System.Collections.Generic.List[hashtable]'
  $lines   = $raw -split '\r?\n'
  $dateRx  = [regex]'(\d{4}-\d{2}-\d{2})|(\d{2}/\d{2}/\d{4})'
  $nameRx  = [regex]'(?:--|[-])\s*([A-Z][a-z]+(?:\s+[A-Z][a-z]+)+)'

  $cur     = $null     # current session hashtable
  $section = $null     # 'sol' | 'feito' | $null
  $buf     = New-Object 'System.Collections.Generic.List[string]'
  $inSolic = $false    # inside ## Solicitacoes block

  # inline: flush buffer into current session
  # (replaces inner function to avoid PS scoping issues)

  foreach ($line in $lines) {

    # ── H2 heading ──────────────────────────────────
    if ($line -match '^##\s+(.+)') {
      $h = $Matches[1].Trim()

      # Entering a "Solicitacoes" container block
      if ($h -match 'Solicita') {
        $inSolic = $true
        # flush + close current session if any
        if ($null -ne $cur) {
          if ($null -ne $section -and $buf.Count -gt 0) {
            $t = ($buf.ToArray() -join "`n").Trim()
            if ($section -eq 'sol') { $cur['Sol'] += $t } else { $cur['Feito'] += $t }
            $buf.Clear()
          }
          $out.Add($cur); $cur = $null
        }
        $section = $null; $buf.Clear()
        continue
      }

      $inSolic = $false

      $dm = $dateRx.Match($h)
      if ($dm.Success) {
        # flush + close current session
        if ($null -ne $cur) {
          if ($null -ne $section -and $buf.Count -gt 0) {
            $t = ($buf.ToArray() -join "`n").Trim()
            if ($section -eq 'sol') { $cur['Sol'] += $t } else { $cur['Feito'] += $t }
            $buf.Clear()
          }
          $out.Add($cur)
        }
        $buf.Clear()

        # Parse date
        if ($dm.Groups[1].Success) {
          $iso = $dm.Groups[1].Value
        } else {
          $p = $dm.Groups[2].Value -split '/'
          $iso = "$($p[2])-$($p[1])-$($p[0])"
        }
        $disp = "$($iso.Substring(8,2))/$($iso.Substring(5,2))/$($iso.Substring(0,4))"

        # Author from "— Name" pattern
        $author = 'Victor Pecuch'
        $nm = $nameRx.Match($h)
        if ($nm.Success) { $author = $nm.Groups[1].Value.Trim() }

        # Title: extract description from parens if present, else "Sessao Claude"
        $title = 'Sessao Claude'
        if ($h -match '\(([^)]+)\)') { $title = $Matches[1].Trim() }

        $cur = @{ DateISO=''; DateDisp=''; Author=''; Title=''; Sol=''; Feito='' }
        $cur['DateISO']  = $iso
        $cur['DateDisp'] = $disp
        $cur['Author']   = $author
        $cur['Title']    = $title
        $section = $null; $buf.Clear()
        continue
      }

      # Plain H2 (not date, not Solicitacoes) - flush & close
      if ($null -ne $cur) {
        if ($null -ne $section -and $buf.Count -gt 0) {
          $t = ($buf.ToArray() -join "`n").Trim()
          if ($section -eq 'sol') { $cur['Sol'] += $t } else { $cur['Feito'] += $t }
          $buf.Clear()
        }
        $out.Add($cur); $cur = $null
      }
      $section = $null; $buf.Clear()
      continue
    }

    # ── H3 heading ──────────────────────────────────
    if ($line -match '^###\s+(.+)') {
      $h3 = $Matches[1].Trim()

      # Session header under Solicitacoes (e.g. ### 30/06 - description)
      if ($inSolic -and $dateRx.IsMatch($h3)) {
        if ($null -ne $cur) {
          if ($null -ne $section -and $buf.Count -gt 0) {
            $t = ($buf.ToArray() -join "`n").Trim()
            if ($section -eq 'sol') { $cur['Sol'] += $t } else { $cur['Feito'] += $t }
            $buf.Clear()
          }
          $out.Add($cur)
        }
        $buf.Clear()

        $dm = $dateRx.Match($h3)
        if ($dm.Groups[1].Success) {
          $iso = $dm.Groups[1].Value
        } else {
          $p = $dm.Groups[2].Value -split '/'
          $iso = "$($p[2])-$($p[1])-$($p[0])"
        }
        $disp = "$($iso.Substring(8,2))/$($iso.Substring(5,2))/$($iso.Substring(0,4))"

        # Title: everything after the date separator
        $title = [regex]::Replace($h3, $dateRx.ToString(), '').TrimStart(' -').Trim()
        $title = [regex]::Replace($title, '^[^A-Za-z0-9]+', '').Trim()
        if (-not $title) { $title = $h3 }

        $cur = @{ DateISO=''; DateDisp=''; Author=''; Title=''; Sol=''; Feito='' }
        $cur['DateISO']  = $iso
        $cur['DateDisp'] = $disp
        $cur['Author']   = 'Victor Pecuch'
        $cur['Title']    = $title
        $section = $null; $buf.Clear()
        continue
      }

      # Section label inside a session
      if ($null -ne $cur) {
        if ($null -ne $section -and $buf.Count -gt 0) {
          $t = ($buf.ToArray() -join "`n").Trim()
          if ($section -eq 'sol') { $cur['Sol'] += $t } else { $cur['Feito'] += $t }
          $buf.Clear()
        }
        if ($h3 -match '(?i)solicit|pedid') { $section = 'sol' }
        elseif ($h3 -match '(?i)feito')     { $section = 'feito' }
        else                                 { $section = $null }
        $buf.Clear()
      }
      continue
    }

    # ── Bold label: **O que foi pedido:** / **O que foi feito:** ──
    if ($null -ne $cur) {
      if ($line -match '^\*\*O que foi pedido|^\*\*O que foi solicit') {
        if ($null -ne $section -and $buf.Count -gt 0) {
          $t = ($buf.ToArray() -join "`n").Trim()
          if ($section -eq 'sol') { $cur['Sol'] += $t } else { $cur['Feito'] += $t }
          $buf.Clear()
        }
        $section = 'sol'; $buf.Clear(); continue
      }
      if ($line -match '^\*\*O que foi feito') {
        if ($null -ne $section -and $buf.Count -gt 0) {
          $t = ($buf.ToArray() -join "`n").Trim()
          if ($section -eq 'sol') { $cur['Sol'] += $t } else { $cur['Feito'] += $t }
          $buf.Clear()
        }
        $section = 'feito'; $buf.Clear(); continue
      }
    }

    # ── Body accumulation ──────────────────────────
    if ($null -ne $cur -and $null -ne $section) {
      $buf.Add($line)
    }
  }

  # flush last session
  if ($null -ne $cur) {
    if ($null -ne $section -and $buf.Count -gt 0) {
      $t = ($buf.ToArray() -join "`n").Trim()
      if ($section -eq 'sol') { $cur['Sol'] += $t } else { $cur['Feito'] += $t }
    }
    $out.Add($cur)
  }

  return ,$out
}

# ── 4. SCAN DO REPO ──────────────────────────────────────
Write-Host "Lendo arquivos..." -ForegroundColor Cyan

$data = New-Object 'System.Collections.Generic.List[hashtable]'

Get-ChildItem -Path $clientesDir -Directory | Sort-Object Name | ForEach-Object {
  $cDir  = $_
  $cId   = $cDir.Name
  $cName = (Get-Culture).TextInfo.ToTitleCase(($cId -replace '-',' '))

  $idxFile = Join-Path $cDir.FullName "index.md"
  if (Test-Path $idxFile) {
    $idxRaw = [System.IO.File]::ReadAllText($idxFile, [System.Text.Encoding]::UTF8)
    if ($idxRaw -match 'title:\s*"?([^"\r\n]+)"?') { $cName = $Matches[1].Trim() }
  }

  $projDir = Join-Path $cDir.FullName "projetos"
  if (-not (Test-Path $projDir)) { return }

  $projs = New-Object 'System.Collections.Generic.List[hashtable]'

  Get-ChildItem -Path $projDir -Filter "*.md" | Sort-Object Name | ForEach-Object {
    $mdFile = $_
    $projId = [System.IO.Path]::GetFileNameWithoutExtension($mdFile.Name)
    $pName  = (Get-Culture).TextInfo.ToTitleCase(($projId -replace '-',' '))
    $pDesc  = ''
    $pTags  = @()

    $fmRaw = [System.IO.File]::ReadAllText($mdFile.FullName, [System.Text.Encoding]::UTF8)
    if ($fmRaw -match 'title:\s*"?([^"\r\n]+)"?')       { $pName = $Matches[1].Trim() }
    if ($fmRaw -match 'description:\s*"?([^"\r\n]+)"?') { $pDesc = $Matches[1].Trim() }
    if ($fmRaw -match 'tags:\s*([^\r\n]+)') {
      $pTags = $Matches[1].Trim() -split '[,\s]+' |
               Where-Object { $_ -and $_ -ne $cId } |
               ForEach-Object { $_.Trim() } |
               Select-Object -First 5
    }

    $sessions = Parse-Sessions -Path $mdFile.FullName
    if ($null -eq $sessions -or $sessions.Count -eq 0) { return }

    $p = @{ Id=''; Name=''; Desc=''; Tags=@(); Sessions=$null }
    $p['Id']       = $projId
    $p['Name']     = $pName
    $p['Desc']     = $pDesc
    $p['Tags']     = $pTags
    $p['Sessions'] = $sessions
    $projs.Add($p)
  }

  if ($projs.Count -eq 0) { return }

  $c = @{ Id=''; Name=''; Projetos=$null }
  $c['Id']       = $cId
  $c['Name']     = $cName
  $c['Projetos'] = $projs
  $data.Add($c)
}

$nClients  = $data.Count
$nProjects = 0; $data | ForEach-Object { $nProjects += $_.Projetos.Count }
$nSessions = 0; $data | ForEach-Object { $_.Projetos | ForEach-Object { $nSessions += $_.Sessions.Count } }
$genDate   = Get-Date -Format "dd/MM/yyyy 'as' HH:mm"

Write-Host "  $nClients clientes / $nProjects projetos / $nSessions sessoes" -ForegroundColor Green

# ── 5. HTML ───────────────────────────────────────────────
Write-Host "Gerando HTML..." -ForegroundColor Cyan
$sb = New-Object System.Text.StringBuilder

function o([string]$s) { [void]$sb.AppendLine($s) }

o '<!DOCTYPE html>'
o '<html lang="pt-BR"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
o '<title>Onze - Historico de Sessoes Claude</title>'
o '<style>
:root{
  --navy:#0A1929;--navy-mid:#0F2237;--navy-light:#162d44;--navy-bd:#1e3952;
  --lime:#CAFF4D;--lime-dim:rgba(202,255,77,.10);--lime-bd:rgba(202,255,77,.22);--lime-ink:#0A1929;
  --text:#dbe8f4;--muted:#6b8fad;--faint:#344f66;
  --sidebar-w:228px;--radius:7px;
  --font:"Segoe UI",-apple-system,BlinkMacSystemFont,system-ui,sans-serif;
  --mono:"Cascadia Code","Consolas","SF Mono",monospace;
}
*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
html{scroll-behavior:smooth}
body{background:var(--navy);color:var(--text);font-family:var(--font);font-size:13.5px;line-height:1.6;min-height:100vh}
::-webkit-scrollbar{width:5px}::-webkit-scrollbar-track{background:transparent}::-webkit-scrollbar-thumb{background:var(--navy-bd);border-radius:3px}
.header{position:sticky;top:0;z-index:100;background:var(--navy-mid);border-bottom:1px solid var(--navy-bd);height:54px;display:flex;align-items:center;gap:14px;padding:0 24px}
.logo{background:var(--lime);color:var(--lime-ink);font-weight:800;font-size:13px;letter-spacing:-.4px;padding:5px 11px;border-radius:5px;line-height:1;flex-shrink:0}
.hsep{width:1px;height:22px;background:var(--navy-bd)}
.htitle{font-size:14.5px;font-weight:600;letter-spacing:-.2px}
.hstats{display:flex;align-items:center;gap:18px;margin-left:auto}
.stat{display:flex;align-items:center;gap:5px;font-size:11.5px;color:var(--muted)}
.stat b{font-weight:700;font-variant-numeric:tabular-nums;color:var(--lime)}
.hdate{font-size:11px;color:var(--faint);border-left:1px solid var(--navy-bd);padding-left:14px}
.layout{display:flex;min-height:calc(100vh - 54px)}
.sidebar{width:var(--sidebar-w);flex-shrink:0;background:var(--navy-mid);border-right:1px solid var(--navy-bd);padding:16px 0 24px;position:sticky;top:54px;height:calc(100vh - 54px);overflow-y:auto}
.sh{font-size:9.5px;font-weight:700;letter-spacing:.09em;text-transform:uppercase;color:var(--faint);padding:0 16px;margin-bottom:6px}
.ssearch{padding:0 12px 10px}
.ssearch input{width:100%;background:var(--navy-light);border:1px solid var(--navy-bd);border-radius:5px;padding:6px 10px;color:var(--text);font-size:12px;font-family:var(--font);outline:none;transition:border-color .15s}
.ssearch input:focus{border-color:var(--lime-bd)}
.ssearch input::placeholder{color:var(--faint)}
.ni{display:flex;align-items:center;gap:8px;padding:7px 16px;cursor:pointer;border-left:3px solid transparent;color:var(--muted);font-size:12.5px;transition:background .1s,color .1s}
.ni:hover{background:var(--lime-dim);color:var(--text)}
.ni.active{background:var(--lime-dim);border-left-color:var(--lime);color:var(--text);font-weight:500}
.nc{margin-left:auto;font-size:10px;font-weight:700;font-variant-numeric:tabular-nums;background:var(--navy-light);color:var(--muted);padding:1px 6px;border-radius:10px}
.ni.active .nc{background:var(--lime);color:var(--lime-ink)}
.sdiv{height:1px;background:var(--navy-bd);margin:10px 14px}
.main{flex:1;min-width:0;padding:28px 36px 60px}
.csec{margin-bottom:44px}
.csec.hidden{display:none}
.ch{display:flex;align-items:center;gap:12px;margin-bottom:22px}
.ci{width:34px;height:34px;border-radius:8px;background:var(--lime);color:var(--lime-ink);font-weight:800;font-size:15px;display:flex;align-items:center;justify-content:center;flex-shrink:0}
.cn{font-size:19px;font-weight:700;letter-spacing:-.4px;line-height:1.2}
.cs{font-size:11px;color:var(--muted);margin-top:1px}
.cpills{margin-left:auto;display:flex;gap:6px}
.pill{font-size:10.5px;font-weight:600;padding:3px 9px;border-radius:4px;background:var(--navy-light);color:var(--muted);border:1px solid var(--navy-bd);white-space:nowrap}
.pill.l{background:var(--lime-dim);color:var(--lime);border-color:var(--lime-bd)}
.pg{padding-left:22px;border-left:1.5px solid var(--navy-bd);margin-bottom:24px;position:relative}
.pg::before{content:"";position:absolute;left:-5px;top:12px;width:8px;height:8px;border-radius:50%;background:var(--lime)}
.ph{display:flex;align-items:flex-start;gap:10px;margin-bottom:10px;flex-wrap:wrap}
.pn{font-size:13.5px;font-weight:600;letter-spacing:-.1px}
.pd{font-size:11.5px;color:var(--muted);margin-top:1px}
.tags{display:flex;gap:4px;flex-wrap:wrap;margin-left:auto}
.tag{font-size:9.5px;font-weight:600;letter-spacing:.03em;padding:2px 6px;border-radius:3px;background:var(--lime-dim);color:var(--lime);border:1px solid var(--lime-bd)}
.card{background:var(--navy-mid);border:1px solid var(--navy-bd);border-radius:var(--radius);margin-bottom:7px;overflow:hidden;transition:border-color .15s}
.card:hover{border-color:var(--lime-bd)}
.card-h{display:flex;align-items:flex-start;gap:10px;padding:12px 14px;cursor:pointer;user-select:none}
.sdate{font-size:10px;font-weight:700;font-variant-numeric:tabular-nums;letter-spacing:.02em;color:var(--lime);background:var(--lime-dim);border:1px solid var(--lime-bd);padding:3px 7px;border-radius:4px;white-space:nowrap;flex-shrink:0;margin-top:2px;font-family:var(--mono)}
.sbody{flex:1;min-width:0}
.stitle{font-size:13px;font-weight:500;line-height:1.45;text-wrap:balance}
.sauthor{font-size:11px;color:var(--muted);margin-top:3px}
.chev{color:var(--faint);flex-shrink:0;width:16px;text-align:center;margin-top:2px;transition:transform .18s ease;font-style:normal;font-size:10px;line-height:1.8}
.card.open .chev{transform:rotate(180deg)}
.card-body{display:none;padding:0 14px 14px;border-top:1px solid var(--navy-bd)}
.card.open .card-body{display:block}
.dl{margin-top:12px}
.dlabel{font-size:9px;font-weight:800;letter-spacing:.1em;text-transform:uppercase;color:var(--faint);margin-bottom:6px}
.d-text{font-size:12.5px;color:var(--muted);line-height:1.7}
.d-list{list-style:none;display:flex;flex-direction:column;gap:3px}
.d-list li{font-size:12px;color:var(--muted);line-height:1.6;padding-left:16px;position:relative}
.d-list li::before{content:">";position:absolute;left:0;top:0;color:var(--lime);font-size:11px;font-weight:700;line-height:1.7}
.empty{text-align:center;padding:60px 0;color:var(--faint);font-size:13px}
@media(max-width:680px){:root{--sidebar-w:0}.sidebar{display:none}.main{padding:20px 16px 48px}.hstats{display:none}}
</style></head><body>'

# Header
o "<div class='header'>"
o "  <span class='logo'>onze</span><span class='hsep'></span>"
o "  <span class='htitle'>Historico de Sessoes Claude</span>"
o "  <div class='hstats'>"
o "    <span class='stat'><b>$nClients</b> clientes</span>"
o "    <span class='stat'><b>$nProjects</b> projetos</span>"
o "    <span class='stat'><b>$nSessions</b> sessoes</span>"
o "    <span class='hdate'>Gerado em $genDate</span>"
o "  </div>"
o "</div>"
o "<div class='layout'>"

# Sidebar
o "<nav class='sidebar'>"
o "  <div class='ssearch'><input type='text' id='q' placeholder='Buscar...' autocomplete='off' /></div>"
o "  <div class='sh'>Clientes</div>"
o "  <div class='ni active' data-f='all' onclick='fc(this,""all"")'>"
o "    Todos <span class='nc'>$nSessions</span>"
o "  </div>"
o "  <div class='sdiv'></div>"
foreach ($c in $data) {
  $cSess = 0; $c.Projetos | ForEach-Object { $cSess += $_.Sessions.Count }
  $cIdH  = Escape-Html $c.Id
  $cNmH  = Escape-Html $c.Name
  o "  <div class='ni' data-f='$cIdH' onclick='fc(this,""$cIdH"")'>"
  o "    $cNmH <span class='nc'>$cSess</span>"
  o "  </div>"
}
o "</nav>"

# Main
o "<main class='main'>"

foreach ($c in $data) {
  $cIdH   = Escape-Html $c.Id
  $cNmH   = Escape-Html $c.Name
  $cProjs = $c.Projetos.Count
  $cSess  = 0; $c.Projetos | ForEach-Object { $cSess += $_.Sessions.Count }
  $init   = if ($c.Name.Length -gt 0) { [char]::ToUpper($c.Name[0]) } else { '?' }
  $pWord  = if ($cProjs -eq 1) { 'projeto' } else { 'projetos' }
  $sWord  = if ($cSess  -eq 1) { 'sessao'  } else { 'sessoes'  }

  o "<section class='csec' data-client='$cIdH'>"
  o "  <div class='ch'>"
  o "    <div class='ci'>$init</div>"
  o "    <div><div class='cn'>$cNmH</div><div class='cs'>Salesforce</div></div>"
  o "    <div class='cpills'><span class='pill'>$cProjs $pWord</span><span class='pill l'>$cSess $sWord</span></div>"
  o "  </div>"

  foreach ($p in $c.Projetos) {
    $pNmH   = Escape-Html $p.Name
    $pDsH   = Escape-Html $p.Desc
    $tagsH  = ($p.Tags | Select-Object -First 4 | ForEach-Object { "<span class='tag'>$(Escape-Html $_)</span>" }) -join ''

    o "  <div class='pg'>"
    o "    <div class='ph'>"
    o "      <div><div class='pn'>$pNmH</div>"
    if ($pDsH) { o "      <div class='pd'>$pDsH</div>" }
    o "      </div>"
    if ($tagsH) { o "      <div class='tags'>$tagsH</div>" }
    o "    </div>"

    foreach ($s in $p.Sessions) {
      $titH    = Escape-Html $s['Title']
      $authH   = Escape-Html $s['Author']
      $dispH   = Escape-Html $s['DateDisp']
      $solHtml = if ($s['Sol']) { Block-To-Html $s['Sol'] } else { "<span class='d-text'>-</span>" }
      $ftoHtml = if ($s['Feito']) { Block-To-Html $s['Feito'] } else { "<span class='d-text'>-</span>" }

      o "    <div class='card' onclick='tog(this)'>"
      o "      <div class='card-h'>"
      o "        <span class='sdate'>$dispH</span>"
      o "        <div class='sbody'>"
      o "          <div class='stitle'>$titH</div>"
      o "          <div class='sauthor'>$authH</div>"
      o "        </div>"
      o "        <i class='chev'>v</i>"
      o "      </div>"
      o "      <div class='card-body'>"
      o "        <div class='dl'><div class='dlabel'>O que foi solicitado</div>$solHtml</div>"
      o "        <div class='dl'><div class='dlabel'>O que foi feito</div>$ftoHtml</div>"
      o "      </div>"
      o "    </div>"
    }

    o "  </div>"
  }

  o "</section>"
}

o "<div class='empty' id='emp' style='display:none'>Nenhuma sessao encontrada.</div>"
o "</main></div>"

o "<script>"
o "function tog(el){el.classList.toggle('open')}"
o "function fc(n,id){"
o "  document.querySelectorAll('.ni').forEach(x=>x.classList.remove('active'));n.classList.add('active');"
o "  document.querySelectorAll('.csec').forEach(s=>s.classList.toggle('hidden',id!=='all'&&s.dataset.client!==id));"
o "  document.querySelectorAll('.pg,.card').forEach(x=>{x.style.display='';x.classList.remove('open')});"
o "  document.getElementById('q').value='';"
o "  document.getElementById('emp').style.display='none';"
o "}"
o "document.getElementById('q').addEventListener('input',function(){"
o "  const q=this.value.trim().toLowerCase();"
o "  if(!q){const a=document.querySelector('.ni.active');fc(a,a.dataset.f);return}"
o "  let n=0;"
o "  document.querySelectorAll('.csec').forEach(sec=>{"
o "    sec.classList.remove('hidden');let sf=0;"
o "    sec.querySelectorAll('.card').forEach(c=>{"
o "      const m=c.textContent.toLowerCase().includes(q);"
o "      c.style.display=m?'':'none';if(m){sf++;n++;c.classList.add('open')}else c.classList.remove('open');"
o "    });"
o "    sec.querySelectorAll('.pg').forEach(pg=>{"
o "      const v=[...pg.querySelectorAll('.card')].some(c=>c.style.display!=='none');"
o "      pg.style.display=v?'':'none';"
o "    });"
o "    sec.classList.toggle('hidden',sf===0);"
o "  });"
o "  document.getElementById('emp').style.display=n?'none':'';"
o "});"
o "</script></body></html>"

# ── 6. SALVAR ────────────────────────────────────────────
$html = $sb.ToString()
[System.IO.File]::WriteAllText($Output, $html, (New-Object System.Text.UTF8Encoding $false))
Write-Host ""
Write-Host "Relatorio gerado: $Output" -ForegroundColor Green
Write-Host "Abrindo no browser..." -ForegroundColor Cyan
Start-Process $Output
