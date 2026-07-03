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

## 2026-07-03 — Victor Pecuch

### O que foi solicitado

- Criar e executar uma classe batch para limpar o campo `AccountCode__c` de contas não-transportadoras (`Transportadora__c = false`) que estivessem com esse campo preenchido, mantendo só `ExternalID__c` como identificador
- Levar os campos `InscricaoEstadual__c` e `CNPJ__c` do próprio `EnderecoComplementar__c` para o `deliveryPlaces` do payload ERP, em vez de usar os campos da Account
- Investigar erro de sincronização de conta com o ERP ("Integrado com erro")
- Remover o bloco "Resposta do ERP" (JSON cru) da tela de sucesso do flow de integração, deixando só o link para o log
- Transformar o campo `CondicaoPagamento__c` (texto) do `NotaFiscal__c` em picklist, usando os mesmos valores/API names do `Prazo__c` da Opportunity
- Preencher automaticamente o campo `StandardCarrier__c` (Transportadora padrão) na criação de contas Cliente

### O que foi feito

- Criada e executada a classe `LimparAccountCodeBatch`, limpando `AccountCode__c` em ~35.386 contas não-transportadoras no sandbox
- `ERPContaService.cls`: `deliveryPlaces` passou a usar `e.InscricaoEstadual__c` e `e.CNPJ__c` do próprio endereço complementar, em vez de `conta.StateRegistration__c`/`conta.CNPJ__c`; queries de endereço atualizadas em `ERPContaService` e `ERPContaIntegrationBatch`; teste `testDeliveryPlacesComCNPJeIE` ajustado para validar o novo comportamento
- Identificado e corrigido bug: as queries de Account em `ERPContaIntegrationBatch` (batch e `processRecords`) não traziam `Tabela_Precos__r.CodigoTabela__c`, causando `SObjectException` ao montar o payload (`priceTable`) sempre que a conta tinha tabela de preço vinculada
- Flow `FLIntegracaoConta`: removido o bloco "Resposta do ERP" (JSON cru) da tela de sucesso, mantendo status, endpoint e link para o log mais recente (`ObterLog`, já ordenado por `CreatedDate` desc)
- `NotaFiscal__c.CondicaoPagamento__c` convertido de Texto para Picklist não-restrita, com 33 valores espelhando o `Prazo__c` da Opportunity (API Name = código numérico do ERP, Label = descrição — ex: `10` → `ANTECIPADO`); mantido não-restrita para não invalidar os ~178 valores de texto livre já gravados nos registros existentes
- Criado o flow `FLContaTransportadoraPadrao` (before-save, na criação de Account): preenche `StandardCarrier__c` com a conta `TRANSCASA LTDA.` (`001HZ00000gCBIuYAO`) quando o campo está vazio e o Record Type é Cliente; validado nos dois cenários (Cliente preenche, Transportadora não preenche)

## 2026-07-03 — Victor Pecuch (Sessão — Payload ERPContaService, FLIntegracaoConta e formulário completo)

### O que foi solicitado

- Completar `ERPContaService.montarPayload()` com mapeamento de todos os campos SF → ERP (`customerPublic`)
- Corrigir erros HTTP 500 do ERP: `customerGroup` inválido, transportador não cadastrado, país não encontrado, formato de CEP inválido, formato de telefone inválido, `activityBranch` sendo enviado como número
- Salvar o `customerCode` retornado pelo ERP no campo `ExternalID__c` da Conta (não `IssuerCode__c`)
- Construir o Flow `FLIntegracaoConta` completo: verificação de conta já integrada, validação de obrigatórios, tela de revisão (de-para), formulário editável, tela de confirmação com botão "Integrar" separado
- Adicionar todos os campos da integração à tela `telaPreencherCampos`
- Corrigir UX: imagens quebradas, erros de encoding de caracteres especiais, visibilidade de botões

### O que foi feito

- `ERPContaService.montarPayload()` finalizado com mapeamento completo:
  - `personalId` ← `formatarCNPJ(CNPJ__c)` → formato `XX.XXX.XXX/XXXX-XX`
  - `activityBranch` ← `conta.get('IndustryLabel')` via `toLabel(Industry)` no SOQL (string, não inteiro)
  - `customerClassification` ← `obterCustomerClassification(Rating)` com mapa de picklist
  - `credit` ← `obterCredit(Situation__c)`: Ativo→1, Inativo→2, Análise→7
  - `creditSuspendedCustomer` ← `Situation__c == 'Inativo' ? true : null` (nunca `false`)
  - `customerGroup` ← `Integer.valueOf(Group__c)` — omitido se nulo
  - `carrier` ← `StandardCarrier__r.ExternalID__c` (Integer)
  - `entityType` ← `0` (matriz) se `Matriz__c` nulo, `1` (filial) se preenchido
  - Endereços com `formatarCEP()` (`88353467` → `88353-467`) e `normalizarPais()` (`BR` → `Brasil`)
