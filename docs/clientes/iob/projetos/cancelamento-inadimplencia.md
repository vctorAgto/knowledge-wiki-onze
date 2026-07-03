---
title: Cancelamento por Inadimplência
description: LWC + integração Apex com a API do Satélite (IOB Vendas) para prévia e execução de cancelamento de clientes inadimplentes
tags: [iob]
---

# Cancelamento por Inadimplência

## 2026-07-03 — Victor Pecuch

### O que foi solicitado
- Criar um LWC que integre com a API do Satélite descrita no Swagger enviado pela IOB (`POST /api/v1/Cancelamento/CancelamentoPorInadimplencia`), com operações de Prévia (`PREV`) e Execução (`EXEC`)
- Layout do componente inspirado no modal existente "Aplicar Índice de Reajuste"
- Componente deve poder ser colocado na Home page (ou em qualquer outra tela) via App Builder
- Revisar um documento técnico (Master Contract / Renewal Nativo do CPQ) produzido por outro consultor antes de enviar ao cliente
- Ajudar a redigir e revisar comunicações técnicas com a equipe da IOB (Marília Caselli) sobre um timeout de integração

### O que foi feito
- Criado `CancelamentoInadimplenciaController` (Apex) com os métodos `previsualizarCancelamento` e `executarCancelamento`, reaproveitando a infraestrutura de integração já existente no org (`TokenDAO`, `TokenCadastroCliente__c`, `IntegrationOrderIOBBO.atualizarTokenAutenticacao()`, `ExternalIntegrationConfig__mdt`, `IntegrationLogs__c`) em vez de criar Named Credential nova
- Descoberto, via exploração do org, que já existe o padrão de integração "IOB Vendas" (mesmo host `iobvendas-integracao-ppr.iob.com.br`) usado por `CancelamentoFaturaController`/`CancelamentoFaturaQueueable`, `IntegrationOrderIOBBO`, etc. — o controller novo segue exatamente esse padrão
- Criado registro de Custom Metadata `ExternalIntegrationConfig.CancelamentoInadimplenciaController` com a URL real do endpoint e o `idSistema` compartilhado
- Corrigido bug real: `AuraHandledException` só entrega a mensagem customizada ao componente se `.setMessage()` for chamado explicitamente
- Criado o LWC `cancelamentoPorInadimplencia` (fluxo Prévia → confirmação → Execução, com layout em seções com divisórias e pares label/valor, seguindo referência visual do cliente), exposto para `lightning__HomePage`, `lightning__AppPage` e `lightning__RecordPage`
- Testes Apex (mock de HTTP) e testes Jest do LWC, todos passando (5/5 Apex, 3/3 Jest)
- Testado o callout real contra a API do Satélite: confirmado que a rota e a autenticação (token Bearer compartilhado) funcionam; identificado que a operação leva ~7 minutos no lado da IOB, incompatível com o limite rígido de 120s do Salesforce para callouts — repassado para a IOB a necessidade de um padrão assíncrono (polling ou callback via os endpoints `CancelamentoOperacaoRetorno`/`CancelamentoVoluntarioRetorno` já existentes no Swagger deles)
- Removidos componentes criados por engano numa primeira tentativa (Named Credential `Satelite_API` e Custom Metadata Type `SateliteConfig__mdt`) antes de descobrir o padrão correto já existente no org
- Revisão do documento "Renovação de Contratos, Master Contract e Migração para o Renewal Nativo do CPQ": identificado que as seções 5.2/5.6 citam classes e Flows fora do escopo declarado na seção 2, com nível de certeza ("✔ JÁ COBERTO", "Impacto confirmado") não condizente com o rigor do resto do documento
