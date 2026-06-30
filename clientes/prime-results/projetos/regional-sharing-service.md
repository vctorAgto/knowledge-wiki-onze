---
title: RegionalSharingService — Distribuição de Leads por Regional
description: Implementação do compartilhamento de leads por regional com controle do Supervisor
published: true
tags: prime-results, salesforce, leads, regional
editor: markdown
---

# RegionalSharingService — Distribuição de Leads por Regional

**Cliente:** Prime Results  
**Status:** ✅ Concluído  
**Responsável:** Victor Pecuch  
**Data:** 30/06/2026  

---

## Sobre o Projeto

Implementação da distribuição automática de leads por regional no Salesforce, com compartilhamento para Gestor (Edit) e Macro Gestor (Read). Só processa leads com `Status_Distribuicao__c = Atribuído` e `Regional__c` preenchida.

---

## Solicitações

### 30/06/2026 — Criar e deployar RegionalSharingService com testes

**O que foi pedido:**  
Implementar o serviço de compartilhamento de leads por regional, garantindo que Gestores tenham acesso de edição e Macro Gestores de leitura para os leads atribuídos à sua regional.

**O que foi feito:**  
- Implementado `RegionalSharingService.cls` com método `compartilharLeadsAtribuidos(List<Lead>)`
- Criado `RegionalSharingServiceTest.cls` com 6 cenários de teste
- Corrigido bug: o trigger sobrescrevia `Status_Distribuicao__c` no insert, impedindo o código principal de ser exercitado — solução: fazer `update` após o `insert` no teste
- Deploy para produção com **6/6 testes passando (100%)**

**Detalhes técnicos:**  
```apex
// Filtra apenas leads válidos para processamento
if (l.Regional__c != null && l.Status_Distribuicao__c == 'Atribuído') {
    regionalIds.add(l.Regional__c);
}
```

**Resultado:** `RegionalSharingService` em produção com Supervisor incluído.
