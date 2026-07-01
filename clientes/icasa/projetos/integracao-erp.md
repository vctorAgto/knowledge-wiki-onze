---
title: Integração ERP
description: Integração do Salesforce com o ERP Datasul via API REST — simulação de impostos em Oportunidades e sincronização de Contas
published: true
tags: icasa
editor: markdown
---

# Integração ERP

Integração do Salesforce com o ERP Datasul (TOTVS) via API REST para simulação de impostos em Oportunidades e sincronização de Contas.

---

## 2026-07-01 — Victor Pecuch

### O que foi solicitado

- Corrigir erro de simulação de impostos em Oportunidades (`ERPOportunidadeService`): campo `Opportunity.Prazo__c` não estava sendo consultado no SOQL de `processRecords`, causando `SObjectException`
- Mapear campos do JSON de resposta do ERP para os campos customizados de `OpportunityLineItem`: `ValorPIS__c`, `BaseCalculoICMS__c`, `ValorCOFINS__c`, `ICMSValor__c`, `ValorDIFAL__c`, `ValorICMSST__c`, `ValorCFOP__c`, `TotalImpostosERP__c`
- Corrigir integração de Conta (`ERPContaService`) conforme email do cliente: `interstateTransactionType` sempre `"611VB"`, adicionar `stateTransactionType` sempre `"511VC"`, `salesChannel` fixo em `0`, `deliveryPlaces` deve incluir CNPJ e IE da conta de faturamento
- Criar classes de teste para `ERPContaService`/`ERPContaIntegrationBatch` e `ERPOportunidadeService`/`ERPOportunidadeIntegrationBatch`
- Criar classe de teste para `ViaCepFlowAction`

### O que foi feito

#### Correções na integração de Oportunidades (`ERPOportunidadeIntegrationBatch` + `ERPOportunidadeService`)

- Adicionado `Prazo__c` ao SOQL de `processRecords` e `start()` — campo estava faltando e causava `SObjectException`
- Adicionado `Industry` e `toLabel(Industry) IndustryLabel` aos SOQLs
- Corrigido vírgula faltando no SOQL de `start()` após `StandardCarrier__r.AccountCode__c`
- Adicionado parâmetro `Opportunity opp` ao método `processarResposta` para uso futuro
- Mapeamento de campos do JSON do ERP para `OpportunityLineItem`:

| Campo JSON ERP | Campo Salesforce OLI |
|---|---|
| `valor_pis` | `ValorPIS__c` |
| `base_calculo_icms` | `BaseCalculoICMS__c` |
| `valor_cofins` | `ValorCOFINS__c` |
| `valor_icms` | `ICMSValor__c` |
| `valor_difal` | `ValorDIFAL__c` |
| `valor_st` | `ValorICMSST__c` |
| `CFOP__c` (OLI, convertido) | `ValorCFOP__c` |
| soma icms+pis+cofins+st+ipi | `TotalImpostosERP__c` |

- Corrigido DML em OLI: criação de `new OpportunityLineItem(Id = oli.Id)` com apenas os campos a atualizar (campos read-only como `OpportunityId`, `Product2Id` causavam `CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY`)
- Adicionada captura de `Database.SaveResult` para expor erros silenciosos do `Database.update(list, false)`

#### Correções na integração de Conta (`ERPContaService` + `ERPContaIntegrationBatch`)

- `salesChannel` alterado de `11` para `0`
- `interstateTransactionType` alterado para sempre `"611VB"` (era condicional por UF)
- Adicionado `stateTransactionType` sempre `"511VC"`
- `deliveryPlaces.stateRegistration` → `conta.StateRegistration__c` (estava nulo)
- `deliveryPlaces.personalId` → `conta.CNPJ__c` (estava nulo)
- Corrigido NPE quando `StandardCarrier__c` é nulo: adicionado null check e try/catch
- Corrigido tipo de `AccountCode__c` (Decimal → String via `String.valueOf()`)
- Adicionado `Industry`, `toLabel(Industry) IndustryLabel` e `ContribuinteICMS__c` aos SOQLs de `start()` e `processRecords()`
- Corrigido vírgula faltando no SOQL de `start()`

#### Classes de teste criadas

**`ERPContaIntegrationTest`** — 8 testes (100% passando):
- `testNovaContaSucesso` — POST de nova conta retorna customerCode
- `testAtualizarContaExistente` — PUT usa endpoint com ExternalID
- `testValidacaoCamposObrigatorios` — lança exceção com campos faltando
- `testErroHTTP` — exceção com status 500
- `testPayloadCamposFixos` — verifica `interstateTransactionType`, `stateTransactionType` e `salesChannel`
- `testDeliveryPlacesComCNPJeIE` — verifica CNPJ e IE em `deliveryPlaces`
- `testBatchProcessRecordsSucesso` — batch seta `StatusIntegracao__c = 'Integrado com sucesso'`
- `testBatchProcessRecordsErro` — batch seta `StatusIntegracao__c = 'Integrado com erro'`

**`ERPOportunidadeIntegrationTest`** — 7 testes (100% passando):
- `testSimulacaoSucesso` — simulação retorna resposta e preenche `ultimoEndpoint`
- `testCamposImpostosPopulados` — ICMS, PIS, COFINS, Base ICMS, ST, Total populados nos OLIs
- `testPayloadMontado` — `CustomerId`, `Payment`, `ListofProducts` no JSON enviado
- `testSimulacaoSemProdutos` — lança `AuraHandledException` quando OLI lista vazia
- `testSimulacaoErroHTTP` — exceção com status 503
- `testBatchProcessRecordsSucesso` — batch preenche campos de imposto e cria log `SUCESSO`
- `testBatchProcessRecordsErroHTTP` — batch cria log `ERRO APEX/HTTP` com status 503

**`ViaCepFlowActionTest`** — 5 testes (100% passando):
- `testConsultarCepShipping` — popula ShippingStreet, ShippingCity, ShippingState
- `testConsultarCepBilling` — popula BillingStreet
- `testConsultarCepAmbos` — popula ambos endereços
- `testContaIdNulo` — ignora entrada sem accountId
- `testCepInvalidoNaoAtualiza` — não atualiza com resposta 404

#### Descobertas importantes no org de homolog

- `MicrorregiaoFaturamento__c` é campo fórmula calculado a partir de `MunicipioIBGEFaturamento__r.CodigoMicrorregiao__c`
- `CodigoIBGEFaturamento__c` é campo fórmula calculado a partir de `MunicipioIBGEFaturamento__r.CodigoIBGE__c`
- Para popular esses campos em testes é necessário criar um registro `MunicipioIBGE__c` e vincular via `MunicipioIBGEFaturamento__c`
- `ContribuinteICMS__c` estava faltando no SOQL do batch — causava `SObjectException` silenciosa no batch

### Org alvo

- Sandbox: `icasa@onze.work.prd.sandbox`
- Endpoint ERP: `https://portal.icasa.com.br/dts/datasul-rest/resources/prg/ftp/v2/itemTaxSimulationPublic`
