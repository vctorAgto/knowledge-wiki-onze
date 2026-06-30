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

---

### 30/06/2026 — Adicionar Supervisor ao compartilhamento de leads

**O que foi pedido:**  
Alguém da equipe alterou o `RegionalSharingService` no homolog para incluir o Supervisor (Read) além do Gestor e Macro Gestor. Necessário atualizar a classe teste e subir para produção.

**Diferença entre homolog e prod:**

| Papel | Antes (prod) | Depois (homolog → prod) |
|---|---|---|
| Gestor Principal | Edit | Edit |
| **Supervisor** | — | **Read (novo)** |
| Macro Gestor | Read | Read |

**O que foi feito:**
- Atualizado `RegionalSharingService.cls` local com a versão do homolog (incluindo `Supervisor__c`)
- Atualizado `RegionalSharingServiceTest.cls`: criado usuário Supervisor no setup e `Supervisor__c` na Regional
- Corrigido baixa cobertura (21% → 100%): trigger sobrescrevia `Status_Distribuicao__c` no insert do lead de teste — corrigido com `update` após `insert` no `@TestSetup`
- Deploy para produção com **6/6 testes passando (100%)**

**Classes modificadas:** `RegionalSharingService.cls`, `RegionalSharingServiceTest.cls`  
**Campos novos:** nenhum (`Supervisor__c` já existia em `Regional__c`)
