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
