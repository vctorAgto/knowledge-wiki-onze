---
title: CustoMedioLeadService — Cálculo de Custo Médio por Lead
description: Reescrita do serviço de custo médio por lead conforme PDF de especificação (item 7)
published: true
tags: prime-results, salesforce, custo-medio, financeiro
editor: markdown
---

# CustoMedioLeadService — Cálculo de Custo Médio por Lead

**Cliente:** Prime Results  
**Status:** ✅ Concluído  
**Responsável:** Victor Pecuch  
**Data:** 30/06/2026  

---

## Sobre o Projeto

Serviço que calcula diariamente o custo médio por lead e atualiza o campo `Custo_Medio_Hoje__c` em todas as regionais ativas. Roda via `CustoMedioLeadSchedulable` → `CustoMedioLeadBatch` todo dia à 01:00.

---

## Solicitações

### 30/06/2026 — Reescrita conforme PDF "Regra de Custo Médio por Lead" (item 7)

**O que foi pedido:**  
Equipe enviou PDF com decisões para o item 7. Pontos confirmados antes da implementação:
- O saldo do numerador deve ser no momento do batch (início do mês)
- Leads devolvidos à Matriz entram no denominador (foram leads gerados, interferem no custo)
- O cálculo usa o valor total investido no início do período (início do mês)
- O custo por lead deve ser sempre maior que zero

**Problema com a implementação anterior:**  
O numerador usava `SUM(Custo_Aquisicao__c)` direto nos leads — isso era circular (lia de volta o que tinha sido debitado) e não refletia o investimento real do mês.

**Nova fórmula implementada:**

```
Numerador  = saldo_atual + débitos_no_mês - créditos_no_mês - estornos_no_mês
             (reconstituído via Movimentacao_Conta__c desde o início do mês)

Denominador = COUNT(Lead) WHERE Data_Atribuicao__c IN [D-1 00:00, D 00:00)
              (sem filtro de status — devolvidos são contados)

Custo = Numerador / Denominador
        se Custo <= 0 → usa Custo_Padrao__c do Configuracao_Distribuicao__mdt (mínimo 1)
        se Denominador = 0 → usa último Custo_Medio_Diario__c calculado, ou Custo_Padrao__c
```

**O que foi feito:**
- Reescrito `CustoMedioLeadService.cls`:
  - `public with sharing` → `public without sharing`
  - Novo numerador via `Movimentacao_Conta__c` agrupado por `Tipo__c` (Débito/Crédito/Estorno)
  - Denominador sem filtro `Custo_Aquisicao__c != null` (devolvidos incluídos)
  - Piso: `media <= 0` → usa `getCustoPadrao()` (novo método privado)
  - Fallback: sem leads → último `Custo_Medio_Diario__c` com `Fonte__c = 'Calculado'`
- Criado `CustoMedioLeadServiceTest.cls` com **7 testes** cobrindo todos os cenários
- Deploy para homolog e produção com **7/7 testes passando (100%)**

**Classes modificadas:** `CustoMedioLeadService.cls`  
**Classes criadas:** `CustoMedioLeadServiceTest.cls`  
**Campos novos:** nenhum (`Movimentacao_Conta__c` já existia em produção)

**Cenários de teste cobertos:**

| Teste | Cenário |
|---|---|
| `testCalculoUsaSaldoInicioDoMes` | Verifica que usa saldo início do mês, não saldo atual |
| `testCalculoSemMovimentacoes` | Sem movimentações — saldo_inicio = saldo_atual |
| `testDevolvidosContamNoDenominador` | Devolvidos com Data_Atribuicao__c são contados |
| `testFallbackComHistorico` | Sem leads em D-1 → reutiliza último CMD calculado |
| `testFallbackSemHistorico` | Sem leads e sem histórico → usa Custo_Padrao__c |
| `testPisoCustoPositivo` | Saldo_inicio=0 com leads → floor aplica Custo_Padrao__c |
| `testRegionalInativaExcluida` | Regional inativa não entra no numerador |

**Observação pós-deploy (produção):**  
Após o deploy, o `CronTrigger` do `CustoMedioLeadSchedulable` foi abortado automaticamente pelo Salesforce. Reagendado manualmente via Apex Anônimo:
```apex
System.schedule('CustoMedioLead', '0 0 1 * * ?', new CustoMedioLeadSchedulable());
```
