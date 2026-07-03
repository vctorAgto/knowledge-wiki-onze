---
title: Portal de Conhecimento Interno
description: Setup do repositorio de documentacao interna com Docusaurus, GitHub Pages e comando /wiki para Claude Code
tags: [onze-work, docusaurus, github-pages, devops]
---

# Portal de Conhecimento Interno

## 2026-07-03 — Victor Pecuch

### O que foi solicitado

- Criar um script/dashboard visual que leia o historico do repositorio Git e mostre por cliente, projeto e sessao Claude o que foi pedido, por quem e quando
- Usar logo e tema Onze (lima `#CAFF4D` + dark navy `#0A1929`)
- Criar script para distribuir para outros membros da equipe
- Limpar o repositorio `knowledge-wiki-onze` e comecar do zero com estrutura mais simples
- Configurar Docusaurus para publicar o wiki via GitHub Pages
- Criar `setup.ps1` para novos membros da equipe instalarem o comando `/wiki`

### O que foi feito

- Criado dashboard HTML (`relatorio-sessoes.ps1`) que le os arquivos markdown do repo e gera relatorio visual com tema Onze (dark navy + lima), filtro por cliente e busca por sessao
- Parser PowerShell para markdown suporta dois formatos: `## YYYY-MM-DD — Autor` e `### data — descricao` (sob `## Solicitacoes`)
- Dashboard publicado como Artifact em claude.ai com dados reais de Prime Results e iCasa
- Repositorio `knowledge-wiki-onze` limpo: removidos todos os docs antigos, Docusaurus legado (v3.6 com bug de webpack) e Wiki.js
- Instalado Docusaurus 3.10.1 (versao que corrige incompatibilidade com Node.js 24)
- Configurado GitHub Actions (`deploy.yml`) para build automatico e deploy no GitHub Pages a cada push em `main`
- Criado `setup.ps1`: script que novos membros rodam uma vez — configura git name/email, clona o repo e instala o comando `/wiki` no Claude Code da maquina deles
- Atualizado comando `/wiki` para escrever em `docs/clientes/` (path correto para Docusaurus)
- Atualizado `relatorio-sessoes.ps1` para buscar em `docs/clientes/` com fallback para `clientes/`
- GitHub Pages ativado no repo — site disponivel em `https://vctorAgto.github.io/knowledge-wiki-onze/`
