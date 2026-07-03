---
title: Integração ERP (Contas e Notas Fiscais)
description: Sincronização de Contas e dados fiscais da iCasa com o ERP — campos, validações, endereços e Município IBGE
tags: [icasa, salesforce]
---

# Integração ERP (Contas e Notas Fiscais)

## 2026-07-03 — Victor Pecuch

### O que foi solicitado

- Adicionar na Nota Fiscal os campos pedidos pelo cliente: Base de Cálculo ICMS, Valor do ICMS, Base de Cálculo ICMS/ST, Valor do ICMS/ST, Valor do Desconto, Valor Outras Despesas, Valor do IPI
- Reorganizar o layout de `NotaFiscal__c` na seção "Valores" seguindo a ordem definida pelo cliente
- Ajustar o JSON de exemplo da integração com os novos campos
- Ajustar regras de validação de endereço do Account para dispensar contas que já vieram do ERP (com `ExternalID__c` ou `AccountCode__c` preenchido)
- Preencher os campos `number` e `billingNumber` no payload de integração de Conta com o ERP
- Enviar o Código IBGE do Município no `deliveryPlaces` do payload
- Investigar por que o campo Município IBGE ficava vazio nos Endereços Complementares
- Enviar o Custo do Frete (`CustoFrete__c`) no payload de `deliveryPlaces`

### O que foi feito

- Criados 7 campos Currency em `NotaFiscal__c`: `BaseCalculoICMS__c`, `ValorICMS__c`, `BaseCalculoICMSST__c`, `ValorICMSST__c`, `ValorDesconto__c`, `ValorOutrasDespesas__c`, `ValorIPI__c`
- Reorganizada a seção "Valores" do layout "Layout de Nota Fiscal" na ordem pedida, reaproveitando campos já existentes (`ValorMercado__c`, `ValorFrete__c`, `ValorSeguro__c`, `ValorTotal__c`) — confirmado que `TipoFaturamento__c` já estava no layout
- Ajustadas as validation rules de endereço do Account para só exigir preenchimento quando a conta não tiver nem `ExternalID__c` nem `AccountCode__c` (cliente novo, sem vínculo com o ERP)
- Identificado (e reportado ao cliente, decisão pendente): o campo `Account.Transportadora__c` tem `defaultValue = true`, então toda conta nova nasce "marcada" como transportadora e escapa da validação de endereço obrigatório
- `ERPContaService.cls`: preenchidos `number` e `billingNumber` no payload, reaproveitando a variável `billingNumero` já calculada (fallback Faturamento → Cobrança)
- `ERPContaService.cls` e `ERPContaIntegrationBatch.cls`: adicionado `MunicipioIBGE__r.CodigoIBGE__c` na query de `EnderecoComplementar__c` e no `ibgeCode` do `deliveryPlaces`
- Diagnosticado por que `MunicipioIBGE__c` ficava vazio nos `EnderecoComplementar__c`: o flow `FlTriggerEnderecoComplementarAtualizaMunicipioIBGE` estava com status Obsoleto — reativado
- Corrigido bug de acentuação nas fórmulas dos flows `FlTriggerEnderecoComplementarAtualizaMunicipioIBGE` e `FlTriggerContaAtualizaMunicipioIBGE`: a substituição de acentos não tratava o "ç", então cidades como Bragança Paulista e Conceição nunca batiam com a tabela de Município IBGE
- Identificado backlog de ~7.250 registros de `EnderecoComplementar__c` com Município IBGE vazio — backfill combinado, ainda pendente de execução
- Corrigido erro HTTP 500 (code 17006) na sincronização com o ERP: `ibgeCode` estava sendo enviado como string; corrigido para `Integer.valueOf(...)`, resolvendo o erro e destravando a integração
- Adicionado `freightPercentage` (`CustoFrete__c`) no payload de `deliveryPlaces` — nome da chave inferido por convenção (ainda não confirmado oficialmente com o time do ERP); testado com sucesso após o fix do `ibgeCode`
