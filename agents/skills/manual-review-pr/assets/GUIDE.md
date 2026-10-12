---
title: PR #<n> — <sujet> : revue de conception
kicker: <projet> — revue de conception
lang: fr
repo: <owner>/<repo>
sha: <40 caractères, tête de la PR au moment de la revue>
pr: <n>
checkout: <chemin absolu du clone>
---

<!--
Source unique : on itère ici, jamais dans index.html.
  python3 build.py
  python3 build.py --check-urls
-->

La [PR #<n>](pr:) <ce qu'elle apporte, en une phrase>. Cette page ne relit
pas le code ligne à ligne : elle résume les choix de conception à
reprendre et les décisions prises pendant la revue. Les extraits de la
cible sont des esquisses, pas du code de la PR. Liens figés sur
[`<sha7>`](tree:).

<!-- tab: Vue d'ensemble -->

::: callout
**En une phrase**

<Verdict : ce qui tient, ce qui est à reprendre, et la direction.>
:::

## Ce que la PR fait aujourd'hui

- <mécanisme, avec lien gh:path#Lx-Ly>

## Les grandes lignes de la revue

| Axe | Dans la PR | Cible | Détail |
| --- | --- | --- | --- |
| <axe> | <aujourd'hui> | <cible> | [<sous-onglet>](#<ancre-du-titre>) |

L'onglet [Cible finale](#cible-finale) montre l'interface obtenue à la
fin, d'un seul tenant ; l'onglet Solutions détaille chaque axe.

## Ordre proposé

1. **<refactor préparatoire>.** <pourquoi d'abord>
2. **<la fonctionnalité>** <se pose ensuite sur le refactor>

## Ce qu'on garde tel quel

- <ce qui est bon dans la PR>

<!-- tab: Cible finale -->

## L'interface à la fin du refactor

<Esquisse : les noms et le découpage sont la cible, le corps des méthodes
est indicatif.>

### Qui fait quoi

| Pièce | Rôle | Ce qu'elle sait de la fonctionnalité |
| --- | --- | --- |
| <pièce> | <rôle unique> | <rien / déclare / orchestre / contenu> |

### Le parcours d'une requête

```text
<requête>
  │
  ├─ <étape> ── <ce qu'elle fait>
  │
  └─ <réponse>
```

### <Pièce>

```ruby
<esquisse dans les idiomes du dépôt>
```

### Ce qu'un nouveau <endpoint, écran, job> doit écrire

1. <déclaration>

### Ce qui disparaît de la PR

| Élément | Remplacé par |
| --- | --- |
| <élément de la PR> | <pièce de la cible> |

<!-- tab: Solutions -->

Chaque sous-onglet part de ce que fait la PR, explique le problème et
décrit la cible, avec les justifications données en revue.

<!-- subtab: <Axe 1> -->

## <Titre de l'axe 1>

### Aujourd'hui

```ruby
<extrait réel du commit figé>
```

[Source](gh:<path>#L<x>-L<y>).

<Le problème, en quelques puces.>

::: callout
**Décision : <la décision>**

<La justification de l'utilisateur, dans ses mots.>
:::

### Cible

```ruby
# cible (esquisse)
<esquisse>
```

### Conséquences

- <ce qui change ailleurs : specs, doc, autres appelants>

<!-- subtab: <Axe 2> -->

## <Titre de l'axe 2>

<!-- tab: Décisions produit -->

## Décisions produit

### <Sujet>

<Le constat.>

::: callout
**Décision : <accepté, refusé, reporté>**

<La justification de l'utilisateur.>
:::

### Ouvert

- **<question>** <pourquoi elle reste ouverte, qui tranche>

<!-- tab: Notes -->

## Notes mineures

Pour mémoire, rien de bloquant.

- **<sujet>.** <constat, lien>