- Helpers criados: `formatarCNPJ`, `formatarCEP`, `formatarTelefone`, `normalizarPais`, `obterShortRegion`, `obterCredit`, `obterCustomerClassification`, `obterEntityType`
- `customerCode` retornado salvo em `conta.ExternalID__c` após sucesso — testado com contas Silvana e Fabiana (código `42210` retornado e salvo)
- `FLIntegracaoConta` implementado com: `decisaoJaIntegrada`, `decisaoValidacao`, `telaConfirmarPayload` (tabela de-para), `telaPreencherCampos` (formulário), `salvarCamposObrigatorios`, `telaCamposSalvos`, `Integrar_Conta_com_ERP`, telas de sucesso e erro
- `telaPreencherCampos` com 30+ campos usando abordagem híbrida:
  - `ObjectProvided` (widget nativo: dropdown para picklist, lookup search para relacionamento): `Situation__c`, `Prazo__c`, `Group__c`, `CNPJ__c`, `StateRegistration__c`, bairros, números, `IssuerShortName__c`, telefones, `Industry`, `Rating`, `Matriz__c`, `Tabela_Precos__c`, `StandardCarrier__c`
  - `dataType:String` (campos incompatíveis com ObjectProvided): endereços compostos (ShippingStreet etc.), `Website`, `Email__c`, `DescontoMaximoPermitido__c`, `OwnerId`, `Description`
- Descoberta técnica: `ObjectProvided` é o `fieldType` correto para widgets nativos em telas de flow (não `InputField`); `isRequired:true` não é permitido em campos `ObjectProvided`; campos compostos de endereço, URL e OwnerId não são suportados por `ObjectProvided`
- UX corrigido: imagens quebradas → emoji HTML `&#x2705;`; encoding de acentos → entidades HTML (`&ccedil;`, `&atilde;`); `allowBack:false` + `allowFinish:false` simultâneos não permitidos pelo SF → ajustado para `allowBack:true`

## 2026-07-03 — Victor Pecuch

### O que foi solicitado

- Corrigir `FlowTrigger_CriaEnderecoComplementarPadrao`: campos `Endereco__c` e `Estado__c` não preenchidos ao criar `EnderecoComplementar__c` a partir de Account
- Atualizar `FLIntegracaoConta`: remover `Prazo__c`, `Group__c`, `BairroCobranca__c` e `NumeroCobranca__c` da validação de obrigatórios e da tela de preenchimento
- Corrigir `interstateTransactionType` em `ERPContaService`: valor hardcoded `'Operação Interna'` sendo truncado para `'Operaç'` pelo ERP
- Criar `ERPOportunidadeService`: simulação de impostos no ERP para Oportunidades
- Criar `ERPOportunidadeIntegrationBatch`: batch com `@InvocableMethod` para uso em flows
- Criar `FLIntegracaoOportunidade`: flow de tela para simular impostos de Oportunidade no ERP
- Criar Quick Action `Opportunity.IntegrarERP`: botão na página da Oportunidade chamando o flow
- Corrigir log de integração não vinculado à Oportunidade (`Oportunidade__c` não era setado)
- Corrigir endpoint: `BaseEndpoint__c` usa `cdp/v1`, mas simulação de impostos usa `ftp/v2`
- Mapear campo `Payment` do payload ERP para `Prazo__c` da Oportunidade
- Investigar diferença entre erro 503 no SF e 500/17006 no Postman

### O que foi feito

- `FlowTrigger_CriaEnderecoComplementarPadrao`: adicionados `inputAssignments` faltantes — `Endereco__c ← ShippingStreet` e `Estado__c ← ShippingState`
- `FLIntegracaoConta`: removidas condições `Prazo__c` e `Group__c` da decisão `decisaoValidacao`; removidos campos `BairroCobranca__c` e `NumeroCobranca__c` da tela `telaPreencherCampos`
- `ERPContaService`: `interstateTransactionType` substituído por lógica condicional: `MG → '511VC'`, demais → `'611VB'`
- `ERPOportunidadeService` (novo): estende `BaseCalloutService`; endpoint derivado via regex `replaceAll('(crm|cdp)/v\\d+/', 'ftp/v2/')` sobre `BaseEndpoint__c`; `Payment` mapeado para `Prazo__c`; campos de imposto nos OLIs comentados com TODO (campos ainda não criados no SF)
- `ERPOportunidadeIntegrationBatch` (novo): batch size 5; pré-busca OLIs em 1 SOQL por lote; `@InvocableMethod` recebe `List<Id>`; log criado com `Oportunidade__c = opp.Id`
- `FLIntegracaoOportunidade` (novo): flow de tela com lookup de oportunidade → decisão de conta integrada (`ExternalID__c` não nulo) → tela de confirmação → action call Apex (`NewTransaction`) → lookup de log → decisão de status → telas de sucesso/erro e fault path
- `Opportunity.IntegrarERP` Quick Action (nova): tipo `Flow`, aponta para `FLIntegracaoOportunidade`; deve ser adicionada ao page layout via Setup → Object Manager → Opportunity → Page Layouts
- Investigação 503 vs 17006: confirmado via curl sem JSESSIONID que o ERP retorna `500/17006` (JSON) quando o Appserver está no ar; o `503 HTML` veio do proxy (Apache/Nginx) na frente do TOTVS indicando que o Appserver estava temporariamente fora; código SF está correto — quando estável, SF e Postman recebem o mesmo erro
