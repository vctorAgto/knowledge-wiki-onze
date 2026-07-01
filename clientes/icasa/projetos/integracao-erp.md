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

---

## 2026-07-01 — Victor Pecuch (Sessão — Criação inicial integração Oportunidade)

### O que foi solicitado

- Corrigir `FlowTrigger_CriaEnderecoComplementarPadrao`: campos `Endereco__c` e `Estado__c` não estavam sendo populados ao criar `EnderecoComplementar__c` a partir de uma Conta
- Atualizar `FLIntegracaoConta`: remover `Prazo__c`, `Group__c`, `BairroCobranca__c` e `NumeroCobranca__c` da validação de campos obrigatórios e da tela de preenchimento
- Corrigir `interstateTransactionType` em `ERPContaService`: valor hardcoded `'Operação Interna'` estava sendo truncado para `'Operaç'` pelo ERP
- Criar `ERPOportunidadeService`: simulação de impostos no ERP para Oportunidades, modelado após `ERPContaService`
- Criar `ERPOportunidadeIntegrationBatch`: batch com `@InvocableMethod` para uso em flows, modelado após `ERPContaIntegrationBatch`
- Criar `FLIntegracaoOportunidade`: flow de tela para simular impostos de uma Oportunidade no ERP
- Criar Quick Action `Opportunity.IntegrarERP`: botão na página da Oportunidade que chama o flow
- Corrigir log não vinculado à Oportunidade: `Oportunidade__c` não estava sendo setado no `IntegrationLog__c`
- Corrigir endpoint: `BaseEndpoint__c` usa `cdp/v1`, mas simulação de impostos usa `ftp/v2`
- Mapear campo `Payment` no payload para `Prazo__c` da Oportunidade
- Investigar por que o SF retorna 503 enquanto Postman retorna 500 com código 17006

### O que foi feito

#### `FlowTrigger_CriaEnderecoComplementarPadrao`

Adicionados dois `inputAssignments` faltantes no record create do flow:

| Campo `EnderecoComplementar__c` | Origem |
|---|---|
| `Endereco__c` | `$Record.ShippingStreet` |
| `Estado__c` | `$Record.ShippingState` |

#### `FLIntegracaoConta`

Removidos da decisão `decisaoValidacao`:
- Bloco de condição `Prazo__c`
- Bloco de condição `Group__c`

Removidos da tela `telaPreencherCampos`:
- Campo de tela `BairroCobranca__c`
- Campo de tela `NumeroCobranca__c`

Campos obrigatórios restantes: `CNPJ__c`, `ShippingStreet`, `ShippingCity`, `ShippingState`, `ShippingPostalCode`, `BairroFaturamento__c`, `NumeroFaturamento__c`, `Situation__c`.

#### `ERPContaService` — `interstateTransactionType`

Substituído valor hardcoded por lógica baseada na UF do cliente:

```apex
payload.put('interstateTransactionType',
    'MG'.equalsIgnoreCase(conta.ShippingState) ? '511VC' : '611VB');
```

> **Nota:** Em sessão posterior, o cliente confirmou que o correto é sempre `'611VB'` e adicionado `stateTransactionType` fixo em `'511VC'`.

#### `ERPOportunidadeService` (novo)

Classe que estende `BaseCalloutService` para simulação de impostos de Oportunidades:

- `getEndpoint`: deriva URL de `ftp/v2` a partir do `BaseEndpoint__c` (`cdp/v1`) via regex `replaceAll('(crm|cdp)/v\\d+/', 'ftp/v2/')`
- `executarSimulacao(Opportunity)`: path single record — re-query opp + OLIs inline
- `executarSimulacao(Opportunity, List<OLI>)`: path batch — recebe OLIs pré-buscados
- `montarPayload`: monta JSON com `CustomerId`, `Payment` (← `Prazo__c`), `ListofProducts`, descontos
- `processarResposta`: campos de imposto nos OLIs comentados com TODO pendente criação dos campos no SF
- Expõe `ultimoRequestBody` e `ultimoEndpoint` para log

#### `ERPOportunidadeIntegrationBatch` (novo)

- Implementa `Database.Batchable`, `Database.AllowsCallouts`, `Schedulable`
- Batch size: 5 (uma chamada HTTP por Oportunidade)
- SOQL de `start()` inclui `Prazo__c`, `PercentualDesconto__c` e relacionamentos de Conta
- Pré-busca OLIs em lote (1 SOQL para todos os registros do lote, não por registro)
- `@InvocableMethod` recebe `List<Id>` para uso direto em flows
- Log criado com `Oportunidade__c = opp.Id` para vincular ao registro

#### `FLIntegracaoOportunidade` (novo)

Flow de tela para Opportunity com:

| Elemento | Descrição |
|---|---|
| `obterOportunidade` | Record lookup da oportunidade com conta relacionada |
| `decisaoContaIntegrada` | Bloqueia se `Account.ExternalID__c` está nulo |
| `telaConfirmar` | Tela de confirmação antes de chamar o ERP |
| `Simular_Impostos_ERP` | Action call para `ERPOportunidadeIntegrationBatch` (`NewTransaction`) |
| `obterLog` | Busca log mais recente filtrando por `itemTaxSimulationPublic` |
| `decisaoStatus` | Redireciona para tela de sucesso ou erro conforme `Status__c` |
| Fault paths | `telaErroApex` para exceções do Apex |

#### `Opportunity.IntegrarERP` Quick Action (nova)

Quick Action do tipo `Flow` apontando para `FLIntegracaoOportunidade`. Deve ser adicionada ao page layout da Oportunidade via Setup → Object Manager → Opportunity → Page Layouts.

#### Investigação 503 vs 500/17006

Confirmado via curl manual sem cookie JSESSIONID que:
1. O cookie **não é necessário** — a API usa somente Basic Auth
2. Sem cookie, a resposta é `500` com `{"code":"17006","message":"Ocorreu algum erro técnico..."}` — mesmo resultado do Postman
3. O `503` que o SF recebeu foi **indisponibilidade momentânea** do Appserver Progress (TOTVS)
4. A resposta 503 vem em HTML (do proxy Apache/Nginx), enquanto a 500 com 17006 vem do próprio app TOTVS
5. O código SF está correto — quando o Appserver estiver estável, SF e Postman receberão o mesmo 17006

O erro 17006 é um problema interno do ERP que precisa ser investigado pela equipe TOTVS no log do Appserver Progress.

### Pendências

- Adicionar campos de imposto nos OLIs (`ICMSValor__c`, `PorcentICMS__c`, `BaseCalculoICMS__c`, `VlrPIS__c`, `PorcentagemPIS__c`, `VlrCOFINS__c`, `PorcentagemCOFINS__c`, `VlrICMSST__c`, `PorcentemICMSST__c`) e descomentar o mapeamento em `processarResposta`
- Investigar erro 17006 com equipe TOTVS (log do Appserver Progress)
- Adicionar Quick Action `Integrar ERP` ao page layout da Oportunidade
