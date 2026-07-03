# knowledge-wiki-onze

Base de conhecimento interna da Onze Work.
Cada sessao com Claude e documentada aqui, separada por cliente e projeto.

---

## Estrutura

```
clientes/
  [cliente]/
    projetos/
      [projeto].md   <- uma sessao por secao ##
```

---

## Como documentar (no final de cada sessao)

No final de qualquer sessao com Claude, rode dentro do Claude Code:

```
/wiki [nome-do-cliente]
```

Exemplos:
```
/wiki prime-results
/wiki icasa
/wiki ces
```

O Claude documenta automaticamente o que foi pedido e o que foi feito,
e envia para este repositorio.

---

## Setup (primeira vez na maquina)

```powershell
.\setup.ps1
```

O script instala o comando /wiki no Claude Code da sua maquina.

---

## Ver historico (relatorio)

```powershell
.\relatorio-sessoes.ps1
```

Abre um dashboard HTML com todas as sessoes por cliente e projeto.
