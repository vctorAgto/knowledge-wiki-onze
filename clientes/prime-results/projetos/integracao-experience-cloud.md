---
title: Integração Experience Cloud - Criação de Usuários Parceiros
description: Integração via API Composite para criação de contas, contatos e usuários na Experience Cloud (Partner Community)
published: true
tags: prime-results
editor: markdown
---

## 2026-06-30 — Victor Pecuch

### O que foi solicitado

Definir o modelo de papéis, perfis e grupos de permissão para usuários da Experience Cloud (consultores e gestores de filial), revisar o payload da integração via API Composite enviado pelo time do Thiago Augusto, identificar o que faltava e documentar os ajustes necessários.

Além disso, criar uma automação para que o campo `Regional__c` no objeto User seja preenchido automaticamente com base em uma sigla de estado (`SiglaRegional__c`) enviada pela integração — evitando que a equipe externa precise conhecer os IDs internos do Salesforce.

---

### O que foi feito

#### 1. Revisão do payload da API Composite

O time de integração tinha dois `compositeRequest`:

- **Request 1** — Upsert de Account e Contact parceiro
- **Request 2** — Ativar Account como parceira (`IsPartner: true`) e criar/atualizar o User

Foram identificados os seguintes gaps no payload:

| Campo | Situação |
|---|---|
| `UserRoleId` | Ausente — precisa do ID do papel "Consultor Partner Community" ou "Gestor Partner Community" |
| `ContactId` | Errado — payload usava objeto aninhado `Contact: { CodigoExclusivo__c }`, deve ser `"ContactId": "@{refContact.id}"` |
| `Regional__c` | Ausente — campo crítico para o motor de distribuição de leads |
| `Is_Consultor_Ativo__c` | Ausente — deve ser `true` |
| `Slots_Ocupados__c` | Ausente — deve ser inicializado com `0` |
| `Slots_Limite__c` | Ausente — deve ser configurado conforme a regional |
| `RecordType.Name` | Não funciona via REST API — deve ser substituído por `RecordTypeId` |

#### 2. Nova requisição identificada: PermissionSetAssignment

O PDF de papéis e perfis (v3.0) define dois Permission Set Groups:
- `PSG_Consultor_PC` — para consultores
- `PSG_Gestor_PC` — para gestores de filial

Essa atribuição **não estava no escopo original** das duas chamadas. Foi identificada a necessidade de um **terceiro composite step** (ou chamada separada) para criar o `PermissionSetAssignment`:

```json
{
  "method": "POST",
  "url": "/services/data/v54.0/sobjects/PermissionSetAssignment",
  "referenceId": "refPSG",
  "body": {
    "AssigneeId": "@{refUser.id}",
    "PermissionSetGroupId": "<ID_PSG_CONSULTOR_PC ou PSG_GESTOR_PC>"
  }
}
```

#### 3. Modelo de papéis e perfis (PDF v3.0)

O PDF define dois perfis EC e dois papéis genéricos — **um par por tipo de usuário**:

| Tipo | Perfil | Papel | PSG |
|---|---|---|---|
| Consultor | Consultor (EC) | Consultor Partner Community | PSG_Consultor_PC |
| Gestor de Filial | Gestor da Filial (EC) | Gestor Partner Community | PSG_Gestor_PC |

**Ponto em aberto:** o sistema de origem (ERP/CRM externo) precisa informar qual tipo de usuário está sendo criado para que o payload use os IDs corretos de ProfileId, UserRoleId e PermissionSetGroupId.

IDs a confirmar com a Prime Results:
- `ProfileId` — já presente no payload como `00ebe000001N4K5AAK`, confirmar se é o perfil "Consultor (EC)"
- `UserRoleId` — ausente, buscar via: `SELECT Id, Name FROM UserRole WHERE Name = 'Consultor Partner Community'`
- `PermissionSetGroupId` — ausente, buscar via: `SELECT Id, MasterLabel FROM PermissionSetGroup WHERE MasterLabel = 'PSG_Consultor_PC'`

#### 4. Automação: SiglaRegional__c → Regional__c

Para evitar que a integração precise conhecer os IDs internos dos registros `Regional__c`, foi criado um trigger no objeto User que resolve automaticamente a sigla do estado para o lookup:

**Arquivos criados:**
- `force-app/main/default/triggers/UserTrigger.trigger` — `before insert, before update`
- `force-app/main/default/classes/UserTriggerHandler.cls` — lógica de resolução

**Como funciona:**
1. A integração envia `SiglaRegional__c: "PR"` (picklist restrita, 26 estados + DF)
2. O trigger consulta `Regional__c WHERE Name IN :siglas`
3. Preenche `Regional__c` com o ID correspondente automaticamente

O campo `SiglaRegional__c` foi convertido de **Text** para **Picklist** (restrita) com os 26 valores de siglas estaduais brasileiras, impedindo envio de valores inválidos.

**Valores aceitos:**
`AC, AL, AM, BA, CE, DF, ES, GO, MA, MG, MS, MT, PA, PB, PE, PI, PR, RJ, RN, RO, RR, RS, SC, SE, SP, TO`

---

### Pendências

- [ ] Prime Results confirmar os IDs de ProfileId, UserRoleId e PermissionSetGroupId para Consultor e Gestor
- [ ] Time de integração (Thiago) confirmar se o sistema de origem sabe distinguir Consultor de Gestor por usuário
- [ ] Atualizar payload final com todos os campos e incluir step de PermissionSetAssignment
