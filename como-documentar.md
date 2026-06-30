---
title: Como Documentar
description: Guia rápido para adicionar documentação
published: true
tags: guia
editor: markdown
---

# Como Documentar um Projeto

## 1. Clone o repositório

```bash
git clone git@github.com:vctorAgto/knowledge-wiki-onze.git
cd knowledge-wiki-onze
```

## 2. Copie o template

```bash
cp _templates/novo-projeto.md clientes/nome-cliente/projetos/nome-projeto.md
```

## 3. Edite o arquivo

Abra no VS Code, peça ajuda ao Claude e preencha.

## 4. Suba para o wiki

```bash
git add .
git commit -m "docs: nome do projeto"
git push
```

Pronto — a página aparece no wiki automaticamente.